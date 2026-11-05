#!/usr/bin/env bash
# =============================================================================
# scripts/audit_bump_and_branch.sh — 仅对 level=patch 的依赖做机械版本 bump、建分支、
#                                   跑 check-versions.sh 自检，（可选）push。
#
# 输入：detect 产物 drift.json（见 audit_collect_drift.py）。
# 只处理 level==patch 且 auto_bump==true 的 dep ∈ {rea, ghidra, node}；
# minor/major/unknown/jdk21 一律不动（留给人工或 report-issue）。
#
# 用法：
#   bash scripts/audit_bump_and_branch.sh drift.json [--apply] [--cmd-list /tmp/cmds-new.txt]
#
#   默认 = dry-run：只打印计划改动，不碰文件、不建分支、不 push。
#   --apply       真正建分支 + sed + 自检 + commit（仍不 push）。
#   AUDIT_PUSH=1  且 --apply：git push 到远端（仅 CI 用；本地绝不 push）。
#
# 产物：/tmp/upgrade-manifest.tsv（列：dep<TAB>branch<TAB>old<TAB>new<TAB>status<TAB>note），
#       供下游 github-script 开 PR / ci-gate / 分级合并消费。
# 退出码：0 = 处理完成（blocked 项会写进 manifest，不影响本脚本退出码，由下游开 blocked issue）；
#         1 = 严重错误（drift.json 不存在 / 解析失败 / git 不在仓库内）。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || exit 1

DRIFT_JSON="${1:-}"
shift || true
APPLY=0
CMD_LIST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --cmd-list) CMD_LIST="${2:-}"; shift ;;
    *) echo "未知参数：$1" >&2; exit 1 ;;
  esac
  shift || true
done

[ -n "$DRIFT_JSON" ] || { echo "用法：$0 drift.json [--apply] [--cmd-list file]" >&2; exit 1; }
[ -f "$DRIFT_JSON" ] || { echo "找不到 drift.json：${DRIFT_JSON}" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "不在 git 工作树内" >&2; exit 1; }

MANIFEST="/tmp/upgrade-manifest.tsv"
: > "$MANIFEST"

# 从 drift.json 抽出可自动 bump 的 patch 项：dep<TAB>old<TAB>new<TAB>build<TAB>date
PATCH_ITEMS="$(python3 - "$DRIFT_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
for it in d.get("items", []):
    if (it.get("auto_bump") and it.get("level") == "patch"
            and it.get("dep") in ("rea", "ghidra", "node") and it.get("upstream")):
        print("\t".join([it["dep"], str(it["locked"]), str(it["upstream"]),
                         str(it.get("ghidra_build") or ""),
                         str(it.get("ghidra_date") or "")]))
PY
)"

if [ -z "$PATCH_ITEMS" ]; then
  echo "没有 level=patch 的可自动 bump 项（全部 in-sync / minor / major / unknown / jdk），无需建分支。"
  exit 0
fi

BASE_SHA="$(git rev-parse HEAD)"
# 记录起始符号引用（本地分支名）；CI 里多为 detached HEAD，回退到 SHA
START_BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
echo "基线提交：${BASE_SHA:0:10}（apply=${APPLY} push=${AUDIT_PUSH:-0}）"

while IFS=$'\t' read -r dep old new build date; do
  [ -n "$dep" ] || continue
  branch="chore/upgrade-${dep}-${new}"
  echo
  echo "== [${dep}] ${old} -> ${new} => ${branch}"

  if [ "$APPLY" -ne 1 ]; then
    echo "  (dry-run) 将修改 config/versions.env（+ghidra 时同步 .github/workflows/ci.yml），"
    echo "  建分支 ${branch}，跑 check-versions.sh，commit，再按 AUDIT_PUSH 决定是否 push。"
    printf '%s\t%s\t%s\t%s\tdry-run\tdry-run 未实际修改\n' "$dep" "$branch" "$old" "$new" >> "$MANIFEST"
    continue
  fi

  # 每次从干净的基线提交切分支
  git checkout -B "$branch" "$BASE_SHA" >/dev/null 2>&1 || {
    echo "  [BLOCKED] 切分支失败"
    printf '%s\t%s\t%s\t%s\tblocked\tcheckout 失败\n' "$dep" "$branch" "$old" "$new" >> "$MANIFEST"
    continue
  }

  case "$dep" in
    rea)
      sed -i -E "s/^REA_VERSION=.*/REA_VERSION=${new}/" config/versions.env
      # rea bump：把最新命令快照落到 config/command-baseline/ 随 PR 提交
      if [ -n "$CMD_LIST" ] && [ -f "$CMD_LIST" ]; then
        sort -u "$CMD_LIST" > "config/command-baseline/rea-${new}.txt"
        git add "config/command-baseline/rea-${new}.txt"
        echo "  写入命令基线快照 config/command-baseline/rea-${new}.txt"
      fi
      ;;
    node)
      sed -i -E "s/^REA_NODE_VERSION=.*/REA_NODE_VERSION=${new}/" config/versions.env
      ;;
    ghidra)
      sed -i -E "s/^GHIDRA_VERSION=.*/GHIDRA_VERSION=${new}/" config/versions.env
      [ -n "$build" ] && sed -i -E "s#^GHIDRA_BUILD=.*#GHIDRA_BUILD=${build}#" config/versions.env
      [ -n "$date" ] && sed -i -E "s/^GHIDRA_DATE=.*/GHIDRA_DATE=${date}/" config/versions.env
      # ci.yml 里硬编码的 Ghidra 版本点（L53 grep 'Ghidra X' 与 cache-key）一并替换
      sed -i "s/${old}/${new}/g" .github/workflows/ci.yml
      ;;
  esac
  git add config/versions.env
  [ "$dep" = "ghidra" ] && git add .github/workflows/ci.yml

  # 自检：版本一致性不过 → 不开 PR，回滚走 blocked
  if ! bash scripts/check-versions.sh; then
    echo "  [BLOCKED] check-versions.sh 自检失败，回滚改动"
    git checkout -- . >/dev/null 2>&1
    printf '%s\t%s\t%s\t%s\tblocked\tcheck-versions.sh 自检失败\n' "$dep" "$branch" "$old" "$new" >> "$MANIFEST"
    continue
  fi

  git commit -q -m "chore(deps): bump ${dep} ${old} -> ${new}" || {
    echo "  [BLOCKED] git commit 失败（无改动？）"
    printf '%s\t%s\t%s\t%s\tblocked\tcommit 失败\n' "$dep" "$branch" "$old" "$new" >> "$MANIFEST"
    continue
  }

  if [ "${AUDIT_PUSH:-0}" = "1" ]; then
    git push -u origin "$branch" || {
      echo "  [BLOCKED] git push 失败"
      printf '%s\t%s\t%s\t%s\tblocked\tpush 失败\n' "$dep" "$branch" "$old" "$new" >> "$MANIFEST"
      continue
    }
    echo "  pushed ${branch}"
  else
    echo "  (AUDIT_PUSH!=1) 本地已 commit，未 push"
  fi

  printf '%s\t%s\t%s\t%s\tok\tready-for-pr\n' "$dep" "$branch" "$old" "$new" >> "$MANIFEST"
done <<EOF
${PATCH_ITEMS}
EOF

# 回到起始分支（本地有分支则回分支，避免游离 HEAD；CI detached 则回 SHA）
if [ -n "$START_BRANCH" ]; then
  git checkout -q "$START_BRANCH" >/dev/null 2>&1 || true
else
  git checkout -q "$BASE_SHA" >/dev/null 2>&1 || true
fi

echo
echo "== bump 完成，manifest：${MANIFEST} =="
cat "$MANIFEST"
exit 0

#!/usr/bin/env bash
# =============================================================================
# scripts/check-versions.sh — 版本一致性检查 + 上游最新版探测
#
# 1) 校验 config/versions.env 字段齐全；
# 2) 校验安装脚本 / Dockerfile 没有再硬编码版本号（单一事实源不被破坏）；
# 3) 若有网络，查询 npm 上 rea-agents 最新版与 GitHub 上 Ghidra 最新版，
#    与锁定版本对比（仅告警，不因此失败；离线/限流时自动跳过）。
#
# 用法：bash scripts/check-versions.sh
# 退出码：结构/一致性错误为 1；上游仅落后为 0（只打印 WARN）。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
load_versions

FAIL=0
err()  { printf '\033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=1; }

echo "== 锁定版本（来自 config/versions.env）=="
echo "  Ghidra  = $GHIDRA_VERSION (build $GHIDRA_BUILD, date $GHIDRA_DATE)"
echo "  JDK     = $JDK_FEATURE"
echo "  Node    = $REA_NODE_VERSION"
echo "  REA     = $REA_VERSION"

echo "== 1. 必需字段 =="
for k in GHIDRA_VERSION GHIDRA_BUILD GHIDRA_DATE JDK_FEATURE REA_NODE_VERSION REA_VERSION; do
  if [ -z "${!k:-}" ]; then err "config/versions.env 缺少 $k"; else echo "  [OK] $k"; fi
done

echo "== 2. 单一事实源（不应硬编码版本）=="
# Dockerfile 现在从 versions.env 读取，不应再出现 ARG GHIDRA_VERSION=... 等默认值
if grep -nE '^\s*ARG\s+(GHIDRA_VERSION|GHIDRA_BUILD|GHIDRA_DATE|REA_NODE_VERSION|REA_VERSION)=' \
     "$REPO_ROOT/Dockerfile" >/dev/null 2>&1; then
  err "Dockerfile 仍硬编码 ARG 版本默认值，应改为读取 config/versions.env"
else
  echo "  [OK] Dockerfile 未硬编码版本 ARG"
fi
# install.sh 不应再出现写死的 GHIDRA_VERSION=12.x
if grep -nE 'GHIDRA_VERSION="?\$\{GHIDRA_VERSION:-[0-9]' "$REPO_ROOT/install.sh" >/dev/null 2>&1; then
  err "install.sh 仍写死 Ghidra 版本默认值，应改用 load_versions"
else
  echo "  [OK] install.sh 未写死 Ghidra 版本"
fi

echo "== 3. 上游最新版本探测（离线/限流自动跳过）=="
# npm：rea-agents 最新版
NPM_LATEST="$(npm view rea-agents version 2>/dev/null || true)"
if [ -n "$NPM_LATEST" ]; then
  if [ "$NPM_LATEST" = "$REA_VERSION" ]; then
    echo "  [OK] rea-agents 最新=${NPM_LATEST}（与锁定一致）"
  else
    printf '  \033[33m[WARN]\033[0m rea-agents 最新=%s，锁定=%s（考虑升级）\n' "$NPM_LATEST" "$REA_VERSION"
  fi
else
  echo "  [SKIP] 无法查询 npm（离线？），跳过 rea-agents 版本比对"
fi

# GitHub：Ghidra 最新 release tag（带 token 可规避匿名限流；无 token 也尝试）
GH_API="$(curl -fsSL \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest 2>/dev/null || true)"
if [ -n "$GH_API" ]; then
  GH_LATEST="$(printf '%s' "$GH_API" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)"
  if [ -n "$GH_LATEST" ]; then
    # tag 形如 Ghidra_12.1.4_build；取出 12.1.4 与锁定比较
    GH_VER="$(printf '%s' "$GH_LATEST" | sed -E 's/Ghidra_([0-9.]+)_build/\1/')"
    if [ "$GH_VER" = "$GHIDRA_VERSION" ]; then
      echo "  [OK] Ghidra 最新=${GH_VER}（与锁定一致）"
    else
      printf '  \033[33m[WARN]\033[0m Ghidra 最新=%s，锁定=%s（需同步更新 GHIDRA_BUILD/DATE）\n' \
        "$GH_VER" "$GHIDRA_VERSION"
    fi
  else
    echo "  [SKIP] 未能解析 Ghidra 最新版本，跳过"
  fi
else
  echo "  [SKIP] 无法访问 GitHub API（限流/离线），跳过 Ghidra 版本比对"
fi

echo "== 4. 便携 Node 与 GHA action 漂移巡检（v4.3；仅报告，不自动升级）=="
# Node：nodejs.org dist index 取当前 LTS 版本，与锁定 REA_NODE_VERSION 比对。
NODE_IDX="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null || true)"
if [ -n "$NODE_IDX" ]; then
  NODE_LTS="$(printf '%s' "$NODE_IDX" | python3 -c '
import sys, json
for r in json.load(sys.stdin):
    lts = r.get("lts")
    if lts:
        print(r["version"].lstrip("v")); break
' 2>/dev/null || true)"
  if [ -n "$NODE_LTS" ]; then
    if [ "$NODE_LTS" = "$REA_NODE_VERSION" ]; then
      echo "  [OK] 便携 Node 锁定=${REA_NODE_VERSION}（与当前 LTS ${NODE_LTS} 一致）"
    else
      printf '  \033[33m[WARN]\033[0m 便携 Node 锁定=%s，当前 Node LTS=%s（升级前需全链路验证门禁 ^22.19||^24.11||>=26）\n' \
        "$REA_NODE_VERSION" "$NODE_LTS"
    fi
  else
    echo "  [SKIP] 未能解析 Node LTS"
  fi
else
  echo "  [SKIP] 无法访问 nodejs.org（离线？），跳过 Node 漂移比对"
fi

# GHA action：列出 CI 里 pin 的 action@ref，best-effort 查每个 action 的最新 major。
# 仅打印报告；发现更新 major 时 WARN，不自动 bump（需人工评估破坏性）。
echo "  -- CI 中固定的 GHA actions --"
grep -hoE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@v[0-9]+' "$REPO_ROOT/.github/workflows/"*.yml 2>/dev/null \
  | sort -u | while read -r spec; do
      echo "     $spec"
    done
# best-effort：对核心 action 查最新 release major（限流/离线静默跳过）
for act in actions/checkout actions/setup-node actions/cache docker/build-push-action; do
  rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$act/releases/latest" 2>/dev/null || true)"
  [ -n "$rel" ] || continue
  latest_tag="$(printf '%s' "$rel" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)"
  [ -n "$latest_tag" ] || continue
  used="$(grep -hoE "$act@v[0-9]+" "$REPO_ROOT/.github/workflows/"*.yml 2>/dev/null | head -1 | grep -oE 'v[0-9]+$' || true)"
  if [ -n "$used" ]; then
    lm="$(printf '%s' "$latest_tag" | grep -oE '^v[0-9]+' || true)"
    if [ -n "$lm" ] && [ "$used" != "$lm" ]; then
      printf '  \033[33m[WARN]\033[0m %s 本地 pin %s，上游最新 %s（评估破坏性后再升级）\n' "$act" "$used" "$lm"
    else
      echo "  [OK] $act pin ${used}（与最新 major ${lm:-?} 持平）"
    fi
  fi
done

echo
if [ "$FAIL" -ne 0 ]; then
  echo "版本一致性检查：失败"; exit 1
fi
echo "版本一致性检查：通过"

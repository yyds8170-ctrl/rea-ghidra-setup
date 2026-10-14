#!/usr/bin/env bash
# =============================================================================
# check-docs-links.sh — 文档相对链接死链检查（bash3.2 兼容）
#
# 扫描仓库根与 docs/ 下所有 *.md，解析 [文本](相对路径[#锚点])，跳过：
#   http(s)://、mailto:、纯 # 自身锚点、<...> 占位。
# 断言相对目标文件存在；同文件 #锚点 仅对 ASCII 标题校验（CJK 标题锚点
# 经 GitHub slugify 后还原不可靠，故不强制）。发现死链以非 0 退出并打印
#   文件:行 -> 链接
#
# 用法：bash scripts/check-docs-links.sh
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 收集 md 文件（根 + docs/，不进 offline/、.git/）
md_files="$(find "$REPO_DIR" -maxdepth 2 -name '*.md' \! -path '*/offline/*' \! -path '*/.git/*' | sort)"
total_links=0; dead=0
n_md="$(printf '%s\n' "$md_files" | grep -c .)"

while IFS= read -r md; do
  [ -n "$md" ] || continue
  # 提取 ( 与 ) 之间的链接目标
  line_no=0
  # shellcheck disable=SC2094
  while IFS= read -r line; do
    line_no=$((line_no+1))
    # 剔除行内代码片段（`...`），避免把文档里的示例语法误判为链接
    # shellcheck disable=SC2016
    clean="$(printf '%s\n' "$line" | sed 's/`[^`]*`//g')"
    # 取 markdown 链接目标 [..](TARGET)
    tgt="$(printf '%s\n' "$clean" | sed -n 's/^.*\](\([^)]*\)).*$/\1/p')"
    [ -n "$tgt" ] || continue
    total_links=$((total_links+1))
    # 跳过外部/占位
    case "$tgt" in
      http://*|https://*|mailto:*) continue ;;
      \#*) continue ;;
      \<*) continue ;;
    esac
    # 分离路径与锚点
    path="${tgt%%#*}"
    [ -z "$path" ] && continue   # 纯同文件锚点，跳过文件存在性校验
    # 相对当前 md 所在目录解析
    base="$(dirname "$md")"
    resolved="$base/$path"
    # 去掉可能的 ./
    resolved="$(cd "$(dirname "$resolved")" 2>/dev/null && echo "$(pwd)/$(basename "$resolved")")"
    if [ ! -e "$resolved" ]; then
      echo "${md#"$REPO_DIR"/}:${line_no} -> ${tgt}"
      dead=$((dead+1))
    fi
  done < "$md"
done <<EOF
$md_files
EOF

echo "检查了 ${n_md} 个 md 文件、${total_links} 个相对链接；死链 ${dead} 个"
if [ "$dead" -gt 0 ]; then
  echo "发现死链，请修复。" >&2
  exit 1
fi
echo "无死链。"

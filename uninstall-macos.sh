#!/usr/bin/env bash
# =============================================================================
# uninstall-macos.sh — 卸载 install-macos.sh 安装的 JDK / Ghidra / 便携 Node
#
# 仅删除本项目安装在 ~/tools 的内容，并清理 ~/.zshrc / ~/.bash_profile 中的
# 环境块；不删除 REA 缓存、其他软件与用户数据。
# 用法：bash uninstall-macos.sh        （交互确认）
#       bash uninstall-macos.sh --yes  （跳过确认）
# =============================================================================
set -uo pipefail

[ "$(uname -s)" = Darwin ] || { echo "本脚本仅用于 macOS（Linux 请用 uninstall.sh）" >&2; exit 1; }

TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
BLOCK_START="# >>> REA + Ghidra env >>>"
BLOCK_END="# <<< REA + Ghidra env <<<"
RC_FILES=("$HOME/.zshrc" "$HOME/.bash_profile")

JDK_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' 2>/dev/null || true)"
GHIDRA_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null || true)"
NODE_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 \( -name 'node-v*' -o -name 'node' \) 2>/dev/null || true)"
indent() { while IFS= read -r line; do echo "  $line"; done; }

echo "将删除以下内容（如存在）："
[ -n "$JDK_TARGETS" ]    && indent <<< "$JDK_TARGETS"
[ -n "$GHIDRA_TARGETS" ] && indent <<< "$GHIDRA_TARGETS"
[ -n "$NODE_TARGETS" ]   && indent <<< "$NODE_TARGETS"
for rc in "${RC_FILES[@]}"; do
  grep -qF "$BLOCK_START" "$rc" 2>/dev/null && echo "  $rc 中的 REA + Ghidra 环境块"
done

if [ "${1:-}" != "--yes" ]; then
  printf "确认删除？输入 y 继续："
  read -r ans
  [ "$ans" = "y" ] || { echo "已取消"; exit 0; }
fi

# 1. 清理各 rc 文件的标记块
for rc in "${RC_FILES[@]}"; do
  if [ -f "$rc" ] && grep -qF "$BLOCK_START" "$rc" 2>/dev/null; then
    TMP="$(mktemp)"
    awk -v s="$BLOCK_START" -v e="$BLOCK_END" \
      '$0==s{skip=1;next} $0==e{skip=0;next} !skip{print}' \
      "$rc" > "$TMP" && mv "$TMP" "$rc"
    echo "[1/3] 已移除 $rc 环境块"
  fi
done
echo "[1/3] 环境块清理完成"

# 2. 删除 Ghidra
if [ -n "$GHIDRA_TARGETS" ]; then
  echo "$GHIDRA_TARGETS" | xargs rm -rf
  echo "[2/3] 已删除 Ghidra"
else
  echo "[2/3] 未发现 Ghidra，跳过"
fi

# 3. 删除 JDK 与便携 Node
if [ -n "$JDK_TARGETS" ]; then echo "$JDK_TARGETS" | xargs rm -rf; echo "已删除 JDK 21"; fi
rm -f "$TOOLS_DIR/jdk21"
if [ -n "$NODE_TARGETS" ]; then echo "$NODE_TARGETS" | xargs rm -rf; echo "已删除便携 Node"; fi
echo "[3/3] JDK / Node 清理完成"

echo
echo "若全局安装过 REA，可执行：npm uninstall --global rea-agents"
echo "清理 REA 缓存（可选）：rm -rf ~/.rea"
echo "卸载完成。新开终端或执行 source ~/.zshrc 以刷新环境。"

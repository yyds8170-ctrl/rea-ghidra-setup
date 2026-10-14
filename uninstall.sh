#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — 卸载 install.sh 安装的 JDK / Ghidra，并清理 ~/.bashrc 环境块
#
# 仅删除本项目安装的内容；不删除 REA 缓存、其他软件与用户数据。
# 用法：bash uninstall.sh        （交互确认）
#       bash uninstall.sh --yes  （跳过确认）
# =============================================================================
set -uo pipefail

TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
BLOCK_START="# >>> REA + Ghidra env >>>"
BLOCK_END="# <<< REA + Ghidra env <<<"
RC_FILE="$HOME/.bashrc"

JDK_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' 2>/dev/null || true)"
GHIDRA_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null || true)"
indent() { while IFS= read -r line; do echo "  $line"; done; }

echo "将删除以下内容："
[ -n "$JDK_TARGETS" ]    && indent <<< "$JDK_TARGETS"
[ -n "$GHIDRA_TARGETS" ] && indent <<< "$GHIDRA_TARGETS"
grep -qF "$BLOCK_START" "$RC_FILE" 2>/dev/null && echo "  $RC_FILE 中的 REA + Ghidra 环境块"

if [ "${1:-}" != "--yes" ]; then
  printf "确认删除？输入 y 继续："
  read -r ans
  [ "$ans" = "y" ] || { echo "已取消"; exit 0; }
fi

# 1. 清理 ~/.bashrc 标记块（标记块之外的用户配置原样保留）
if grep -qF "$BLOCK_START" "$RC_FILE" 2>/dev/null; then
  TMP="$(mktemp)"
  awk -v s="$BLOCK_START" -v e="$BLOCK_END" \
    '$0==s{skip=1;next} $0==e{skip=0;next} !skip{print}' \
    "$RC_FILE" > "$TMP" && mv "$TMP" "$RC_FILE"
  echo "[1/3] 已移除 $RC_FILE 环境块"
else
  echo "[1/3] $RC_FILE 中无环境块，跳过"
fi

# 2. 删除 Ghidra
if [ -n "$GHIDRA_TARGETS" ]; then
  echo "$GHIDRA_TARGETS" | xargs -r rm -rf
  echo "[2/3] 已删除 Ghidra"
else
  echo "[2/3] 未发现 Ghidra，跳过"
fi

# 3. 删除 JDK
if [ -n "$JDK_TARGETS" ]; then
  echo "$JDK_TARGETS" | xargs -r rm -rf
  echo "[3/3] 已删除 JDK 21"
else
  echo "[3/3] 未发现 JDK 21，跳过"
fi

echo
echo "若全局安装过 REA，可执行：npm uninstall --global rea-agents"
echo "清理 REA 缓存（可选）：rm -rf ~/.rea"
echo "卸载完成。新开终端或执行 source ~/.bashrc 以刷新环境。"

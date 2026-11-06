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

# v4.0.4（FIX-8）：--help/-h 只打印用法并退出 0，绝不进入删除/交互确认（旧行为是
# 用户敲 --help 却直接跑了完整卸载流程）。
case "${1:-}" in
  -h|--help)
    cat <<'EOF'
uninstall.sh — 卸载 install.sh 安装的 JDK / Ghidra，并清理 ~/.bashrc 环境块

用法：
  bash uninstall.sh           （列出将删除的内容，交互确认 y 后执行）
  bash uninstall.sh --yes     （跳过确认直接执行）
  bash uninstall.sh --help    （本帮助，不做任何改动）

仅删除本项目安装的内容；不删除 REA 缓存、其他软件与用户数据。
EOF
    exit 0
    ;;
esac

JDK_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' 2>/dev/null || true)"
GHIDRA_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null || true)"
# 便携 Node（与 install.sh 安装的 node-v<ver>-linux-<arch> 目录及 node 软链对应）
NODE_TARGETS="$(find "$TOOLS_DIR" -maxdepth 1 \( -name 'node-v*-linux-*' -o -name 'node' \) 2>/dev/null || true)"
indent() { while IFS= read -r line; do echo "  $line"; done; }

echo "将删除以下内容："
[ -n "$JDK_TARGETS" ]    && indent <<< "$JDK_TARGETS"
[ -n "$GHIDRA_TARGETS" ] && indent <<< "$GHIDRA_TARGETS"
[ -n "$NODE_TARGETS" ]   && indent <<< "$NODE_TARGETS"
[ -e "$TOOLS_DIR/current-ghidra" ] && echo "  $TOOLS_DIR/current-ghidra（软链）"
[ -e "$TOOLS_DIR/current-jdk" ]    && echo "  $TOOLS_DIR/current-jdk（软链）"
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
  echo "[1/4] 已移除 $RC_FILE 环境块"
else
  echo "[1/4] $RC_FILE 中无环境块，跳过"
fi

# v4.0.5（D4）：旧实现 `echo "$X" | xargs -r rm -rf` 对含空格路径会按空白分词，
# 且 -r 是 GNU xargs 扩展（macOS BSD xargs 无此选项）。改为逐行 read 安全删除：
# 每行一个目标，空格/中文原样保留，rm -- 结束选项解析防路径以 - 开头。
# v4.4：hpvs_fs 上 rm -rf 偶发 "Directory not empty"，带限重试后再如实返回。
safe_rm() { # $1=路径
  local tgt="$1"
  [ -e "$tgt" ] || [ -L "$tgt" ] || return 0
  for _ in 1 2 3; do
    rm -rf -- "$tgt" 2>/dev/null || true
    [ -e "$tgt" ] || [ -L "$tgt" ] || return 0
    sleep 0.3
  done
  rm -rf -- "$tgt"
}
# set -uo pipefail（无 -e）：while 走管道子进程，本处删完即弃，无需回传变量。
delete_targets() { # $1=find 输出（换行分隔）
  [ -n "$1" ] || return 0
  printf '%s\n' "$1" | while IFS= read -r d; do
    [ -n "$d" ] && safe_rm "$d"
  done
}

# 2. 删除 Ghidra
if [ -n "$GHIDRA_TARGETS" ]; then
  delete_targets "$GHIDRA_TARGETS"
  echo "[2/4] 已删除 Ghidra"
else
  echo "[2/4] 未发现 Ghidra，跳过"
fi

# 3. 删除 JDK
if [ -n "$JDK_TARGETS" ]; then
  delete_targets "$JDK_TARGETS"
  echo "[3/4] 已删除 JDK 21"
else
  echo "[3/4] 未发现 JDK 21，跳过"
fi

# 4. 删除便携 Node、current-* 软链与残留安装锁（避免悬空软链/半成品残留）
if [ -n "$NODE_TARGETS" ]; then
  delete_targets "$NODE_TARGETS"
  echo "      已删除便携 Node"
fi
safe_rm "$TOOLS_DIR/current-ghidra"
safe_rm "$TOOLS_DIR/current-jdk"
safe_rm "$TOOLS_DIR/current.previous"
safe_rm "$TOOLS_DIR/.install.lock"
echo "[4/4] Node / current 软链 / 安装锁清理完成"

echo
echo "若全局安装过 REA，可执行：npm uninstall --global rea-agents"
echo "清理 REA 缓存（可选）：rm -rf ~/.rea"
echo "卸载完成。新开终端或执行 source ~/.bashrc 以刷新环境。"

#!/usr/bin/env bash
# =============================================================================
# ghidra-decompile.sh — 用 Ghidra 原生 headless 批量反编译所有函数
#
# 不依赖 REA / Node / npm，适合只想把整个二进制反编译出来的场景。
# 用法：./scripts/ghidra-decompile.sh <二进制> [输出目录] [separate|combined]
#   separate：每个函数一个 .c（默认）
#   combined：合并为一个 decompiled.c
# 示例：./scripts/ghidra-decompile.sh ./demo ./out combined
# =============================================================================
set -euo pipefail

BIN="${1:-}"
OUTDIR="${2:-./decompiled}"
MODE="${3:-separate}"
if [ -z "$BIN" ] || [ ! -f "$BIN" ]; then
  echo "用法: $0 <二进制> [输出目录] [separate|combined]" >&2
  exit 1
fi
if [ "$MODE" != "separate" ] && [ "$MODE" != "combined" ]; then
  echo "模式必须是 separate 或 combined" >&2
  exit 1
fi

# 定位 Ghidra / JDK（环境变量优先，其次 ~/tools）
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-$(find "$HOME/tools" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null | head -1)}"
if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]; then
  echo "未找到 Ghidra，请先运行 install.sh 或设置 GHIDRA_INSTALL_DIR" >&2
  exit 1
fi
JHOME="${JAVA_HOME:-$(find "$HOME/tools" -maxdepth 1 -name 'jdk-21*' 2>/dev/null | head -1)}"
if [ -n "$JHOME" ]; then export JAVA_HOME="$JHOME"; export PATH="$JHOME/bin:$PATH"; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(mktemp -d)"
trap 'rm -rf "$PROJ_DIR"' EXIT
mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"

"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$PROJ_DIR" Proj \
  -import "$BIN" \
  -scriptPath "$SCRIPT_DIR" \
  -postScript DecompileAll.java "$OUTDIR" "$MODE" \
  -deleteProject

# v6.0.6：analyzeHeadless 对空/垃圾/非二进制只打 ERROR REPORT 仍返回 0。
# 校验反编译产物真实存在，否则把导入失败误报成成功。
if [ "$MODE" = "combined" ]; then
  [ -s "$OUTDIR/decompiled.c" ] || {
    echo "[ERR] 未产出 decompiled.c（Ghidra 导入失败：空/损坏/非二进制？）" >&2; exit 1; }
else
  # separate：至少应有一个 .c 产物
  found=0
  for f in "$OUTDIR"/*.c; do [ -e "$f" ] && { found=1; break; }; done
  [ "$found" = 1 ] || {
    echo "[ERR] 未产出任何 .c 反编译文件（Ghidra 导入失败：空/损坏/非二进制？）" >&2; exit 1; }
fi

echo "完成，输出目录：$OUTDIR"

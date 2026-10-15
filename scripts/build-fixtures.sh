#!/usr/bin/env bash
# =============================================================================
# build-fixtures.sh — 编译多架构 fixture（ELF64 原生 / ELF32 / AArch64 ELF / PE32）
#
# 产物写入 examples/fixtures/（gitignore，不入库）；源码在 examples/fixtures_src/。
# v4.0.4（FIX-7）：
#   - 先构建一个【必成】的 native x86_64 目标（gcc fixture.c），普通无交叉工具链
#     的 x86_64 机器也能 built>=1、exit 0，不再必然失败；
#   - 构建前清空 examples/fixtures/ 旧产物，保证输出与本次运行一一对应
#     （避免上一台工具链齐全机器留下的 aarch64/pe32.exe 残留误导）。
# 缺某个交叉编译器时跳过对应产物并打印提示（不假装成功）。
#
# 用法：scripts/build-fixtures.sh
# =============================================================================
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_DIR/examples/fixtures_src/fixture.c"
OUT="$REPO_DIR/examples/fixtures"
[ -f "$SRC" ] || { echo "build-fixtures: 缺少 $SRC" >&2; exit 1; }

# v4.0.4：构建前清空旧产物（FIX-7b），保证 examples/fixtures/ 全为本次生成。
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -delete

built=0; skipped=0
try_build() { # name compiler outfile [extra flags...]
  local name="$1" cc="$2" out="$3"; shift 3
  if command -v "$cc" >/dev/null 2>&1; then
    if "$cc" -O0 "$@" -o "$OUT/$out" "$SRC" 2>"$OUT/$out.log"; then
      echo "[build] $name -> $OUT/$out ($(file -b "$OUT/$out" | cut -d, -f1))"
      built=$((built+1))
    else
      echo "[skip] $name 编译失败（见 $OUT/$out.log）" >&2; skipped=$((skipped+1))
    fi
  else
    echo "[skip] ${name}：未找到编译器 ${cc}" >&2; skipped=$((skipped+1))
  fi
}

# ---- native x86_64：必成目标（FIX-7a）。普通开发/CI 机器都带 gcc/cc，
#      保证 built>=1；交叉工具链缺失时其它目标跳过，脚本仍 exit 0。
NATIVE_CC="gcc"; command -v gcc >/dev/null 2>&1 || NATIVE_CC="cc"
try_build "ELF64 (x86_64 原生)" "$NATIVE_CC" "linux_x86_64"

# ELF32 优先用 i686 交叉编译器（与 aarch64/mingw 同为跨目标，不依赖 gcc-multilib，
# 可避免 Ubuntu 24.04 上 gcc-multilib 与原生 gcc 版本冲突）；缺失时回退 gcc -m32。
if command -v i686-linux-gnu-gcc >/dev/null 2>&1; then
  try_build "ELF32 (x86 32-bit, i686 交叉)" "i686-linux-gnu-gcc" "elf32"
else
  try_build "ELF32 (x86 32-bit, gcc -m32)" "gcc" "elf32" -m32
fi
try_build "AArch64 ELF"           "aarch64-linux-gnu-gcc" "aarch64"
try_build "PE32 (mingw i686)"    "i686-w64-mingw32-gcc"   "pe32.exe"

echo "build-fixtures: built=$built skipped=$skipped"
# 至少要有一个架构编译成功（native x86_64 目标通常兜底）；全跳过则报错
[ "$built" -ge 1 ] || { echo "build-fixtures: 没有任何架构编译成功（连 native gcc 都不可用？）" >&2; exit 1; }

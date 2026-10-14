#!/usr/bin/env bash
# =============================================================================
# verify.sh — Linux 端到端自检（ELF）
#
# 编译 examples/demo，真实调用 REA 的 Ghidra provider：
#   1) analyze 识别 ELF / 架构 / 函数数 / 字符串
#   2) decompile secret_check：observed，含 0x539（1337）
#   3) decompile calc_discount：observed，含 0x32（50）
#   4) 剥离符号版仍可导入分析
#
# 断言逻辑统一走 scripts/verify-check.js（与 verify-macos.sh / verify.ps1 一致）。
# 全部通过退出码 0；任一失败退出码 1。可作为 CI 的一个步骤。
# 用法：bash verify.sh
#   可覆盖：REA_VERSION=6.4.0 GHIDRA_INSTALL_DIR=... JAVA_HOME=... ./verify.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_versions   # REA_VERSION 等默认值来自 config/versions.env
EX_DIR="$SCRIPT_DIR/examples"
CHECK="$SCRIPT_DIR/scripts/verify-check.js"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0; FAIL=0
ok()   { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
info() { printf '  \033[36m[....]\033[0m %s\n' "$1"; }

# ---- 定位 JDK 21 / Ghidra（Ghidra 12.1 要求 JDK 21+）-----------------------
jdk_major_of() {
  "$1/bin/java" -version 2>&1 | awk -F'"' '/version/ {
    split($2,a,"."); v=a[1]; if(v=="1") v=a[2]; print v; exit
  }'
}
# 现有 JAVA_HOME 缺失或版本低于 21（如 CI runner 预置 JDK17）时，改用 ~/tools
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME:-/nonexistent}/bin/java" ] \
     || [ "$(jdk_major_of "$JAVA_HOME" 2>/dev/null || echo 0)" -lt 21 ]; then
  JHOME="$(find "$HOME/tools" -maxdepth 1 -name 'jdk-21*' 2>/dev/null | head -1 || true)"
  if [ -n "$JHOME" ]; then export JAVA_HOME="$JHOME"; fi
fi
if [ -z "${GHIDRA_INSTALL_DIR:-}" ]; then
  GDIR="$(find "$HOME/tools" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null | head -1 || true)"
  if [ -n "$GDIR" ]; then export GHIDRA_INSTALL_DIR="$GDIR"; fi
fi
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"

# REA：优先全局 rea，否则 npx 锁定版本
if command -v rea >/dev/null 2>&1; then REA=(rea); else REA=(npx -y "rea-agents@${REA_VERSION}"); fi

# 用 search 解析 Ghidra 内的真实函数名（Mach-O 带 _ 前缀，统一做法保证跨平台一致）
resolve_func() {
  local pattern="$1" out="$WORKDIR/search-$1.json"
  "${REA[@]}" search "$EX_DIR/demo" "$pattern" --provider ghidra --kind procedures \
      --mode regex --format json --snapshot "$WORKDIR/demo.snap" >"$out" 2>/dev/null
  node "$CHECK" funcname "$out" "$pattern" 2>/dev/null
}

# REA 失败时错误信封（{"error":...,"message":...}）写到 stdout，stderr 常为空
show_rea_error() {
  local json="$1" err="$2"
  if [ -s "$json" ] && grep -q '"error"' "$json" 2>/dev/null; then
    node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1]));console.log("    REA: "+(j.message||j.error||JSON.stringify(j).slice(0,400)));}catch(e){}' "$json"
  fi
  [ -s "$err" ] && tail -8 "$err" | sed 's/^/    /'
}

echo "== 环境 =="
echo "  JAVA_HOME          = ${JAVA_HOME:-（未设置，依赖 PATH）}"
echo "  GHIDRA_INSTALL_DIR = ${GHIDRA_INSTALL_DIR:-（未设置）}"
echo "  REA 调用           = ${REA[*]}"
java -version 2>&1 | head -1 | sed 's/^/  /'
command -v node >/dev/null 2>&1 || { echo "缺少 node（REA 要求 Node 22.19+/24.11+/26+）" >&2; exit 1; }

# ---- 1. 前置检查 ------------------------------------------------------------
echo "== 1. 前置检查 =="
if command -v node >/dev/null 2>&1; then ok "node 存在"; else bad "缺少 node"; fi
if command -v gcc  >/dev/null 2>&1; then ok "gcc 存在";  else bad "缺少 gcc"; fi
if [ -x "${GHIDRA_INSTALL_DIR:-/nonexistent}/support/analyzeHeadless" ]; then
  ok "analyzeHeadless 存在"
else
  bad "未找到 Ghidra analyzeHeadless（请先运行 install.sh）"
fi

# ---- 2. 编译测试程序 --------------------------------------------------------
echo "== 2. 编译 demo =="
if make -C "$EX_DIR" clean >/dev/null && make -C "$EX_DIR" >/dev/null 2>"$WORKDIR/make.err"; then
  ok "demo 与 demo_stripped 编译无警告"
else
  bad "demo 编译失败（见 $WORKDIR/make.err）"; cat "$WORKDIR/make.err"
fi

# ---- 3. analyze（含符号）---------------------------------------------------
echo "== 3. analyze demo =="
info "首次分析会启动 Ghidra headless，可能需 1-3 分钟…"
if "${REA[@]}" analyze "$EX_DIR/demo" --provider ghidra --format json \
     --snapshot "$WORKDIR/demo.snap" >"$WORKDIR/analyze.json" 2>"$WORKDIR/analyze.err"; then
  ok "analyze 命令成功"
  if ck="$(node "$CHECK" analyze "$WORKDIR/analyze.json" elf 2>&1)"; then
    ok "识别 ELF / 架构 / 函数数(>=3) / 字符串（${ck#PASS|}）"
  else
    bad "analyze 结构不符（${ck#FAIL|}）"
  fi
else
  bad "analyze 失败（见 $WORKDIR/analyze.err）"; show_rea_error "$WORKDIR/analyze.json" "$WORKDIR/analyze.err"
fi

# ---- 4/5. decompile 两个函数 ------------------------------------------------
decomp_check() {
  local want="$1" const="$2" json="$3" err="$4"
  local name
  name="$(resolve_func "$want")"
  [ -z "$name" ] && name="$want"
  if "${REA[@]}" decompile "$EX_DIR/demo" "$name" --provider ghidra --format json \
       --snapshot "$WORKDIR/demo.snap" >"$json" 2>"$err"; then
    local r
    r="$(node "$CHECK" decompile "$json" "$want" "$const" 2>&1)"
    if [ "${r%%|*}" = "PASS" ]; then ok "$want 还原（observed，含 ${const}，${r#PASS|}）"
    else bad "$want 结果不符（${r#FAIL|}）"; fi
  else
    bad "$want 反编译失败（见 ${err}）"; show_rea_error "$json" "$err"
  fi
}
echo "== 4. decompile secret_check =="
decomp_check secret_check 0x539 "$WORKDIR/decomp.json" "$WORKDIR/decomp.err"
echo "== 5. decompile calc_discount =="
decomp_check calc_discount 0x32 "$WORKDIR/discount.json" "$WORKDIR/discount.err"

# ---- 6. analyze（剥离符号）-------------------------------------------------
echo "== 6. analyze demo_stripped（无符号）=="
if "${REA[@]}" analyze "$EX_DIR/demo_stripped" --provider ghidra --format json \
     --snapshot "$WORKDIR/stripped.snap" >"$WORKDIR/stripped.json" 2>"$WORKDIR/stripped.err"; then
  if ck="$(node "$CHECK" count "$WORKDIR/stripped.json" 3 2>&1)"; then
    ok "无符号二进制仍可导入分析（${ck#PASS|}）"
  else bad "stripped 函数数异常（${ck#FAIL|}）"; fi
else
  bad "stripped analyze 失败（见 $WORKDIR/stripped.err）"; show_rea_error "$WORKDIR/stripped.json" "$WORKDIR/stripped.err"
fi

# ---- 汇总 -------------------------------------------------------------------
echo ""
echo "================================================"
echo " 结果：$PASS 通过 / $FAIL 失败（Linux）"
echo "================================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

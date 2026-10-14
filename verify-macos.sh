#!/usr/bin/env bash
# =============================================================================
# verify-macos.sh — macOS 端到端自检（Mach-O）
#
# 用系统 cc（clang）编译 examples/demo，真实调用 REA 的 Ghidra provider：
#   1) analyze 识别 Mach-O / 架构 / 函数数 / 字符串
#   2) decompile secret_check：observed，含 0x539（1337）
#   3) decompile calc_discount：observed，含 0x32（50）
#   4) 剥离符号版仍可导入分析
#
# 前置：先运行 install-macos.sh（Apple Silicon 上会构建 mac_arm_64 native）。
# 与 verify.sh（Linux）断言一致，仅目标格式（Mach-O vs ELF）与 JDK 目录不同。
# 用法：bash verify-macos.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_versions
EX_DIR="$SCRIPT_DIR/examples"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0; FAIL=0
ok()   { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
info() { printf '  \033[36m[....]\033[0m %s\n' "$1"; }

[ "$(uname -s)" = Darwin ] || { echo "verify-macos.sh 仅用于 macOS" >&2; exit 1; }
ARCH="$(normalize_arch)"

# ---- 定位 JDK 21（macOS 布局为 <bundle>/Contents/Home）---------------------
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME:-/nonexistent}/bin/java" ]; then
  JHOME="$(find "$HOME/tools" -maxdepth 3 -type d -path '*/Contents/Home' 2>/dev/null | grep 'jdk-21' | head -1 || true)"
  [ -n "$JHOME" ] && export JAVA_HOME="$JHOME"
fi
if [ -z "${GHIDRA_INSTALL_DIR:-}" ]; then
  GDIR="$(find "$HOME/tools" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null | head -1 || true)"
  [ -n "$GDIR" ] && export GHIDRA_INSTALL_DIR="$GDIR"
fi
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"
NATIVE_OS_DIR="mac_x86_64"; [ "$ARCH" = "aarch64" ] && NATIVE_OS_DIR="mac_arm_64"

# REA：优先全局 rea，否则 npx 锁定版本
if command -v rea >/dev/null 2>&1; then REA=(rea); else REA=(npx -y "rea-agents@${REA_VERSION}"); fi

echo "== 环境（macOS/$ARCH）=="
echo "  JAVA_HOME          = ${JAVA_HOME:-（未设置）}"
echo "  GHIDRA_INSTALL_DIR = ${GHIDRA_INSTALL_DIR:-（未设置）}"
echo "  REA 调用           = ${REA[*]}"
java -version 2>&1 | head -1 | sed 's/^/  /'
command -v node >/dev/null 2>&1 || { echo "缺少 node（REA 要求 Node 22.19+/24.11+/26+）" >&2; exit 1; }

# ---- 1. 前置检查 ------------------------------------------------------------
echo "== 1. 前置检查 =="
if command -v node >/dev/null 2>&1; then ok "node 存在"; else bad "缺少 node"; fi
if command -v cc >/dev/null 2>&1; then
  ok "cc(clang) 存在"
else
  bad "缺少 cc（请运行 xcode-select --install）"
fi
if [ -x "${GHIDRA_INSTALL_DIR:-/nonexistent}/support/analyzeHeadless" ]; then
  ok "analyzeHeadless 存在"
else
  bad "未找到 analyzeHeadless（请先运行 install-macos.sh）"
fi
if [ -x "${GHIDRA_INSTALL_DIR:-/nonexistent}/Ghidra/Features/Decompiler/os/$NATIVE_OS_DIR/decompile" ]; then
  ok "native decompiler 存在（$NATIVE_OS_DIR）"
else
  bad "native decompiler 缺失（$NATIVE_OS_DIR）：bash scripts/build-ghidra-native.sh"
fi

# ---- 2. 编译 demo（clang 产出 Mach-O）--------------------------------------
echo "== 2. 编译 demo（Mach-O）=="
if make -C "$EX_DIR" clean >/dev/null && make -C "$EX_DIR" >/dev/null 2>"$WORKDIR/make.err"; then
  ok "demo 与 demo_stripped 编译无警告"
else
  bad "demo 编译失败（见 $WORKDIR/make.err）"; cat "$WORKDIR/make.err"
fi

# ---- 3. analyze（Mach-O）---------------------------------------------------
echo "== 3. analyze demo =="
info "首次分析会启动 Ghidra headless，可能需 1-3 分钟…"
if "${REA[@]}" analyze "$EX_DIR/demo" --provider ghidra --format json \
     --snapshot "$WORKDIR/demo.snap" >"$WORKDIR/analyze.json" 2>"$WORKDIR/analyze.err"; then
  AOK="$(node -e '
    const j=JSON.parse(require("fs").readFileSync(process.argv[1]));
    const s=j.subject||{}, n=j.normalized_result||{};
    const fmt=String(s.format||"").toLowerCase();
    const ok=fmt.includes("mach") && (n.procedure_count||0)>=3 && (n.string_count||0)>0;
    console.log((ok?"1":"0")+"|format="+s.format+" arch="+s.architecture+
                " procedures="+n.procedure_count+" strings="+n.string_count);
  ' "$WORKDIR/analyze.json")"
  if [ "${AOK%%|*}" = "1" ]; then ok "识别 Mach-O / 架构 / 函数数(>=3) / 字符串（${AOK#1|}）"
  else bad "analyze 结构不符（${AOK#0|}）"; fi
else
  bad "analyze 失败（见 $WORKDIR/analyze.err）"; tail -5 "$WORKDIR/analyze.err"
fi

# ---- 4/5. decompile 两个函数 ------------------------------------------------
decomp_check() {
  local func="$1" const="$2" json="$3" err="$4"
  if "${REA[@]}" decompile "$EX_DIR/demo" "$func" --provider ghidra --format json \
       --snapshot "$WORKDIR/demo.snap" >"$json" 2>"$err"; then
    local r
    r="$(node -e '
      const j=JSON.parse(require("fs").readFileSync(process.argv[1]));
      const code=String(j.normalized_result||"");
      const ok=j.confidence==="observed" && code.includes(process.argv[2]) && code.includes(process.argv[3]);
      console.log((ok?"1":"0")+"|confidence="+j.confidence);
    ' "$json" "$func" "$const")"
    if [ "${r%%|*}" = "1" ]; then ok "$func 还原（observed，含 $const，${r#1|}）"
    else bad "$func 结果不符（${r#0|}）"; fi
  else
    bad "$func 反编译失败（见 $err）"; tail -5 "$err"
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
  SC="$(node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1]));console.log((j.normalized_result||{}).procedure_count||0)' "$WORKDIR/stripped.json")"
  if [ "${SC:-0}" -ge 3 ]; then ok "无符号二进制仍可导入分析（procedures=$SC）"
  else bad "stripped 函数数异常（procedures=$SC）"; fi
else
  bad "stripped analyze 失败（见 $WORKDIR/stripped.err）"; tail -5 "$WORKDIR/stripped.err"
fi

# ---- 汇总 -------------------------------------------------------------------
echo ""
echo "================================================"
echo " 结果：$PASS 通过 / $FAIL 失败（macOS/$ARCH）"
echo "================================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

#!/usr/bin/env bash
# =============================================================================
# verify.sh — REA + Ghidra 端到端自检
#
# 编译 examples/demo，真实调用 REA 的 Ghidra provider：
#   1) analyze  能识别 ELF / 架构 / 函数数量
#   2) decompile 能还原 secret_check 且置信度 observed、常量 0x539 可见
#   3) 剥离符号版仍可被导入分析
#
# 全部通过退出码 0；任一失败退出码 1。可作为 CI 的一个步骤。
# 用法：./verify.sh
#   可覆盖：REA_VERSION=6.4.0 GHIDRA_INSTALL_DIR=... JAVA_HOME=... ./verify.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EX_DIR="$SCRIPT_DIR/examples"
REA_VERSION="${REA_VERSION:-6.4.0}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0; FAIL=0
ok()   { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
info() { printf '  \033[36m[....]\033[0m %s\n' "$1"; }

# ---- 定位 JDK 21 / Ghidra（Ghidra 12.1 要求 JDK 21+）-----------------------
# 读取某个 JDK 目录的主版本号（兼容 "1.8" 与 "21" 两种输出）
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
if [ -n "${JAVA_HOME:-}" ]; then export PATH="$JAVA_HOME/bin:$PATH"; fi

# REA 调用：优先 PATH 上的 rea，否则用 npx 拉取已发布版本
if command -v rea >/dev/null 2>&1; then
  REA=(rea)
else
  REA=(npx -y "rea-agents@${REA_VERSION}")
fi

echo "== 环境 =="
echo "  JAVA_HOME          = ${JAVA_HOME:-（未设置，依赖 PATH）}"
echo "  GHIDRA_INSTALL_DIR = ${GHIDRA_INSTALL_DIR:-（未设置）}"
echo "  REA 调用           = ${REA[*]}"
java -version 2>&1 | head -1 | sed 's/^/  /'

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
  AOK="$(python3 -c "
import json
d=json.load(open('$WORKDIR/analyze.json')); s=d['subject']; nr=d['normalized_result']
good = s['format']=='elf' and nr['procedure_count']>=3 and nr['string_count']>0
print(('1' if good else '0') + '|' +
      f'format={s[\"format\"]} arch={s[\"architecture\"]} procedures={nr[\"procedure_count\"]} strings={nr[\"string_count\"]}')
")"
  if [ "${AOK%%|*}" = "1" ]; then
    ok "识别 ELF / 架构 / 函数数(>=3) / 字符串（${AOK#1|}）"
  else
    bad "analyze 结构不符（${AOK#0|}）"
  fi
else
  bad "analyze 失败（见 $WORKDIR/analyze.err）"; tail -5 "$WORKDIR/analyze.err"
fi

# ---- 4. decompile secret_check（含符号）------------------------------------
echo "== 4. decompile secret_check =="
if "${REA[@]}" decompile "$EX_DIR/demo" secret_check --provider ghidra --format json \
     --snapshot "$WORKDIR/demo.snap" >"$WORKDIR/decomp.json" 2>"$WORKDIR/decomp.err"; then
  DOK="$(python3 -c "
import json
d=json.load(open('$WORKDIR/decomp.json'))
code=d.get('normalized_result','')
good = d.get('confidence')=='observed' and 'secret_check' in code and '0x539' in code
print(('1' if good else '0') + '|confidence=' + str(d.get('confidence')))
")"
  if [ "${DOK%%|*}" = "1" ]; then
    ok "secret_check 还原（observed，含 0x539=1337，${DOK#1|}）"
  else
    bad "decompile 结果不符（${DOK#0|}）"
  fi
else
  bad "decompile 失败（见 $WORKDIR/decomp.err）"; tail -5 "$WORKDIR/decomp.err"
fi

# ---- 5. analyze（剥离符号）-------------------------------------------------
echo "== 5. analyze demo_stripped（无符号）=="
if "${REA[@]}" analyze "$EX_DIR/demo_stripped" --provider ghidra --format json \
     --snapshot "$WORKDIR/stripped.snap" >"$WORKDIR/stripped.json" 2>"$WORKDIR/stripped.err"; then
  SC="$(python3 -c "import json;print(json.load(open('$WORKDIR/stripped.json'))['normalized_result']['procedure_count'])")"
  if [ "${SC:-0}" -ge 3 ]; then
    ok "无符号二进制仍可导入分析（procedures=$SC）"
  else
    bad "stripped 函数数异常（procedures=$SC）"
  fi
else
  bad "stripped analyze 失败（见 $WORKDIR/stripped.err）"; tail -5 "$WORKDIR/stripped.err"
fi

# ---- 汇总 -------------------------------------------------------------------
echo ""
echo "================================================"
echo " 结果：$PASS 通过 / $FAIL 失败"
echo "================================================"
if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi

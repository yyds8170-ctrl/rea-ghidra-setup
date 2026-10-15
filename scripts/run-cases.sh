#!/usr/bin/env bash
# =============================================================================
# run-cases.sh —— 端到端逆向案例库自动断言
#
# 做什么：
#   1) cd examples/cases && make  —— 编译 5 个案例的「带符号版」与「strip 版」
#   2) 对每个二进制跑 scripts/ghidra-export.sh --kind all，得到 JSON
#   3) 用内嵌 python3 读取 JSON，逐项断言【字符串 / 函数名 / 调用边 / 反编译常量】
#   4) 打印 [PASS]/[FAIL] 中文结果与汇总（X 通过 / Y 失败），任一失败退出非 0
#
# 设计原则：
#   - 幂等：每次清空 build/ghidra-out 重新导出。
#   - bash 3.2 兼容（macOS 自带 bash）：变量一律用 ${var}，不用关联数组。
#   - 环境覆盖：GHIDRA_INSTALL_DIR / JAVA_HOME / TOOLS_DIR 透传给 ghidra-export.sh。
#
# 用法：
#   bash scripts/run-cases.sh           # 全量跑
#   bash scripts/run-cases.sh --help
#   GHIDRA_INSTALL_DIR=... JAVA_HOME=... bash scripts/run-cases.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CASES_DIR="${REPO_ROOT}/examples/cases"
BUILD_DIR="${CASES_DIR}/build"
EXPORT_SH="${REPO_ROOT}/scripts/ghidra-export.sh"
OUT_ROOT="${BUILD_DIR}/ghidra-out"

# 案例清单（与 Makefile 目标名一致）
CASES="01-crackme-password 02-license-key 03-tiered-pricing 04-switch-dispatch 05-export-flow"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

# ---- 前置检查 ----
command -v make >/dev/null 2>&1 || { echo "[FATAL] 缺少 make" >&2; exit 2; }
command -v gcc >/dev/null 2>&1 || command -v cc >/dev/null 2>&1 || { echo "[FATAL] 缺少 gcc/cc" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "[FATAL] 缺少 python3" >&2; exit 2; }
[ -x "${EXPORT_SH}" ] || { echo "[FATAL] 缺少导出脚本 ${EXPORT_SH}" >&2; exit 2; }

echo "==> [1/3] 编译全部案例（输出到 ${BUILD_DIR}）"
make -C "${CASES_DIR}" clean >/dev/null
make -C "${CASES_DIR}" all

echo "==> [2/3] 准备导出目录（幂等清空 ${OUT_ROOT}）"
rm -rf "${OUT_ROOT}"
mkdir -p "${OUT_ROOT}"

# 累计失败计数（通过 env 传给 python；bash 侧只看退出码）
FAIL_TOTAL=0

# run_one <case> <binary-stem> <mode: symbols|stripped>
# 对单个二进制导出并用 python 断言。失败时退出码非 0。
run_one() {
  local case="$1"
  local stem="$2"          # 例如 01-crackme-password 或 01-crackme-password-stripped
  local mode="$3"          # symbols | stripped
  local bin="${BUILD_DIR}/${stem}"
  local out="${OUT_ROOT}/${stem}"

  echo "----------------------------------------------------------------"
  echo ">> 导出 ${stem}  [${mode}]"
  mkdir -p "${out}"
  if ! bash "${EXPORT_SH}" "${bin}" --out "${out}" --kind all >"${out}/export.log" 2>&1; then
    echo "[FAIL] ${stem}: ghidra-export 失败，日志尾部：" >&2
    tail -20 "${out}/export.log" >&2 || true
    return 1
  fi

  CASE_NAME="${case}" MODE="${mode}" OUT_DIR="${out}" python3 - <<'PY'
import json, os, re, sys

case = os.environ["CASE_NAME"]
mode = os.environ["MODE"]
d = os.environ["OUT_DIR"]

def load(n):
    p = os.path.join(d, n + ".json")
    if not os.path.exists(p):
        print(f"[FAIL] {case}/{mode}: 缺少产物 {n}.json")
        sys.exit(1)
    with open(p, encoding="utf-8") as f:
        return json.load(f)

funcs   = load("functions")
strings = load("strings")
symbols = load("symbols")
calls   = load("calls")
decomp  = load("decompiled")   # dict: name -> c text

func_names = set(f.get("name", "") for f in funcs)
str_values  = "\n".join(s.get("value", "") for s in strings)
callees    = set(c.get("callee", "") for c in calls)
callers    = set(c.get("caller", "") for c in calls)
sym_names  = set(s.get("name", "") for s in symbols)
all_decomp  = "\n".join(decomp.values())
low_decomp  = all_decomp.lower()

# 跨平台归一化：Mach-O（macOS）给 C 符号加前导下划线（_printf），ELF 不加。
# 去掉命名空间限定（末段）与前导下划线后比较；供“识别某导入函数”类断言使用。
def norm(n):
    n = n.split("::")[-1]
    return n[1:] if n.startswith("_") and len(n) > 1 else n
extern_names = set(norm(n) for n in sym_names) | set(norm(n) for n in callees)

results = []  # (ok, message)
def check(ok, msg):
    results.append((bool(ok), msg))

def has_substr(text, needle):
    return needle in text

# 在反编译文本里同时接受 十六进制 token 或 十进制 token（Ghidra 二者都可能出现）
def has_const(hextok, dectok):
    if hextok.lower() in low_decomp:
        return True
    # 十进制按“独立数字 token”匹配，避免误命中 0x1b7 内部
    return re.search(r"(?<![0-9a-fA-Fx])" + re.escape(dectok) + r"\b", all_decomp) is not None

# 带符号版才检查内部函数名；strip 后内部函数名变成 FUN_xxx，不检查
def need_func(name):
    if mode == "stripped":
        return  # strip 版跳过内部函数名断言
    check(name in func_names, f"函数表含 {name}")

# ---------------- 各案例断言 ----------------
if case == "01-crackme-password":
    check(has_substr(str_values, "S3cr3t-2026"), "字符串表含硬编码口令 S3cr3t-2026")
    check(has_substr(str_values, "ACCESS GRANTED"), "字符串表含 ACCESS GRANTED")
    need_func("check_password")
    check("strcmp" in callees, "调用边出现 strcmp")

elif case == "02-license-key":
    check(has_const("0x5a", "90"),  "反编译含异或常量 0x5a(90)")
    check(has_const("0x1b7", "439"), "反编译含魔数 0x1b7(439)")
    check(has_substr(str_values, "LICENSE OK"), "字符串表含 LICENSE OK")
    need_func("verify_key")

elif case == "03-tiered-pricing":
    # 真实反编译：qty>=100 -> "qty < 100"；满减 +50 -> "+ 0x32"。
    # qty>=10 被规整为 "9 < qty"，故不搜字面 10，改搜可见的高阈值与满减常量。
    check(has_const("0x32", "50"), "反编译含满减常量 0x32(50)")
    check(re.search(r"(?<![0-9])100\b", all_decomp) is not None, "反编译含高数量阈值 100(0x64)")
    need_func("compute_price")

elif case == "04-switch-dispatch":
    for s in ("login-menu", "buy-menu", "about-menu", "exit-menu"):
        check(has_substr(str_values, s), f"字符串表含 {s}")
    if mode == "stripped":
        # strip 后 do_* 内部函数名丢失，只断言字符串仍在
        pass
    else:
        check("do_login" in callees, "调用边出现 do_login")
        check("do_buy" in callees,   "调用边出现 do_buy")
        check("do_exit" in callees,  "调用边出现 do_exit")
        need_func("dispatch")

elif case == "05-export-flow":
    check(len(funcs) >= 1,    f"functions 非空（{len(funcs)}）")
    check(len(strings) >= 1,  f"strings 非空（{len(strings)}）")
    check(len(calls) >= 1,    f"calls 非空（{len(calls)}）")
    check(len(symbols) >= 1,  f"symbols 非空（{len(symbols)}）")
    for lib in ("printf", "strlen", "strcmp"):
        # 跨平台：ELF 为 printf；Mach-O 为 _printf（归一化后比较）。
        check(lib in extern_names, f"识别 libc 导入 {lib}（符号/调用，跨平台）")

else:
    print(f"[FAIL] 未知案例 {case}")
    sys.exit(1)

bad = 0
for ok, msg in results:
    tag = "PASS" if ok else "FAIL"
    if not ok:
        bad += 1
    print(f"  [{tag}] {case}/{mode}: {msg}")

if bad:
    print(f"[FAIL] {case}/{mode} 共 {bad} 项失败")
    sys.exit(1)
print(f"[PASS] {case}/{mode} 全部 {len(results)} 项断言通过")
PY
}

echo "==> [3/3] 逐二进制导出并断言"
for c in ${CASES}; do
  # 带符号版
  if ! run_one "${c}" "${c}" "symbols"; then
    FAIL_TOTAL=$((FAIL_TOTAL + 1))
  fi
  # strip 版
  if ! run_one "${c}" "${c}-stripped" "stripped"; then
    FAIL_TOTAL=$((FAIL_TOTAL + 1))
  fi
done

echo "=================================================================="
if [ "${FAIL_TOTAL}" -ne 0 ]; then
  echo "汇总：有 ${FAIL_TOTAL} 个二进制断言失败（详见上方 [FAIL]）"
  exit 1
fi
echo "汇总：全部 10 个二进制（5 案例 × 带符号/strip）断言通过"
exit 0

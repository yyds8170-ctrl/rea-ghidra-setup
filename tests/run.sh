#!/usr/bin/env bash
# =============================================================================
# tests/run.sh — 统一测试入口（离线、确定性、零外部框架依赖）
#
# 运行：
#   1) tests/test_*.sh            纯 bash 单元测试（harness.sh 计数）
#   2) python3 -m unittest        tests/python/ 下 stdlib unittest 套件
#   3) shellcheck（若本机装有）   对本仓库新增 bash 脚本做零告警静态门
#
# 输出：逐条 PASS/FAIL + 汇总 pass/total；任一失败则整体退出 1。
# 不联网、不依赖 Ghidra/Node/JDK 二进制。长日志落到 tests/run.sh 外的 LOGDIR。
#
# 环境变量：
#   TESTS_LOG_DIR   日志目录（默认在 worktree 外，避免误提交）
#   TESTS_NO_SHELLCHECK=1  跳过 shellcheck 门
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

LOGDIR="${TESTS_LOG_DIR:-/home/user/.doubao/agent_mode/workspace/.sessions/38447183969018626/agents/o_0003MEsFsKb/scratch/testssc-logs}"
mkdir -p "$LOGDIR"

TOTAL_PASS=0
TOTAL_FAIL=0

bump() { # bump <pass> <fail>
  TOTAL_PASS=$((TOTAL_PASS + $1))
  TOTAL_FAIL=$((TOTAL_FAIL + $2))
}

echo "================================================================"
echo " rea-ghidra-setup 测试套件（离线）"
echo " 日志目录: $LOGDIR"
echo "================================================================"

# ---- 1) bash 测试 -----------------------------------------------------------
echo
echo "## Bash 单元测试"
for t in "$HERE"/test_*.sh; do
  [ -e "$t" ] || continue
  name="$(basename "$t")"
  echo
  echo ">>> $name"
  out="$(bash "$t" 2>&1)" || true
  printf '%s\n' "$out" | tee "$LOGDIR/$name.log"
  p=$(printf '%s\n' "$out" | grep -c '^PASS ' || true)
  f=$(printf '%s\n' "$out" | grep -c '^FAIL ' || true)
  bump "${p:-0}" "${f:-0}"
done

# ---- 2) python unittest -----------------------------------------------------
echo
echo "## Python unittest（stdlib）"
pylog="$LOGDIR/python-unittest.log"
pyout="$(python3 -m unittest discover -s "$HERE/python" -p 'test_*.py' -v 2>&1)"
pyrc=$?
printf '%s\n' "$pyout" | tee "$pylog"
# -v 每行以 " ... ok" 结尾为通过；"FAIL:" / "ERROR:" 为失败
pp=$(printf '%s\n' "$pyout" | grep -cE '\.\.\. (ok|skipped|expected-fail)' || true)
pf=$(printf '%s\n' "$pyout" | grep -cE '^(FAIL|ERROR):' || true)
# unittest 自身非 0 退出（如 import 错误）也计为失败，即使上面没匹配到失败行
if [ "$pyrc" -ne 0 ] && [ "${pf:-0}" -eq 0 ]; then
  pf=1
fi
bump "${pp:-0}" "${pf:-0}"

# ---- 3) shellcheck 静态门（可选）--------------------------------------------
if [ "${TESTS_NO_SHELLCHECK:-0}" = "1" ]; then
  echo
  echo "## shellcheck：已跳过（TESTS_NO_SHELLCHECK=1）"
elif ! command -v shellcheck >/dev/null 2>&1; then
  echo
  echo "## shellcheck：本机未安装，跳过静态门"
else
  echo
  echo "## shellcheck（$(shellcheck --version | awk '/^version:/{print $2}')）"
  sc_targets=(
    "$HERE"/harness.sh
    "$HERE"/run.sh
    "$HERE"/test_*.sh
    "$REPO_ROOT/scripts/gen-sbom.sh"
    "$REPO_ROOT/scripts/verify-integrity.sh"
  )
  # SC1091=“未跟随 source 文件”：被 source 的 lib/* 是他人所有、不在本次 lint 范围；
  # 这里动态路径在运行时确定，显式排除该 info，其余规则零容忍。
  if shellcheck -s bash --exclude=SC1091 "${sc_targets[@]}" >"$LOGDIR/shellcheck.log" 2>&1; then
    echo "PASS shellcheck 零告警"
    bump 1 0
  else
    echo "FAIL shellcheck 有告警（见 $LOGDIR/shellcheck.log）"
    cat "$LOGDIR/shellcheck.log" >&2
    bump 0 1
  fi
fi

# ---- 汇总 -------------------------------------------------------------------
echo
echo "================================================================"
TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
echo " 汇总：PASS ${TOTAL_PASS} / ${TOTAL}"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo " 结果：全部通过"
  exit 0
else
  echo " 结果：${TOTAL_FAIL} 项失败"
  exit 1
fi

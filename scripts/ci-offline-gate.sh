#!/usr/bin/env bash
# =============================================================================
# scripts/ci-offline-gate.sh — 一条命令跑全部离线质量门（供 CI 调用）
#
# 依次执行，任一失败立即非 0 退出并打印总结：
#   1) tests/run.sh            单元/集成 + python unittest + shellcheck 门
#   2) verify-integrity.sh     离线工件哈希核对（仅当 OFFLINE_DIR 存在；否则跳过）
#   3) gen-sbom 可复现性        同一份输入两次生成 SBOM，字节级 diff 必须为空
#
# 不联网、不依赖 Ghidra/Node/JDK 二进制运行。
# 环境：
#   OFFLINE_DIR    离线包目录（含 SHA256SUMS.txt）；未设则第 2 步跳过
#   TESTS_LOG_DIR  透传给 tests/run.sh 的日志目录
# =============================================================================
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILURES=()
step() { printf '\n==============================================================\n 步骤：%s\n==============================================================\n' "$*"; }

step "1/3 tests/run.sh（单测 + unittest + shellcheck）"
if bash "$REPO_ROOT/tests/run.sh"; then
  echo "PASS step1"
else
  FAILURES+=("tests/run.sh")
fi

step "2/3 verify-integrity.sh（离线工件哈希核对）"
if [ -n "${OFFLINE_DIR:-}" ] && [ -d "$OFFLINE_DIR" ]; then
  if OFFLINE_DIR="$OFFLINE_DIR" bash "$REPO_ROOT/scripts/verify-integrity.sh"; then
    echo "PASS step2"
  else
    FAILURES+=("verify-integrity.sh")
  fi
else
  echo "SKIP step2：OFFLINE_DIR 未设置或目录不存在（${OFFLINE_DIR}）"
fi

step "3/3 gen-sbom.sh 可复现性（两次生成字节级 diff）"
TMP_A="$(mktemp)"; TMP_B="$(mktemp)"
trap 'rm -f "$TMP_A" "$TMP_B"' EXIT
if OFFLINE_DIR="${OFFLINE_DIR:-$REPO_ROOT/offline}" bash "$REPO_ROOT/scripts/gen-sbom.sh" "$TMP_A" >/dev/null \
   && OFFLINE_DIR="${OFFLINE_DIR:-$REPO_ROOT/offline}" bash "$REPO_ROOT/scripts/gen-sbom.sh" "$TMP_B" >/dev/null \
   && cmp -s "$TMP_A" "$TMP_B"; then
  echo "PASS step3（SBOM 两次生成字节级一致）"
else
  FAILURES+=("gen-sbom 可复现性")
fi

printf '\n==============================================================\n 总结\n==============================================================\n'
if [ "${#FAILURES[@]}" -eq 0 ]; then
  echo "全部离线质量门通过。"
  exit 0
else
  echo "失败步骤："
  f=0
  while [ "$f" -lt "${#FAILURES[@]}" ]; do
    echo "  - ${FAILURES[$f]}"
    f=$((f + 1))
  done
  exit 1
fi

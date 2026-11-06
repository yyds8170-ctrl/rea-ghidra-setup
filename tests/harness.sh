#!/usr/bin/env bash
# =============================================================================
# tests/harness.sh — 零依赖 bash 测试小框架（不依赖 bats，bash 3.2+ 兼容）
#
# 被每个 tests/test_*.sh source。约定：
#   T_PASS / T_FAIL 计数；每条断言打印一行
#     PASS <用例名>   到 stdout
#     FAIL <用例名>   到 stdout，并把差异打到 stderr
#   脚本末尾调用 tests_done 退出（有失败则非 0）。
# run.sh 靠 grep '^PASS '/'^FAIL ' 汇总。
# =============================================================================

T_PASS=0
T_FAIL=0

# assert_eq <期望> <实际> <用例名>
assert_eq() {
  if [ "$1" = "$2" ]; then
    printf 'PASS %s\n' "$3"
    T_PASS=$((T_PASS + 1))
  else
    printf 'FAIL %s\n' "$3"
    T_FAIL=$((T_FAIL + 1))
    printf '      expected: [%s]\n' "$1" >&2
    printf '      actual  :   [%s]\n' "$2" >&2
  fi
}

# assert_rc <期望退出码> <实际退出码> <用例名>
assert_rc() {
  if [ "$1" -eq "$2" ]; then
    printf 'PASS %s\n' "$3"
    T_PASS=$((T_PASS + 1))
  else
    printf 'FAIL %s\n' "$3"
    T_FAIL=$((T_FAIL + 1))
    printf '      expected rc: %s\n' "$1" >&2
    printf '      actual rc:   %s\n' "$2" >&2
  fi
}

# assert_contains <子串> <被检字符串> <用例名>
assert_contains() {
  case "$2" in
    *"$1"*)
      printf 'PASS %s\n' "$3"
      T_PASS=$((T_PASS + 1))
      ;;
    *)
      printf 'FAIL %s\n' "$3"
      T_FAIL=$((T_FAIL + 1))
      printf '      substring not found: [%s]\n' "$1" >&2
      printf '      in: [%s]\n' "$2" >&2
      ;;
  esac
}

# assert_empty <被检字符串> <用例名>
assert_empty() {
  if [ -z "$1" ]; then
    printf 'PASS %s\n' "$2"
    T_PASS=$((T_PASS + 1))
  else
    printf 'FAIL %s\n' "$2"
    T_FAIL=$((T_FAIL + 1))
    printf '      expected empty, got: [%s]\n' "$1" >&2
  fi
}

# tests_done — 打印汇总行并以正确退出码结束本测试脚本
tests_done() {
  printf 'SUITE-RESULT pass=%d fail=%d\n' "$T_PASS" "$T_FAIL"
  [ "$T_FAIL" -eq 0 ]
}

#!/usr/bin/env bash
# =============================================================================
# tests/test_exitcodes.sh — lib/exitcodes.sh 单元测试
#
# 覆盖：RC_* 常量取值、fatal <rc> 以正确退出码退出、非 TTY 时输出机器可读
# JSON envelope（name/code/message/tool）、die() 等价 fatal 1。
# 不联网、不碰 Ghidra。stderr 被命令替换捕获 => 恒为非 TTY => JSON 必现。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"
# shellcheck source=../lib/exitcodes.sh
. "$REPO_ROOT/lib/exitcodes.sh"

# 1) 常量
assert_rc 0  "$RC_OK"     "RC_OK=0"
assert_rc 2  "$RC_USAGE"  "RC_USAGE=2"
assert_rc 10 "$RC_DEPENDENCY" "RC_DEPENDENCY=10"
assert_rc 11 "$RC_CHECKSUM"  "RC_CHECKSUM=11"
assert_rc 12 "$RC_UPSTREAM"  "RC_UPSTREAM=12"
assert_rc 13 "$RC_DISK"       "RC_DISK=13"
assert_rc 14 "$RC_BUSY"      "RC_BUSY=14"

# 2) fatal 以指定码退出（子 shell 捕获）
rc=0; (fatal "$RC_USAGE" "boom usage") >/dev/null 2>&1 || rc=$?
assert_rc 2 "$rc" "fatal RC_USAGE -> exit 2"

rc=0; (fatal "$RC_CHECKSUM" "boom csum") >/dev/null 2>&1 || rc=$?
assert_rc 11 "$rc" "fatal RC_CHECKSUM -> exit 11"

rc=0; (fatal 99 "unclassified") >/dev/null 2>&1 || rc=$?
assert_rc 99 "$rc" "fatal unknown code passthrough"

# 3) 非 TTY stderr 上的 JSON envelope：含 code/name/message
out="$(fatal "$RC_BUSY" "two installs" 2>&1 >/dev/null || true)"
assert_contains '"code": 14' "$out" "envelope carries code 14"
assert_contains '"name": "RC_BUSY"' "$out" "envelope carries name RC_BUSY"
assert_contains '"message": "two installs"' "$out" "envelope carries message"

# 4) JSON 必须是合法 JSON（jq 可用则校验）
if command -v jq >/dev/null 2>&1; then
  json_line="$(printf '%s\n' "$out" | grep '^{' | head -n1)"
  echo "$json_line" | jq -e '.error.code == 14 and .error.name == "RC_BUSY"' >/dev/null 2>&1 \
    && ok_jq=1 || ok_jq=0
  assert_rc 1 "$ok_jq" "envelope JSON 可被 jq 解析且字段正确"
fi

# 5) die() 兼容接口 = fatal 1
rc=0; (die "legacy error") >/dev/null 2>&1 || rc=$?
assert_rc 1 "$rc" "die() exits 1"

tests_done

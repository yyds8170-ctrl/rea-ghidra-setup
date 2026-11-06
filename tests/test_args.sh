#!/usr/bin/env bash
# =============================================================================
# tests/test_args.sh — lib/args.sh 命令行解析单元测试
#
# 覆盖：默认值、各开关、带值参数、镜像模式白名单、未知参数/缺值 -> RC_USAGE(2)。
# 每个用例在独立子 shell 里重新 source，避免全局互相污染。不联网。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"

# 在子 shell 里解析 "$@"：
#   成功 -> stdout 打印 key=value|...，退出 0；
#   fatal 路径 -> fatal 直接 exit 子 shell（=RC_USAGE=2），用法/JSON 打到 stderr。
# 调用方用 out="$(run_parse ... 2>&1)"; rc=$? 同时拿到两者。
run_parse() {
  (
    # shellcheck source=../lib/exitcodes.sh
    . "$REPO_ROOT/lib/exitcodes.sh"
    # shellcheck source=../lib/args.sh
    . "$REPO_ROOT/lib/args.sh"
    # 被 lib/args.sh 的 install_usage 在 fatal 时引用，export 使其可见
    export INSTALLER_NAME="install.sh"
    parse_install_args "$@"
    printf 'ARG_HELP=%s|ARG_DRY_RUN=%s|ARG_YES=%s|TOOLS_DIR=%s|SKIP_NODE=%s|SKIP_NATIVE=%s|REA_MIRROR=%s|PROV=%s|OFF=%s|GV=%s|NV=%s|RV=%s' \
      "$ARG_HELP" "$ARG_DRY_RUN" "$ARG_YES" "$TOOLS_DIR" "$SKIP_NODE" "$SKIP_NATIVE" \
      "${REA_MIRROR:-}" "$REA_ANALYSIS_PROVIDER" "${OFFLINE_DIR:-}" \
      "${GHIDRA_VERSION:-}" "${REA_NODE_VERSION:-}" "${REA_VERSION:-}"
  )
}

out="$(run_parse)"
assert_contains 'ARG_HELP=0'   "$out" "无参默认 ARG_HELP=0"
assert_contains 'ARG_DRY_RUN=0' "$out" "无参默认 ARG_DRY_RUN=0"
assert_contains 'TOOLS_DIR='   "$out"  "无参默认 TOOLS_DIR 有值"

out="$(run_parse --help)"
assert_contains 'ARG_HELP=1' "$out" "--help 置位 ARG_HELP"

out="$(run_parse --dry-run)"
assert_contains 'ARG_DRY_RUN=1' "$out" "--dry-run 置位"

out="$(run_parse -y)"
assert_contains 'ARG_YES=1' "$out" "-y 置位 ARG_YES"
out="$(run_parse --yes)"
assert_contains 'ARG_YES=1' "$out" "--yes 置位 ARG_YES"
out="$(run_parse --non-interactive)"
assert_contains 'ARG_YES=1' "$out" "--non-interactive 置位 ARG_YES"

out="$(run_parse --prefix /opt/rea)"
assert_contains 'TOOLS_DIR=/opt/rea' "$out" "--prefix 设定 TOOLS_DIR"
out="$(run_parse --tools-dir /x/y)"
assert_contains 'TOOLS_DIR=/x/y' "$out" "--tools-dir 同义"

out="$(run_parse --mirror cn)"
assert_contains 'REA_MIRROR=cn' "$out" "--mirror cn 接受"
out="$(run_parse --mirror global)"
assert_contains 'REA_MIRROR=global' "$out" "--mirror global 接受"

out="$(run_parse --skip-node --no-native)"
assert_contains 'SKIP_NODE=1' "$out" "--skip-node 置位"
assert_contains 'SKIP_NATIVE=1' "$out" "--no-native 置位"

out="$(run_parse --provider ghidra)"
assert_contains 'PROV=ghidra' "$out" "--provider 透传 REA_ANALYSIS_PROVIDER"

out="$(run_parse --offline-dir /srv/offline)"
assert_contains 'OFF=/srv/offline' "$out" "--offline-dir 透传"

out="$(run_parse --ghidra-version 9.9.9)"
assert_contains 'GV=9.9.9' "$out" "--ghidra-version 覆盖"
out="$(run_parse --node-version 9.9.9)"
assert_contains 'NV=9.9.9' "$out" "--node-version 覆盖"
out="$(run_parse --rea-version 9.9.9)"
assert_contains 'RV=9.9.9' "$out" "--rea-version 覆盖"

# 错误路径：未知参数 / 非法镜像 / 缺值 -> fatal 退出 2（用法/JSON 已并入 out，仅用于静默）
out="$(run_parse --bogus-flag 2>&1)"; rc=$?
assert_rc 2 "$rc" "未知参数退出 2"
out="$(run_parse --mirror mars 2>&1)"; rc=$?
assert_rc 2 "$rc" "非法 --mirror 退出 2"
out="$(run_parse --prefix 2>&1)"; rc=$?
assert_rc 2 "$rc" "--prefix 缺值退出 2"
out="$(run_parse --ghidra-version 2>&1)"; rc=$?
assert_rc 2 "$rc" "--ghidra-version 缺值退出 2"

tests_done

#!/usr/bin/env bash
# =============================================================================
# tests/test_checksums.sh — lib/checksums.sh 纯函数单元测试（不联网，不改原文件）
#
# 覆盖：cs_sha256 计算、cs_manifest_sha 解析离线清单/未命中、cs_verify 三种返回
# （0 匹配 / 1 不匹配或文件缺失）。离线清单格式与 prepare-offline.sh 产出一致。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"
# shellcheck source=../lib/checksums.sh
. "$REPO_ROOT/lib/checksums.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 造两个夹具文件
printf 'hello-rea-ghidra\n' > "$WORK/a.tar.gz"
printf 'tampered\n'         > "$WORK/b.zip"
HASH_A="$(sha256sum "$WORK/a.tar.gz" | awk '{print $1}')"
HASH_B="$(sha256sum "$WORK/b.zip" | awk '{print $1}')"

# 离线清单：hash 两空格 basename（与 scripts/prepare-offline.sh 产出一致）
MAN="$WORK/SHA256SUMS.txt"
{
  printf '%s  a.tar.gz\n' "$HASH_A"
  printf '%s  b.zip\n'    "$HASH_B"
} > "$MAN"

# 1) cs_sha256
got="$(cs_sha256 "$WORK/a.tar.gz")"
assert_eq "$HASH_A" "$got" "cs_sha256 计算与 sha256sum 一致"

# 2) cs_manifest_sha：命中 / 未命中 / 清单不存在
got="$(cs_manifest_sha "$MAN" a.tar.gz)"; rc=$?
assert_eq "$HASH_A" "$got" "cs_manifest_sha 命中 a.tar.gz"
assert_rc 0 "$rc" "cs_manifest_sha 命中退出 0"
got="$(cs_manifest_sha "$MAN" nope.tgz 2>/dev/null)"; rc=$?
assert_empty "$got" "cs_manifest_sha 未命中输出为空"
assert_rc 1 "$rc" "cs_manifest_sha 未命中退出 1"
got="$(cs_manifest_sha "$WORK/nosuch" a.tar.gz 2>/dev/null)"; rc=$?
assert_rc 1 "$rc" "cs_manifest_sha 清单不存在退出 1"

# 3) cs_verify：匹配 / 不匹配 / 文件缺失
cs_verify "$WORK/a.tar.gz" "$HASH_A"; rc=$?
assert_rc 0 "$rc" "cs_verify 匹配返回 0"
cs_verify "$WORK/a.tar.gz" "$HASH_B"; rc=$?
assert_rc 1 "$rc" "cs_verify 哈希不符返回 1"
cs_verify "$WORK/missing.tar" "$HASH_A" 2>/dev/null; rc=$?
assert_rc 1 "$rc" "cs_verify 文件缺失返回 1"

# 4) 清单里的 b.zip 哈希与实际文件一致（跨函数闭环）
got="$(cs_manifest_sha "$MAN" b.zip)"
cs_verify "$WORK/b.zip" "$got"; rc=$?
assert_rc 0 "$rc" "清单条目可校验真实文件（manifest->verify 闭环）"

tests_done

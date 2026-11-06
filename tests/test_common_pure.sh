#!/usr/bin/env bash
# =============================================================================
# tests/test_common_pure.sh — lib/common.sh 中与 IO/网络无关的纯函数
#
# 覆盖：normalize_arch、ghidra_*_name/url、adoptium_jdk_url、node_tarball_url/dir、
# load_versions 从 config/versions.env 读默认值。不联网。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"
# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"

# 固定一组输入，断言 URL/命名派生（版本来自 versions.env）
GHIDRA_VERSION=12.1.4
GHIDRA_BUILD=Ghidra_12.1.4_build
GHIDRA_DATE=20260921
JDK_FEATURE=21
REA_NODE_VERSION=24.22.2

assert_eq "ghidra_12.1.4_PUBLIC_20260921.zip" "$(ghidra_zip_name)" "ghidra_zip_name 派生正确"
assert_eq "ghidra_12.1.4_PUBLIC" "$(ghidra_dir_name)" "ghidra_dir_name 派生正确"
assert_eq \
  "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip" \
  "$(ghidra_release_url)" "ghidra_release_url 组装正确"
assert_eq \
  "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse" \
  "$(adoptium_jdk_url linux x64)" "adoptium_jdk_url 组装正确"
assert_eq \
  "https://nodejs.org/dist/v24.22.2/node-v24.22.2-linux-x64.tar.gz" \
  "$(node_tarball_url linux x64)" "node_tarball_url linux-x64 正确"
assert_eq \
  "https://nodejs.org/dist/v24.22.2/node-v24.22.2-linux-arm64.tar.gz" \
  "$(node_tarball_url linux aarch64)" "node_tarball_url aarch64→arm64 重命名正确"
assert_eq "node-v24.22.2-linux-arm64" "$(node_tarball_dir linux aarch64)" "node_tarball_dir aarch64→arm64"

# normalize_arch：本机是 x86_64 -> x64
case "$(uname -m)" in
  x86_64|amd64) expect_arch=x64 ;;
  arm64|aarch64) expect_arch=aarch64 ;;
  *) expect_arch="$(uname -m)" ;;
esac
assert_eq "$expect_arch" "$(normalize_arch)" "normalize_arch 归一化本机架构"

# load_versions：全新环境里从 config/versions.env 装载
out="$(
  unset GHIDRA_VERSION GHIDRA_BUILD GHIDRA_DATE JDK_FEATURE REA_NODE_VERSION REA_VERSION
  load_versions
  printf '%s|%s|%s|%s|%s|%s' \
    "$GHIDRA_VERSION" "$GHIDRA_BUILD" "$GHIDRA_DATE" "$JDK_FEATURE" "$REA_NODE_VERSION" "$REA_VERSION"
)"
assert_eq "12.1.4|Ghidra_12.1.4_build|20260921|21|24.22.2|6.8.0" "$out" \
  "load_versions 装载 config/versions.env 全部锁定版本"

tests_done

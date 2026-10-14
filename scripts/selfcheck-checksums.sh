#!/usr/bin/env bash
# =============================================================================
# scripts/selfcheck-checksums.sh — 校验和链路自检（CI / 本地，联网）
#
# 验证：
#   1) Node SHASUMS256、Adoptium JDK、GitHub release(Ghidra) 三个上游校验和源均可取到；
#   2) 真实下载 Node（最小，约 52MB）并通过 fetch_artifact 强校验一致。
# 任一失败退出非零。CI 会注入 GITHUB_TOKEN 以避免 GitHub API 限流。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=lib/checksums.sh
source "$SCRIPT_DIR/../lib/checksums.sh"
load_versions

is_hex64() { [[ "$1" =~ ^[0-9a-f]{64}$ ]]; }
fail=0
check_src() {
  local name="$1" val="$2"
  if is_hex64 "$val"; then echo "[PASS] $name 校验和可获取：${val:0:16}…"; else echo "[FAIL] $name 校验和为空或非法（限流/离线？）"; fail=1; fi
}

NODE_PKG="$(node_tarball_dir linux x64).tar.gz"
check_src "Node(SHASUMS256)" "$(cs_expected_node "$REA_NODE_VERSION" "$NODE_PKG" 2>/dev/null || true)"
check_src "JDK(Adoptium)"    "$(cs_expected_jdk "$JDK_FEATURE" linux x64 2>/dev/null || true)"
check_src "Ghidra(GitHub)"   "$(cs_expected_ghidra "$GHIDRA_BUILD" "$(ghidra_zip_name)" 2>/dev/null || true)"

# 真实下载 Node 并校验
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if fetch_artifact node "$NODE_PKG" "$(node_tarball_url linux x64)" "$TMP/node.tar.gz"; then
  if is_hex64 "$(cs_sha256 "$TMP/node.tar.gz")" && tar -tzf "$TMP/node.tar.gz" >/dev/null; then
    echo "[PASS] Node 下载并校验一致，tarball 可解包"
  else
    echo "[FAIL] Node 文件校验/解包异常"; fail=1
  fi
else
  echo "[FAIL] fetch_artifact Node 失败"; fail=1
fi

[ "$fail" -eq 0 ] || { echo "校验和链路自检失败"; exit 1; }
echo "校验和链路自检通过"

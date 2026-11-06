#!/usr/bin/env bash
# =============================================================================
# tests/test_mirrors.sh — lib/mirrors.sh 镜像策略单元测试（离线确定性）
#
# auto 探测本会联网；这里用 PATH 上前置一个“必定失败的假 curl”模拟官方不可达，
# 使 auto 确定性落到 cn。cn/global 走 REA_MIRROR 短路，本就不联网。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"
# shellcheck source=../lib/mirrors.sh
. "$REPO_ROOT/lib/mirrors.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 假 curl：任何调用都失败（模拟 nodejs.org 不可达）
FAKEBIN="$WORK/fakebin"; mkdir -p "$FAKEBIN"
printf '#!/bin/sh\nexit 7\n' > "$FAKEBIN/curl"
chmod +x "$FAKEBIN/curl"

export REA_NODE_VERSION=24.22.2
export JDK_FEATURE=21

# 1) global/cn 短路
out="$(REA_MIRROR=global REA_MIRROR_MODE='' rea_mode)"
assert_eq "global" "$out" "REA_MIRROR=global → global"
out="$(REA_MIRROR=cn REA_MIRROR_MODE='' rea_mode)"
assert_eq "cn" "$out" "REA_MIRROR=cn → cn"

# 2) auto：假 curl 失败 → cn（不触网，最多跑一次假 curl）
out="$(PATH="$FAKEBIN:$PATH" REA_MIRROR=auto REA_MIRROR_MODE='' rea_mode)"
assert_eq "cn" "$out" "auto 官方不可达时确定性降级 cn"

# 3) node 候选 URL 顺序：cn 镜像在前官方兜底；global 官方在前
out="$(REA_MIRROR=cn REA_MIRROR_MODE=cn node_candidate_urls node-v24.22.2-linux-x64.tar.gz)"
case "$out" in
  "https://registry.npmmirror.com/-/binary/node/v24.22.2/node-v24.22.2-linux-x64.tar.gz"*)
    printf 'PASS %s\n' "cn 模式 npmmirror 排在首位"; T_PASS=$((T_PASS+1)) ;;
  *) printf 'FAIL %s\n' "cn 模式 npmmirror 应排首位"; T_FAIL=$((T_FAIL+1)); printf '     got: %s\n' "$out" >&2 ;;
esac
case "$out" in
  *" https://nodejs.org/dist/v24.22.2/node-v24.22.2-linux-x64.tar.gz")
    printf 'PASS %s\n' "cn 模式官方源兜底在末位"; T_PASS=$((T_PASS+1)) ;;
  *) printf 'FAIL %s\n' "cn 模式官方源应在末位"; T_FAIL=$((T_FAIL+1)); printf '     got: %s\n' "$out" >&2 ;;
esac

out="$(REA_MIRROR=global REA_MIRROR_MODE=global node_candidate_urls node-v24.22.2-linux-x64.tar.gz)"
case "$out" in
  "https://nodejs.org/dist/v24.22.2/node-v24.22.2-linux-x64.tar.gz"*)
    printf 'PASS %s\n' "global 模式官方排首位"; T_PASS=$((T_PASS+1)) ;;
  *) printf 'FAIL %s\n' "global 模式官方应排首位"; T_FAIL=$((T_FAIL+1)); printf '     got: %s\n' "$out" >&2 ;;
esac

# 4) npm_registry_assign：仅 cn 注入 registry
out="$(REA_MIRROR=cn REA_MIRROR_MODE=cn npm_registry_assign)"
assert_contains "npm_config_registry=https://registry.npmmirror.com" "$out" "cn 注入 npmmirror registry"
out="$(REA_MIRROR=global REA_MIRROR_MODE=global npm_registry_assign)"
assert_empty "$out" "global 不注入 registry"

# 5) jdk_candidate_urls：离线（假 curl）拿不到 Adoptium JSON → 原样回退 fallback
out="$(PATH="$FAKEBIN:$PATH" REA_MIRROR=global REA_MIRROR_MODE=global jdk_candidate_urls linux x64 'https://example.com/jdk.tgz')"
assert_eq "https://example.com/jdk.tgz" "$out" "离线拿不到 Adoptium JSON 时回退单一官方 URL"

tests_done

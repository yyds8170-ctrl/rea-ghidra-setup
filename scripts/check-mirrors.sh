#!/usr/bin/env bash
# =============================================================================
# scripts/check-mirrors.sh — 镜像/源连通性与 Range 探测
#
# 对当前 REA_MIRROR 模式下的各候选源做 Range: bytes=0-0 探测，打印 OK/FAIL。
# 退出码：所有“必需源”全挂才非 0；镜像可选项不可达只 WARN，不阻断。
#
# 用法：REA_MIRROR=cn bash scripts/check-mirrors.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
load_versions

MODE="$(rea_mode)"
echo "镜像模式：REA_MIRROR=${REA_MIRROR:-auto} → 有效模式 = $MODE"

fail=0

# probe <描述> <url> <期望ContentLength(可空)>
probe() {
  local desc="$1" url="$2" expect_cl="${3:-}"
  local out
  out="$(curl -sL -o /dev/null -w '%{http_code} %{size_download}' \
        --connect-timeout 8 --max-time 25 -r 0-0 "$url" 2>/dev/null)"
  local code="${out%% *}"
  local cl
  cl="$(curl -sIL --connect-timeout 8 --max-time 25 "$url" 2>/dev/null \
        | awk 'tolower($0)~/^content-length:/{v=$2} END{gsub(/[^0-9]/,"",v);print v}')"
  if [ "$code" = "206" ] || [ "$code" = "200" ]; then
    if [ -n "$expect_cl" ] && [ "$cl" != "$expect_cl" ]; then
      printf '  [WARN] %-22s http=%s CL=%s（期望 %s）\n' "$desc" "$code" "$cl" "$expect_cl"
    else
      printf '  [OK]   %-22s http=%s CL=%s\n' "$desc" "$code" "$cl"
    fi
  else
    printf '  [FAIL] %-22s http=%s\n' "$desc" "$code"
    return 1
  fi
}

NODE_NAME="$(node_tarball_dir linux x64).tar.gz"
NODE_OFFICIAL="https://nodejs.org/dist/v${REA_NODE_VERSION}/${NODE_NAME}"
NODE_NPMM="https://registry.npmmirror.com/-/binary/node/v${REA_NODE_VERSION}/${NODE_NAME}"
NODE_HW="https://repo.huaweicloud.com/nodejs/v${REA_NODE_VERSION}/${NODE_NAME}"

echo "== Node v${REA_NODE_VERSION} (linux-x64) =="
probe "nodejs官方"  "$NODE_OFFICIAL" || true
probe "npmmirror"   "$NODE_NPMM" || true
probe "华为云"       "$NODE_HW" || true

echo "== JDK Temurin ${JDK_FEATURE} (linux-x64) =="
JDK_INFO="$(jdk_asset_info "$JDK_FEATURE" linux x64 2>/dev/null || true)"
JDK_SIZE="$(printf '%s' "$JDK_INFO" | cut -d'|' -f3)"
JDK_NAME="$(printf '%s' "$JDK_INFO" | cut -d'|' -f4)"
JDK_LINK="$(printf '%s' "$JDK_INFO" | cut -d'|' -f1)"
if [ -n "$JDK_NAME" ]; then
  JDK_TUNA="https://mirrors.tuna.tsinghua.edu.cn/Adoptium/${JDK_FEATURE}/jdk/x64/linux/${JDK_NAME}"
  probe "Adoptium官方" "$JDK_LINK" "$JDK_SIZE" || true
  probe "TUNA"         "$JDK_TUNA" "$JDK_SIZE" || true
else
  echo "  [WARN] 取不到 Adoptium assets JSON，跳过 JDK 探测（限流/离线）"
fi

echo "== npm registry (rea-agents) =="
probe "npmjs官方" "https://registry.npmjs.org/rea-agents" || true
probe "npmmirror" "https://registry.npmmirror.com/rea-agents" || true

echo
echo "当前模式下的 Node 候选顺序："
for u in $(node_candidate_urls "$NODE_NAME"); do echo "  - $u"; done

# 必需源判定：官方 nodejs 与 Adoptium 至少一个可用，否则才算失败（离线除外）
if ! probe "nodejs官方(必需)" "$NODE_OFFICIAL" >/dev/null 2>&1; then
  # cn 模式下官方可能就是不通，只要镜像可用即可，不判失败
  if [ "$MODE" = "cn" ]; then
    echo "（cn 模式官方直连不可达属预期，已回退镜像）"
  else
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then echo "镜像探测完成"; else echo "镜像探测：必需源不可用"; exit 1; fi

#!/usr/bin/env bash
# =============================================================================
# lib/mirrors.sh — 国内镜像加速策略（bash；Linux/macOS/WSL/Crostini）
#
# 只被 source（由 lib/common.sh 引入）。核心：
#   - REA_MIRROR=auto|cn|global 模式解析（auto 对官方主机做 ~5s 短探测）
#   - Node / JDK 的「官方 + 国内镜像」多源候选 URL 列表（顺序随模式变化）
#   - cn 模式下为 npx/npm 调用注入 npmmirror registry（仅当前进程，不改全局 .npmrc）
#
# 安全原则（与 v2.3 一致）：
#   - 镜像只是候选，官方源始终保留为最终回退；
#   - 镜像下载的文件仍必须过权威 checksum（Node 官方 SHASUMS256 / Adoptium JSON /
#     GitHub API digest），权威 checksum 不可达时维持「警告放行」语义；
#   - 不把“与镜像同源的 checksum”当作可信。
#
# 实测（2026-10-15）：
#   Node  v22.19.0：npmmirror ✓、华为云 ✓（Content-Length 与官方一致）；
#                   TUNA nodejs-release 未镜像该版本（404），故不写入。
#   JDK   Temurin 21：TUNA Adoptium 路径 ✓（Range 206，Content-Length==Adoptium package.size）；
#                   华为云 adoptium 路径当前不可用（错误页），故 JDK 镜像用 TUNA。
# =============================================================================

REA_NPM_MIRROR_REGISTRY="https://registry.npmmirror.com"

# 解析有效镜像模式（结果缓存）。global=仅官方顺序；cn=镜像优先官方兜底；
# auto=对官方 nodejs.org 做一次短连接探测，可达→global，超时→cn。
REA_MIRROR_MODE=""
rea_mode() {
  if [ -n "$REA_MIRROR_MODE" ]; then
    printf '%s' "$REA_MIRROR_MODE"
    return 0
  fi
  local m="${REA_MIRROR:-auto}"
  case "$m" in
    global|cn) REA_MIRROR_MODE="$m" ;;
    *)
      REA_MIRROR_MODE="global"
      if ! curl -sS -o /dev/null --connect-timeout 5 --max-time 8 -r 0-0 \
           "https://nodejs.org/dist/v${REA_NODE_VERSION}/SHASUMS256.txt" >/dev/null 2>&1; then
        REA_MIRROR_MODE="cn"
      fi
      ;;
  esac
  printf '%s' "$REA_MIRROR_MODE"
}

# Node 二进制候选 URL（$1=交付物 basename，如 node-v22.19.0-linux-x64.tar.gz）。
# 各镜像目录下文件名与官方完全一致，故直接 basename 拼接。
# echo 空格分隔列表：cn 模式镜像在前、官方兜底；global 模式官方在前。
node_candidate_urls() {
  local name="$1"
  local base="v${REA_NODE_VERSION}"
  local official="https://nodejs.org/dist/${base}/${name}"
  local npmmirror="https://registry.npmmirror.com/-/binary/node/${base}/${name}"
  local huawei="https://repo.huaweicloud.com/nodejs/${base}/${name}"
  if [ "$(rea_mode)" = "cn" ]; then
    printf '%s %s %s' "$npmmirror" "$huawei" "$official"
  else
    printf '%s %s %s' "$official" "$npmmirror" "$huawei"
  fi
}

# Adoptium assets JSON 取 JDK 包信息：echo “link|checksum|size|name”。
# $1=feature $2=os(linux/mac/windows) $3=arch(x64/aarch64)。失败返回非 0。
jdk_asset_info() {
  local feature="$1" os="$2" arch="$3" url
  url="https://api.adoptium.net/v3/assets/latest/${feature}/hotspot?architecture=${arch}&os=${os}&image_type=jdk&vendor=eclipse"
  curl -fsSL "$url" 2>/dev/null | python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
    for b in d:
        pk=b.get("binary",{}).get("package",{})
        if pk.get("checksum"):
            print("%s|%s|%s|%s" % (pk.get("link",""), pk.get("checksum",""), pk.get("size",""), pk.get("name","")))
            sys.exit(0)
except Exception:
    pass
sys.exit(1)
'
}

# JDK 候选 URL（$1=os $2=arch $3=官方兜底 URL（api redirect））。
# cn 模式 TUNA 在前、GitHub release 官方在后；global 反之。
# 拿不到 Adoptium JSON（限流/离线）时退回单一官方 URL，强校验逻辑照旧。
jdk_candidate_urls() {
  local os="$1" arch="$2" fallback="$3"
  local info link name
  info="$(jdk_asset_info "$JDK_FEATURE" "$os" "$arch" 2>/dev/null || true)"
  link="$(printf '%s' "$info" | cut -d'|' -f1)"
  name="$(printf '%s' "$info" | cut -d'|' -f4)"
  if [ -z "$link" ] || [ -z "$name" ]; then
    printf '%s' "$fallback"
    return 0
  fi
  local tuna="https://mirrors.tuna.tsinghua.edu.cn/Adoptium/${JDK_FEATURE}/jdk/${arch}/${os}/${name}"
  if [ "$(rea_mode)" = "cn" ]; then
    printf '%s %s' "$tuna" "$link"
  else
    printf '%s %s' "$link" "$tuna"
  fi
}

# 在 cn 模式下，为 npx/npm 调用注入 npmmirror registry（仅当前命令/进程，
# 不写用户全局 .npmrc）。用法：REA=(env "$(npm_registry_assign)" npx ...)
npm_registry_assign() {
  if [ "$(rea_mode)" = "cn" ]; then
    printf 'npm_config_registry=%s' "$REA_NPM_MIRROR_REGISTRY"
  fi
}

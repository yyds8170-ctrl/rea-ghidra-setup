#!/usr/bin/env bash
# =============================================================================
# lib/checksums.sh — 下载物 SHA-256 校验（Linux / macOS / WSL / Crostini）
#
# 只被 source。提供三类上游校验和来源：
#   - Node   ：官方 SHASUMS256.txt
#   - JDK    ：Adoptium v3 assets JSON 的 package.checksum
#   - Ghidra ：GitHub release asset 的 digest（sha256: 前缀）
# 以及离线包（scripts/prepare-offline.sh 生成的 SHA256SUMS.txt）。
#
# 安全策略：
#   - 校验和能拿到且不匹配 → 判定失败（硬错误，拒绝使用该文件）。
#   - 校验和来源不可达（离线/限流）且没有离线清单 → 警告但继续（不阻断离线安装）。
#   - 离线包若带有 SHA256SUMS.txt，则以其为准，离线也能强校验。
# =============================================================================

# 计算文件 SHA-256（兼容 Linux sha256sum 与 macOS shasum）
cs_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 2
  fi
}

# 从离线清单中取某文件的期望哈希；清单不存在或无匹配时返回 1。
cs_manifest_sha() {
  local manifest="$1" name="$2"
  [ -f "$manifest" ] || return 1
  awk -v n="$name" '$2==n{print $1; found=1} END{exit found?0:1}' "$manifest"
}

# Node 官方 SHASUMS256.txt 取期望哈希；无网络返回 2，无匹配返回 1。
cs_expected_node() {
  local ver="$1" basename="$2" url tmp
  url="https://nodejs.org/dist/v${ver}/SHASUMS256.txt"
  tmp="$(mktemp)"; : > "$tmp"
  if curl -fsSL "$url" -o "$tmp" 2>/dev/null; then
    awk -v n="$basename" '$2==n{print $1; found=1} END{exit found?0:1}' "$tmp"
    rc=$?; rm -f "$tmp"; return $rc
  fi
  rm -f "$tmp"; return 2
}

# Adoptium assets JSON 取 JDK 包的 package.checksum；参数 os=linux|mac|windows arch=x64|aarch64
cs_expected_jdk() {
  local feature="$1" os="$2" arch="$3" url
  # Adoptium 用 x64/aarch64（windows/linux/mac 一致）
  url="https://api.adoptium.net/v3/assets/latest/${feature}/hotspot?architecture=${arch}&os=${os}&image_type=jdk&vendor=eclipse"
  curl -fsSL "$url" 2>/dev/null | python3 -c '
import sys,json
try:
    data=json.load(sys.stdin)
    for b in data:
        pk=b.get("binary",{}).get("package",{})
        if pk.get("checksum"):
            print(pk["checksum"]); sys.exit(0)
except Exception:
    pass
sys.exit(1)
'
}

# GitHub release asset digest（sha256:xxxx）；参数 tag asset_basename。
# 若设置了 GITHUB_TOKEN / GH_TOKEN 会带上以提高限流额度。
cs_expected_ghidra() {
  local tag="$1" asset="$2" auth=()
  local tok="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  [ -n "$tok" ] && auth=(-H "Authorization: Bearer $tok")
  curl -fsSL "${auth[@]}" \
    "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/tags/${tag}" 2>/dev/null | \
    python3 -c '
import sys,json
asset=sys.argv[1]
try:
    data=json.load(sys.stdin)
    for a in data.get("assets",[]):
        if a.get("name")==asset:
            d=a.get("digest") or ""
            if d.startswith("sha256:"): d=d.split(":",1)[1]
            if d: print(d); sys.exit(0)
except Exception:
    pass
sys.exit(1)
' "$asset"
}

# 校验文件哈希；参数：file expected。0=匹配 1=不匹配 2=无法计算
cs_verify() {
  local file="$1" expected="$2" actual
  [ -f "$file" ] || return 1
  actual="$(cs_sha256 "$file" 2>/dev/null)" || return 2
  [ -n "$actual" ] || return 2
  [ "$actual" = "$expected" ]
}

# 统一取“交付物”：优先离线目录，否则下载；并尽量做 SHA-256 校验。
#
# 参数：
#   $1 kind      node | jdk | ghidra
#   $2 basename  交付物文件名（如 node-v22.19.0-linux-x64.tar.gz）
#   $3 url       在线下载地址
#   $4 out       落地路径（下载/复制到这里）
# 环境：
#   OFFLINE_DIR    离线包目录（含可选的 SHA256SUMS.txt）
#   版本变量来自 lib/common.sh（load_versions 之后调用）
# 返回：0 成功（已校验或离线放行）；1 校验和不匹配（硬错误）；2 下载失败
fetch_artifact() {
  local kind="$1" name="$2" url="$3" out="$4"
  local expected="" have_manifest=0 src=""
  local manifest="${OFFLINE_DIR:-}/SHA256SUMS.txt"
  [ -n "${OFFLINE_DIR:-}" ] && [ -f "$manifest" ] && have_manifest=1

  mkdir -p "$(dirname "$out")"

  # 1) 离线清单优先（离线也能强校验）
  if [ "$have_manifest" = "1" ]; then
    expected="$(cs_manifest_sha "$manifest" "$name" 2>/dev/null || true)"
  fi

  # 2) 选来源：离线目录中的同名文件，否则联网下载
  if [ -n "${OFFLINE_DIR:-}" ] && [ -f "$OFFLINE_DIR/$name" ]; then
    src="$OFFLINE_DIR/$name"
    cp -f "$src" "$out"
    echo "[离线] 使用 $OFFLINE_DIR/$name"
  else
    if ! curl -fSL "$url" -o "$out"; then
      echo "下载失败：$url" >&2
      return 2
    fi
  fi

  # 3) 离线清单未命中时，联网查上游期望哈希（有则强校验）
  if [ -z "$expected" ]; then
    case "$kind" in
      node)  expected="$(cs_expected_node "$REA_NODE_VERSION" "$name" 2>/dev/null || true)" ;;
      jdk)
        local _os _arch
        _os="$(uname -s | tr '[:upper:]' '[:lower:]')"; _os="${_os%%_*}"
        [ "$_os" = "darwin" ] && _os=mac
        _arch="$(normalize_arch)"
        expected="$(cs_expected_jdk "$JDK_FEATURE" "$_os" "$_arch" 2>/dev/null || true)" ;;
      ghidra) expected="$(cs_expected_ghidra "$GHIDRA_BUILD" "$(ghidra_zip_name)" 2>/dev/null || true)" ;;
    esac
  fi

  if [ -n "$expected" ]; then
    if cs_verify "$out" "$expected"; then
      echo "[校验] $name SHA-256 一致"
      return 0
    else
      echo "[校验失败] $name 哈希不匹配，删除并中止（可能下载损坏或被篡改）" >&2
      echo "  期望：$expected" >&2
      echo "  实际：$(cs_sha256 "$out" 2>/dev/null)" >&2
      rm -f "$out"
      return 1
    fi
  fi

  # 无法获得期望哈希（离线且无清单 / 限流）：放行但明确警告
  if [ -n "${OFFLINE_DIR:-}" ] && [ ! -f "$manifest" ]; then
    echo "[警告] 离线目录无 SHA256SUMS.txt，未校验 ${name}（建议用 prepare-offline.sh 生成完整离线包）" >&2
  else
    echo "[警告] 未能获取 $name 的上游校验和（离线或限流），已跳过校验" >&2
  fi
  return 0
}

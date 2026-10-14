#!/usr/bin/env bash
# =============================================================================
# lib/common.sh — 各平台 bash 安装/验证脚本共用的工具函数
#
# 本文件只被 source，不直接执行。提供：
#   - 版本号加载（config/versions.env 为默认值，调用方已 export 的变量优先）
#   - 下载 URL 构造（Ghidra 跨平台 zip、Adoptium Temurin JDK、Node）
#   - 日志与架构归一化
#
# 兼容 bash（Linux / macOS / WSL / Crostini）。
# =============================================================================

# 仓库根目录（lib/ 的上一级）
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIB_DIR/.." && pwd)"

# 健壮下载内核（download / github_proxy_urls）；所有交付物下载统一走它
# shellcheck source=lib/download.sh
. "$LIB_DIR/download.sh"

# ---- 确保 UTF-8 locale ------------------------------------------------------
# CI（尤其 macOS 的 bash -e step）可能未设 LANG，回退为 C/POSIX 环境，
# 此时 "$VAR" 后紧跟的中文多字节字符会被当作变量名的一部分（unbound）。
ensure_utf8_locale() {
  if locale charmap 2>/dev/null | grep -qi 'UTF-8'; then
    return 0
  fi
  local _loc
  for _loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8 zh_CN.UTF-8; do
    if LANG="$_loc" LC_ALL="$_loc" locale charmap 2>/dev/null | grep -qi 'UTF-8'; then
      export LANG="$_loc"
      export LC_ALL="$_loc"
      return 0
    fi
  done
}
ensure_utf8_locale

# ---- 日志（带颜色；非 TTY 时自动无 ANSI）-----------------------------------
if [ -t 1 ]; then
  C_GREEN='\033[32m'; C_BLUE='\033[36m'; C_YELLOW='\033[33m'
  C_RED='\033[31m'; C_RESET='\033[0m'
else
  C_GREEN=''; C_BLUE=''; C_YELLOW=''; C_RED=''; C_RESET=''
fi
log()  { printf '%b[*]%b %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '%b[OK]%b %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%b[!]%b %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%b[ERR]%b %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# ---- 版本加载：config/versions.env 为默认，已存在的环境变量不被覆盖 --------
load_versions() {
  local vfile="$REPO_ROOT/config/versions.env"
  [ -f "$vfile" ] || die "找不到版本文件 $vfile"
  local key val
  while IFS='=' read -r key val || [ -n "$key" ]; do
    key="${key//[[:space:]]/}"
    case "$key" in
      ''|'#'*) continue ;;
    esac
    # 仅当该变量当前为空（未由调用方 export）时使用默认值
    if [ -z "${!key:-}" ]; then
      export "$key=$val"
    fi
  done < "$vfile"
}

# Ghidra 跨平台发布 zip（Windows/macOS/Linux 用同一个包）
ghidra_zip_name() {
  printf 'ghidra_%s_PUBLIC_%s.zip' "$GHIDRA_VERSION" "$GHIDRA_DATE"
}
ghidra_release_url() {
  printf 'https://github.com/NationalSecurityAgency/ghidra/releases/download/%s/%s' \
    "$GHIDRA_BUILD" "$(ghidra_zip_name)"
}
# Ghidra 解压后的目录名（跨平台一致）
ghidra_dir_name() { printf 'ghidra_%s_PUBLIC' "$GHIDRA_VERSION"; }

# Adoptium Temurin JDK 最新小版本二进制（重定向到具体文件）
# 参数：$1=OS（linux/mac/windows）  $2=arch（x64/aarch64）
# 另见：https://api.adoptium.net/q/swagger-ui/
adoptium_jdk_url() {
  local os="$1" arch="$2" image="${3:-jdk}"
  printf 'https://api.adoptium.net/v3/binary/latest/%s/ga/%s/%s/%s/hotspot/normal/eclipse' \
    "$JDK_FEATURE" "$os" "$arch" "$image"
}

# Node 官方二进制目录（仅 Linux/macOS 的 tar.gz；Windows 用 zip 或 msi）
node_tarball_url() {
  local os="$1" arch="$2"   # os=darwin|linux；arch=x64|arm64|aarch64
  local narch="$arch"
  [ "$arch" = "aarch64" ] && narch="arm64"
  printf 'https://nodejs.org/dist/v%s/node-v%s-%s-%s.tar.gz' \
    "$REA_NODE_VERSION" "$REA_NODE_VERSION" "$os" "$narch"
}

# 把 uname -m 归一化为 x64 / aarch64 / 其它（原样）
normalize_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    x86_64|amd64) echo x64 ;;
    arm64|aarch64) echo aarch64 ;;
    *) echo "$m" ;;
  esac
}

# Node 解压后的目录名（tar.gz 包），如 node-v22.19.0-linux-x64
node_tarball_dir() {
  local os="$1" arch="$2" narch="$2"
  [ "$arch" = "aarch64" ] && narch="arm64"
  printf 'node-v%s-%s-%s' "$REA_NODE_VERSION" "$os" "$narch"
}

# REA 要求 Node ^22.19 || ^24.11 || >=26；检查当前 PATH 上的 node 是否满足
# 返回 0 满足、1 不满足（或没有 node）。
node_satisfies_rea() {
  command -v node >/dev/null 2>&1 || return 1
  local v major minor
  v="$(node --version 2>/dev/null | sed 's/^v//; s/-.*//')"
  major="${v%%.*}"
  minor="${v#*.}"; minor="${minor%%.*}"
  case "$major" in ''|*[!0-9]*) return 1 ;; esac
  [ "$major" -ge 26 ] && return 0
  [ "$major" -eq 24 ] && [ "${minor:-0}" -ge 11 ] && return 0
  [ "$major" -eq 22 ] && [ "${minor:-0}" -ge 19 ] && return 0
  return 1
}

# 下载并解压便携 Node 到 $1=tools_dir；$2=os(darwin|linux)；$3=arch(x64|aarch64)
# 建立版本无关软链 <tools_dir>/node，echo 该软链路径。
# 若已 source lib/checksums.sh（fetch_artifact 可用），则走带校验/离线的下载。
install_node_portable() {
  local tools_dir="$1" os="$2" arch="$3" tmp name
  tmp="$(mktemp -d)"
  name="$(node_tarball_dir "$os" "$arch").tar.gz"
  if type -t fetch_artifact >/dev/null 2>&1; then
    fetch_artifact node "$name" "$(node_tarball_url "$os" "$arch")" "$tmp/$name"
  else
    download "$tmp/$name" "$(node_tarball_url "$os" "$arch")"
  fi
  tar -xzf "$tmp/$name" -C "$tools_dir"
  rm -rf "$tmp"
  ln -sfn "$tools_dir/$(node_tarball_dir "$os" "$arch")" "$tools_dir/node"
  printf '%s\n' "$tools_dir/node"
}

# 检测是否运行在 WSL（Windows Subsystem for Linux）
is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# 检测是否运行在 ChromeOS Crostini（官方 Linux 开发环境）
is_crostini() {
  # Crostini 容器常见标记：/dev/.cros_milestone 或 cros-env
  [ -f /dev/.cros_milestone ] || grep -q container=lxc /proc/1/environ 2>/dev/null
}

# 检测是否运行在 Docker / 其它容器（K8s/containerd）
is_docker() {
  [ -f /.dockerenv ] && return 0
  grep -qE 'docker|containerd|kubepods|lxc' /proc/1/cgroup 2>/dev/null
}

# 稳定的运行环境标记：physical | wsl | crostini | docker | vm
env_token() {
  if is_wsl; then
    echo wsl
  elif is_crostini; then
    echo crostini
  elif is_docker; then
    echo docker
  elif command -v systemd-detect-virt >/dev/null 2>&1; then
    case "$(systemd-detect-virt 2>/dev/null || echo none)" in
      none) echo physical ;;
      *)    echo vm ;;
    esac
  else
    echo physical
  fi
}

# 运行环境的中文标签（供各脚本打印）
env_label() {
  case "$(env_token)" in
    wsl)      echo 'WSL2（Windows 上的 Linux 子系统）' ;;
    crostini) echo 'ChromeOS Crostini（Linux 开发环境）' ;;
    docker)   echo 'Docker 容器' ;;
    vm)       echo '虚拟机/云电脑（VDI）' ;;
    *)        echo '物理本机' ;;
  esac
}


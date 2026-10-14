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

# 检测是否运行在 WSL（Windows Subsystem for Linux）
is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# 检测是否运行在 ChromeOS Crostini（官方 Linux 开发环境）
is_crostini() {
  # Crostini 容器常见标记：/dev/.cros_milestone 或 cros-env
  [ -f /dev/.cros_milestone ] || grep -q container=lxc /proc/1/environ 2>/dev/null
}

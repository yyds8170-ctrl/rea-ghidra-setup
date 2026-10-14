#!/usr/bin/env bash
# =============================================================================
# scripts/detect-env.sh — 识别当前操作系统 / CPU 架构 / 运行环境
#
# 用于在安装前确认该用哪个安装脚本，以及 Ghidra native decompiler 是否需要自建：
#   系统：Linux / macOS（Windows 请在 PowerShell 运行，见 lib/common.ps1）
#   架构：x64 / aarch64
#   环境：physical（物理本机）/ wsl / crostini（ChromeOS）/ docker / vm（含 VDI）
#
# 用法：
#   bash scripts/detect-env.sh            # 人类可读
#   bash scripts/detect-env.sh --shell    # KEY=VALUE，便于 eval
#   bash scripts/detect-env.sh --json     # JSON
# 退出码：0 始终成功（检测仅为信息性）。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
# shellcheck source-path=SCRIPTDIR/..
source "$SCRIPT_DIR/../lib/common.sh"

# ---- 操作系统 ----------------------------------------------------------------
OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Linux)  OS=linux ;;
  Darwin) OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  *) OS="$OS_NAME" ;;
esac

# ---- 发行版（Linux）----------------------------------------------------------
PRETTY=""; DISTRO=""
if [ "$OS" = linux ] && [ -r /etc/os-release ]; then
  . /etc/os-release 2>/dev/null || true
  PRETTY="${PRETTY_NAME:-}"
  DISTRO="${ID:-}"
fi
if [ "$OS" = macos ]; then
  PRETTY="macOS $(sw_vers -productVersion 2>/dev/null || true)"
fi

# ---- 架构 --------------------------------------------------------------------
ARCH="$(normalize_arch)"
case "$OS" in
  linux)  GHIDRA_OS_DIR="linux_x86_64"; [ "$ARCH" = aarch64 ] && GHIDRA_OS_DIR="linux_arm_64" ;;
  macos)  GHIDRA_OS_DIR="mac_x86_64";   [ "$ARCH" = aarch64 ] && GHIDRA_OS_DIR="mac_arm_64" ;;
  windows) GHIDRA_OS_DIR="win_x86_64" ;;
  *) GHIDRA_OS_DIR="unknown" ;;
esac

# ---- 运行环境 ----------------------------------------------------------------
ENV_TOKEN="$(env_token)"
ENV_LABEL="$(env_label)"

# x86_64 Linux / Windows 官方预编译；arm64 Linux 与 macOS（含 x64 个别版本）需自建
case "$GHIDRA_OS_DIR" in
  linux_x86_64|win_x86_64) NATIVE="prebuilt" ;;
  linux_arm_64|mac_arm_64|mac_x86_64) NATIVE="build-required" ;;
  *) NATIVE="unknown" ;;
esac

# 推荐安装脚本
case "$OS" in
  linux)   INSTALLER="bash install.sh" ;;
  macos)   INSTALLER="bash install-macos.sh" ;;
  windows) INSTALLER="powershell -ExecutionPolicy Bypass -File install.ps1" ;;
  *)       INSTALLER="unknown" ;;
esac

# ---- 输出 --------------------------------------------------------------------
case "${1:-}" in
  --json)
    printf '{'
    printf '"os":"%s",' "$OS"
    printf '"distro":"%s",' "$DISTRO"
    printf '"pretty":"%s",' "$PRETTY"
    printf '"arch":"%s",' "$ARCH"
    printf '"environment":"%s",' "$ENV_TOKEN"
    printf '"environment_label":"%s",' "$ENV_LABEL"
    printf '"ghidra_native_dir":"%s",' "$GHIDRA_OS_DIR"
    printf '"native":"%s",' "$NATIVE"
    printf '"installer":"%s"' "$INSTALLER"
    printf '}\n'
    ;;
  --shell)
    echo "OS=$OS"
    echo "DISTRO=$DISTRO"
    echo "PRETTY_NAME=$PRETTY"
    echo "ARCH=$ARCH"
    echo "ENVIRONMENT=$ENV_TOKEN"
    echo "GHIDRA_NATIVE_DIR=$GHIDRA_OS_DIR"
    echo "NATIVE=$NATIVE"
    echo "INSTALLER=$INSTALLER"
    ;;
  *)
    echo "=========================================================="
    echo " 运行环境识别"
    echo "----------------------------------------------------------"
    echo " 操作系统   : ${PRETTY:-$OS_NAME}"
    echo " CPU 架构   : $ARCH"
    echo " 运行环境   : $ENV_LABEL（$ENV_TOKEN）"
    echo " Ghidra 平台 : $GHIDRA_OS_DIR"
    if [ "$NATIVE" = prebuilt ]; then
      echo " native     : 官方预编译，无需自建"
    else
      echo " native     : 官方未预编译，需 bash scripts/build-ghidra-native.sh"
    fi
    echo " 推荐安装   : $INSTALLER"
    echo "=========================================================="
    ;;
esac

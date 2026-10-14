#!/usr/bin/env bash
# =============================================================================
# scripts/build-ghidra-native.sh — 从源码构建 Ghidra native decompiler
#
# Ghidra 官方发布包对常见平台预编译了 native decompiler；以下架构官方【不预编译】，
# 需用本脚本在本机用 C++ 源码构建（REA 官方文档同款做法）：
#   - Linux arm64  → Ghidra/Features/Decompiler/os/linux_arm_64/decompile
#   - macOS arm64  → Ghidra/Features/Decompiler/os/mac_arm_64/decompile
#   - macOS x86_64 → Ghidra/Features/Decompiler/os/mac_x86_64/decompile（官方包可能只带源码）
# Linux x86_64 / Windows x86_64 官方自带，通常无需构建（可用 --force 重建）。
#
# 依赖：make、C++ 编译器（g++/clang++；macOS 为 Xcode CLT）、bison（个别发行版需要）。
# 构建只需要 C++ 工具链，不需要 JDK。
#
# 用法：bash scripts/build-ghidra-native.sh [--force]
# 环境变量：GHIDRA_INSTALL_DIR 可显式指定；否则在 ~/tools 下查找。
# 退出码：0=已存在/构建成功；2=缺少构建工具；3=不支持的平台；1=构建失败。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# ---- 定位 Ghidra ------------------------------------------------------------
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-$(find "$HOME/tools" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null | head -1)}"
if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -d "$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler" ]; then
  echo "未找到 Ghidra（Features/Decompiler）。请先运行安装脚本或设置 GHIDRA_INSTALL_DIR。" >&2
  exit 1
fi
CPP_SRC="$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/src/decompile/cpp"
OS_BASE="$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os"
[ -d "$CPP_SRC" ] || { echo "Ghidra 发布包缺少 decompiler 源码目录：$CPP_SRC" >&2; exit 1; }

# ---- 确定目标平台目录与编译参数 --------------------------------------------
UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"
case "$UNAME_S" in
  Linux)
    case "$UNAME_M" in
      x86_64|amd64) OSDIR=linux_x86_64; ARCH_TYPE="-m64";      PREBUILT=1 ;;
      arm64|aarch64) OSDIR=linux_arm_64; ARCH_TYPE="";         PREBUILT=0 ;;
      *) echo "不支持的 Linux 架构：$UNAME_M" >&2; exit 3 ;;
    esac
    ;;
  Darwin)
    case "$UNAME_M" in
      x86_64)        OSDIR=mac_x86_64; ARCH_TYPE="-arch x86_64"; PREBUILT=0 ;;
      arm64|aarch64) OSDIR=mac_arm_64;  ARCH_TYPE="-arch arm64";  PREBUILT=0 ;;
      *) echo "不支持的 macOS 架构：$UNAME_M" >&2; exit 3 ;;
    esac
    ;;
  *)
    echo "本脚本仅支持 Linux / macOS（Windows 请用官方自带 win_x86_64 二进制）。当前：$UNAME_S" >&2
    exit 3
    ;;
esac

DEST_DIR="$OS_BASE/$OSDIR"
DEST_BIN="$DEST_DIR/decompile"

if [ "$FORCE" -ne 1 ] && [ -x "$DEST_BIN" ]; then
  echo "native decompiler 已存在：$DEST_BIN（如需重建用 --force）"
  exit 0
fi
if [ "$PREBUILT" = 1 ] && [ "$FORCE" -ne 1 ]; then
  echo "该平台官方预编译，无需构建：$DEST_BIN"
  exit 0
fi

# ---- 检查构建工具 -----------------------------------------------------------
command -v make >/dev/null 2>&1 || { echo "缺少 make。" >&2; MISSING_TOOL=1; }
if ! command -v g++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then
  echo "缺少 C++ 编译器（g++/clang++）。" >&2; MISSING_TOOL=1
fi
if [ "${MISSING_TOOL:-0}" = 1 ]; then
  echo "请先安装构建工具：" >&2
  case "$UNAME_S" in
    Linux)  echo "  Debian/Ubuntu：sudo apt install build-essential bison" >&2
            echo "  Fedora/RHEL  ：sudo dnf install gcc-c++ make bison" >&2 ;;
    Darwin) echo "  xcode-select --install    # 安装 Xcode 命令行工具（含 clang/make）" >&2 ;;
  esac
  exit 2
fi
if ! command -v bison >/dev/null 2>&1; then
  warn "未检测到 bison（多数情况下发布包已附带生成好的解析器，可继续；若报错请安装 bison）"
fi

# ---- 构建 -------------------------------------------------------------------
log "构建 native decompiler：$UNAME_S/$UNAME_M → $OSDIR"
mkdir -p "$DEST_DIR"
# 用临时构建目录避免污染源码树（在 cpp 目录内执行，Makefile 相对路径依赖该目录）
cd "$CPP_SRC"
# 清理同名旧产物（若有），避免链接到陈旧目标
rm -f ghidra_opt
if [ "$UNAME_S" = Darwin ]; then
  # macOS 需显式覆盖架构（Makefile 默认 -arch x86_64 与 -mmacosx-version-min=10.6）
  make ghidra_opt ARCH_TYPE="$ARCH_TYPE" OSDIR="$OSDIR" ADDITIONAL_FLAGS="-w"
else
  # Linux arm64 必须显式传空 ARCH_TYPE 与 OSDIR，否则 Makefile 会退回 -m32
  make ghidra_opt ARCH_TYPE="$ARCH_TYPE" OSDIR="$OSDIR"
fi

[ -x ghidra_opt ] || { echo "构建失败：未生成 ghidra_opt" >&2; exit 1; }
install -m 755 ghidra_opt "$DEST_BIN"
ok "已安装 native decompiler：$DEST_BIN"

# 简单自检：文件存在且为可执行
test -x "$DEST_BIN" || { echo "安装后自检失败：$DEST_BIN 不可执行" >&2; exit 1; }
ok "完成。可运行：rea doctor --provider ghidra 复核"

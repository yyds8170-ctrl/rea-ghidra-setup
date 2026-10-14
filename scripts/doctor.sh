#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh — REA + Ghidra 只读自检（Linux / macOS / WSL / Crostini）
#
# 安装前预检、安装后复检都用它。不改动任何配置，只报告：
#   [PASS] 满足 / [WARN] 可用但有隐患 / [FAIL] 阻断（必须处理）
# 存在任一 FAIL 时退出码为 1；仅有 WARN 时退出码为 0。
#
# 用法：
#   bash scripts/doctor.sh            # 人类可读
#   GHIDRA_INSTALL_DIR=/path bash scripts/doctor.sh
#
# 与 `rea doctor` 的分工：rea doctor 校验 REA 自身的 provider 连接；
# 本脚本校验本项目各安装脚本关心的操作系统/架构/工具链/环境变量前置条件。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
# shellcheck source-path=SCRIPTDIR/..
source "$SCRIPT_DIR/../lib/common.sh"
load_versions

PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
p() { printf '%b[PASS]%b %s\n' "$C_GREEN" "$C_RESET" "$*"; PASS_COUNT=$((PASS_COUNT+1)); }
w() { printf '%b[WARN]%b %s\n' "$C_YELLOW" "$C_RESET" "$*"; WARN_COUNT=$((WARN_COUNT+1)); }
f() { printf '%b[FAIL]%b %s\n' "$C_RED" "$C_RESET" "$*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
hr() { printf '%s\n' '------------------------------------------------------------'; }

UNAME_S="$(uname -s)"
ARCH="$(normalize_arch)"
case "$UNAME_S" in
  Linux)
    [ "$ARCH" = "aarch64" ] && NATIVE_OSDIR="linux_arm_64" || NATIVE_OSDIR="linux_x86_64" ;;
  Darwin)
    [ "$ARCH" = "aarch64" ] && NATIVE_OSDIR="mac_arm_64" || NATIVE_OSDIR="mac_x86_64" ;;
  *) NATIVE_OSDIR="unknown" ;;
esac

echo '============================================================'
echo ' REA + Ghidra 自检（doctor）'
echo " 系统   = $UNAME_S ($(uname -m)) / 运行环境 = $(env_label)"
echo " 锁定版本 = Ghidra ${GHIDRA_VERSION:-?} / JDK ${JDK_FEATURE:-?} / Node ${REA_NODE_VERSION:-?} / rea ${REA_VERSION:-?}"
echo " 期望 native 目录 = ${NATIVE_OSDIR}"
hr

# ---- 1. Node -------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  NV="$(node --version 2>/dev/null)"
  if node_satisfies_rea; then
    p "Node ${NV} 满足 REA 要求（^22.19 || ^24.11 || >=26）"
  else
    f "Node ${NV} 不满足要求：需 Node 22.19+ / 24.11+ / 26+（运行安装脚本或 fnm/nvm 切换）"
  fi
else
  f "未找到 node：REA 要求 Node 22.19+ / 24.11+ / 26+（运行安装脚本会装便携 Node 22）"
fi

# ---- 2. JDK 21 -------------------------------------------------------------
JAVA_BIN=""
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  JAVA_BIN="${JAVA_HOME}/bin/java"
elif command -v java >/dev/null 2>&1; then
  JAVA_BIN="$(command -v java)"
fi
if [ -n "$JAVA_BIN" ]; then
  JVER_RAW="$("$JAVA_BIN" -version 2>&1 | awk -F\" '/version/ {print $2; exit}')"
  JMAJOR="${JVER_RAW%%.*}"
  # 旧版 1.8 形式
  [ "$JMAJOR" = "1" ] && JMAJOR="$(echo "$JVER_RAW" | awk -F. '{print $2}')"
  if [ "${JMAJOR:-0}" -eq "$JDK_FEATURE" ] 2>/dev/null; then
    p "JDK ${JVER_RAW}（${JAVA_BIN}）"
  elif [ "${JMAJOR:-0}" -gt "$JDK_FEATURE" ] 2>/dev/null; then
    w "JDK ${JVER_RAW} 高于要求的 ${JDK_FEATURE}；Ghidra 通常要求恰好 ${JDK_FEATURE}，建议装 Temurin ${JDK_FEATURE}"
  else
    f "JDK ${JVER_RAW} 过低：Ghidra 12.x 要求 JDK ${JDK_FEATURE}（安装脚本会装 Temurin ${JDK_FEATURE}）"
  fi
  [ -z "${JAVA_HOME:-}" ] && w "未设置 JAVA_HOME（部分启动器依赖它；安装脚本会写）"
else
  f "未找到 java：Ghidra 要求 64 位 JDK ${JDK_FEATURE}（运行安装脚本会装 Temurin）"
fi

# ---- 3. Ghidra / analyzeHeadless ------------------------------------------
GH_DIR="${GHIDRA_INSTALL_DIR:-}"
if [ -n "$GH_DIR" ] && [ -d "$GH_DIR" ]; then
  HEADLESS="$GH_DIR/support/analyzeHeadless"
  case "$UNAME_S" in
    *) HEADLESS_BIN="$HEADLESS" ;;
  esac
  if [ -x "$HEADLESS_BIN" ]; then
    p "Ghidra 安装目录存在且 analyzeHeadless 可执行（${GH_DIR}）"
  else
    f "GHIDRA_INSTALL_DIR 已设但缺少可执行的 support/analyzeHeadless：$GH_DIR"
  fi
else
  f "未设置或不存在 GHIDRA_INSTALL_DIR（运行安装脚本会下载并解压 Ghidra ${GHIDRA_VERSION}）"
fi

# ---- 4. native decompiler（关键，arm64/macOS 常缺失）----------------------
if [ -n "$GH_DIR" ] && [ -d "$GH_DIR" ]; then
  DECOMP="$GH_DIR/Ghidra/Features/Decompiler/os/$NATIVE_OSDIR/decompile"
  if [ -x "$DECOMP" ]; then
    p "native decompiler 就位：os/$NATIVE_OSDIR/decompile"
  elif [ "$NATIVE_OSDIR" = "linux_x86_64" ] || [ "$NATIVE_OSDIR" = "win_x86_64" ]; then
    f "缺少官方预编译 native decompiler：${DECOMP}（发布包可能解压不完整，建议重新解压）"
  else
    f "缺少 native decompiler：${DECOMP}；官方对 $NATIVE_OSDIR 不预编译，请运行 scripts/build-ghidra-native.sh"
  fi

  # macOS Gatekeeper 隔离属性
  if [ "$UNAME_S" = "Darwin" ] && command -v xattr >/dev/null 2>&1; then
    if xattr -pr com.apple.quarantine "$GH_DIR" >/dev/null 2>&1; then
      w "Ghidra 目录仍带 com.apple.quarantine 隔离：执行 xattr -dr com.apple.quarantine \"$GH_DIR\""
    else
      p "未发现 Gatekeeper 隔离属性"
    fi
  fi
fi

# ---- 5. rea 命令 -----------------------------------------------------------
if command -v rea >/dev/null 2>&1; then
  p "已全局安装 rea（$(command -v rea)）"
else
  w "未发现全局 rea 命令；可直接用 npx -y rea-agents@${REA_VERSION}（安装脚本会全局安装）"
fi

# ---- 5b. 镜像模式（信息性；可选源不可达不阻断）------------------------------
_mmode="$(rea_mode 2>/dev/null || echo unknown)"
if [ "$_mmode" = "cn" ]; then
  w "镜像模式=cn（REA_MIRROR=${REA_MIRROR:-auto}）：下载优先国内镜像，npm 走 npmmirror；详细探测见 scripts/check-mirrors.sh"
else
  p "镜像模式=${_mmode}（REA_MIRROR=${REA_MIRROR:-auto}）：官方源优先"
fi

# ---- 6. 构建工具链（仅在需要自建 native 时才重要）--------------------------
need_build=0
if [ "$NATIVE_OSDIR" = "linux_arm_64" ] || [ "$NATIVE_OSDIR" = "mac_arm_64" ] || [ "$NATIVE_OSDIR" = "mac_x86_64" ]; then
  if [ ! -x "${DECOMP:-/nonexistent}" ]; then need_build=1; fi
fi
if [ "$need_build" = "1" ]; then
  for tool in make g++; do
    if command -v "$tool" >/dev/null 2>&1; then p "构建工具 $tool 可用（$(command -v "$tool")）" ; else f "缺少构建工具 ${tool}（自建 native 需要）"; fi
  done
  if command -v bison >/dev/null 2>&1; then p "bison 可用"; else w "缺少 bison（多数发布包自带生成的解析器，可先构建；若报错再安装）"; fi
  if [ "$UNAME_S" = "Darwin" ]; then
    if xcode-select -p >/dev/null 2>&1; then
      p "Xcode 命令行工具已安装"
    else
      f "未安装 Xcode 命令行工具：xcode-select --install"
    fi
  fi
fi

# ---- 7. 路径 / 磁盘 / 内存 -------------------------------------------------
case "$GH_DIR" in
  *'!'*|*'^'*) f "Ghidra 路径含 ! 或 ^（${GH_DIR}），analyzeHeadless 无法启动，请改到纯字母数字路径" ;;
  *) [ -n "$GH_DIR" ] && p "Ghidra 路径无特殊字符风险" ;;
esac

AVAIL_KB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
if [ -n "$AVAIL_KB" ]; then
  AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
  if [ "$AVAIL_GB" -ge 5 ]; then p "磁盘可用空间约 ${AVAIL_GB}GB"
  else w "磁盘可用空间仅约 ${AVAIL_GB}GB（Ghidra 解压+JDK 约需 2GB，arm64 自建另需构建空间）"; fi
fi

if [ -n "${GHIDRA_HEADLESS_MAXMEM:-}" ]; then
  p "GHIDRA_HEADLESS_MAXMEM=${GHIDRA_HEADLESS_MAXMEM}（自定义堆内存）"
else
  w "GHIDRA_HEADLESS_MAXMEM 未设置（默认 2G；低内存机器可设 512M）"
fi

hr
printf ' 自检结果：%b%d 通过%b / %b%d 警告%b / %b%d 失败%b\n' \
  "$C_GREEN" "$PASS_COUNT" "$C_RESET" \
  "$C_YELLOW" "$WARN_COUNT" "$C_RESET" \
  "$C_RED" "$FAIL_COUNT" "$C_RESET"
echo '============================================================'
[ "$FAIL_COUNT" -eq 0 ] || exit 1

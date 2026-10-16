#!/usr/bin/env bash
# =============================================================================
# REA + Ghidra 一键部署脚本（macOS：Intel x86_64 / Apple Silicon arm64）
#
# 作用：安装 Temurin JDK 21 + Ghidra +（可选）便携 Node 24.22.0，解除 Gatekeeper
#       隔离，并在官方未预编译时从源码构建 native decompiler。
# 适用环境：Mac 物理机、Apple Silicon 虚拟机（仅 arm64 guest）、云 Mac（CI）。
# 特点：无需 root、无需 Homebrew（tar.gz 解压到 ~/tools）、幂等。
# 用法：bash install-macos.sh
#   可覆盖：TOOLS_DIR=... SKIP_NODE=1 bash install-macos.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/checksums.sh
source "$SCRIPT_DIR/lib/checksums.sh"

# ---- 命令行参数解析（在 load_versions 与平台专属动作之前）-------------------
INSTALLER_NAME="install-macos.sh"
parse_install_args "$@"
if [ "$ARG_HELP" = "1" ]; then install_usage "$INSTALLER_NAME"; exit 0; fi

load_versions
print_dry_run_if_requested "macOS"   # dry-run/--help 在任意机器都提前退出，不触碰 Darwin 专属命令

# v4.1：平台/架构环境不匹配 → RC_UPSTREAM(12)（环境问题，非参数错误）
[ "$(uname -s)" = "Darwin" ] || fatal "$RC_UPSTREAM" "本脚本仅用于 macOS（Linux 请用 install.sh）"

# ---- 可调参数（命令行/环境变量已在 args.sh 设好，这里补默认值）---------------
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
SKIP_NODE="${SKIP_NODE:-0}"
SKIP_NATIVE="${SKIP_NATIVE:-0}"
ARCH="$(normalize_arch)"
case "$ARCH" in
  x64)     JDK_ARCH=x64 ;;
  aarch64) JDK_ARCH=aarch64 ;;
  *) fatal "$RC_UPSTREAM" "不支持的 CPU 架构：$ARCH" ;;
esac
JDK_API="$(adoptium_jdk_url mac "$JDK_ARCH")"
JDK_PKG="jdk21-mac-${JDK_ARCH}.tar.gz"
GHIDRA_URL="$(ghidra_release_url)"
NATIVE_OS_DIR="mac_x86_64"; [ "$ARCH" = "aarch64" ] && NATIVE_OS_DIR="mac_arm_64"

echo "=========================================================="
echo " REA + Ghidra 部署（macOS）"
echo " 架构   : ${ARCH}（$([ "$ARCH" = aarch64 ] && echo 'Apple Silicon' || echo 'Intel')）"
echo " 目录   : $TOOLS_DIR"
echo " Ghidra : $GHIDRA_VERSION ｜ JDK: $JDK_FEATURE ｜ Node: $REA_NODE_VERSION ｜ REA: $REA_VERSION"
echo "=========================================================="

# ---- 前置检查（v4.1：缺本地依赖 → RC_DEPENDENCY 10）--------------------------
command -v curl >/dev/null 2>&1 || fatal "$RC_DEPENDENCY" "缺少 curl"
command -v unzip >/dev/null 2>&1 || fatal "$RC_DEPENDENCY" "缺少 unzip"
mkdir -p "$TOOLS_DIR"
# v4.2：安装原子锁——防止并发安装写同一 TOOLS_DIR；死锁自动接管
acquire_install_lock "$TOOLS_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"; release_install_lock' EXIT

# ---- 磁盘空间（粗略检查）----------------------------------------------------
TOOLS_NEED_KB=3000000
avail_kb="$(df -Pk "$TOOLS_DIR" | awk 'NR==2{print $4}')"
if [[ "${avail_kb:-0}" -lt "$TOOLS_NEED_KB" ]]; then
  fatal "$RC_DISK" "$TOOLS_DIR 可用空间不足（需约 3GB，当前约 $((avail_kb/1024/1024))GB）"
fi

# ---- 1. 安装 JDK 21（macOS tar.gz 解包后为 <bundle>/Contents/Home）----------
JDK_HOME="$(find "$TOOLS_DIR" -maxdepth 3 -type d -path '*/Contents/Home' -name 'Home' 2>/dev/null | grep 'jdk-21' | head -1 || true)"
if [[ -n "$JDK_HOME" && -x "$JDK_HOME/bin/java" ]]; then
  echo "[1/5] JDK 21 已存在：$JDK_HOME"
else
  echo "[1/5] 下载 Temurin JDK 21（mac/${JDK_ARCH}）..."
  # v4.2：自愈——清理上次解压到一半的 jdk-21 bundle（缺 Contents/Home/bin/java）
  for d in "$TOOLS_DIR"/jdk-21*; do [ -e "$d" ] && self_heal_partial "$d" Contents/Home/bin/java; done
  # v4.1：fetch_artifact 1=校验和失败→11，2=下载失败→12（用 || rc=$? 捕获原始码）
  rc=0
  fetch_artifact jdk "$JDK_PKG" "$JDK_API" "$TMP_DIR/jdk21.tar.gz" || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 1 ] && fatal "$RC_CHECKSUM" "JDK 下载物校验和失败（${JDK_PKG}）"
    fatal "$RC_UPSTREAM" "JDK 下载失败（${JDK_API}）"
  fi
  tar -xzf "$TMP_DIR/jdk21.tar.gz" -C "$TOOLS_DIR"
  JDK_BUNDLE="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' -type d | head -1)"
  JDK_HOME="$JDK_BUNDLE/Contents/Home"
  # 解压后仍无 java 二进制 = 上游资源损坏/不完整 → RC_UPSTREAM(12)
  [ -x "$JDK_HOME/bin/java" ] || fatal "$RC_UPSTREAM" "JDK 解压后未找到 $JDK_HOME/bin/java（上游资源可能损坏）"
  ln -sfn "$JDK_HOME" "$TOOLS_DIR/jdk21"
  echo "      已安装：$JDK_HOME"
fi

# ---- 2. 安装 Node（满足 REA 要求；已满足则跳过）-----------------------------
NODE_HOME=""
if node_satisfies_rea; then
  echo "[2/5] Node 已满足 REA 要求：$(node --version)"
elif [ "$SKIP_NODE" = "1" ]; then
  echo "[2/5] SKIP_NODE=1，跳过便携 Node 安装（请自行确保 Node 22.19+/24.11+/26+）"
else
  # v4.0.4：文案不写死“下载”——install_node_portable 优先复用 TOOLS_DIR 下已有便携 Node（FIX-5）。
  echo "[2/5] 准备便携 Node ${REA_NODE_VERSION}（darwin/${ARCH}；已存在则复用，不重复下载）..."
  NODE_HOME="$(install_node_portable "$TOOLS_DIR" darwin "$ARCH")"
  echo "      已就绪：${NODE_HOME}（$("$NODE_HOME/bin/node" --version)）"
fi

# ---- 3. 安装 Ghidra ---------------------------------------------------------
GHIDRA_DIR="$TOOLS_DIR/$(ghidra_dir_name)"
if [[ -x "$GHIDRA_DIR/support/analyzeHeadless" ]]; then
  echo "[3/5] Ghidra $GHIDRA_VERSION 已存在：$GHIDRA_DIR"
else
  echo "[3/5] 下载 Ghidra $GHIDRA_VERSION ..."
  # v4.2：自愈——清理上次解压到一半的 Ghidra 目录（缺 analyzeHeadless 标志）
  self_heal_partial "$GHIDRA_DIR" support/analyzeHeadless
  rc=0
  fetch_artifact ghidra "$(ghidra_zip_name)" "$GHIDRA_URL" "$TMP_DIR/ghidra.zip" || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 1 ] && fatal "$RC_CHECKSUM" "Ghidra 下载物校验和失败（$(ghidra_zip_name)）"
    fatal "$RC_UPSTREAM" "Ghidra 下载失败（${GHIDRA_URL}）"
  fi
  unzip -q -o "$TMP_DIR/ghidra.zip" -d "$TOOLS_DIR"
  echo "      已安装：$GHIDRA_DIR"
fi

# ---- 3.5 解除 Gatekeeper 隔离（REA 不替你做，必须脚本处理）------------------
# 对整个 Ghidra 目录递归移除 com.apple.quarantine，避免 headless/native 被拦
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$GHIDRA_DIR" 2>/dev/null || true
  if [ -d "$JDK_HOME" ]; then
    # JDK_HOME 形如 <bundle>/Contents/Home，向上两级到 <bundle> 再去隔离
    xattr -dr com.apple.quarantine "$(dirname "$(dirname "$JDK_HOME")")" 2>/dev/null || true
  fi
  echo "      已解除 Gatekeeper 隔离（xattr）"
fi

# ---- 4. 确保 native decompiler（macOS 官方包常只带源码，需构建）-------------
NATIVE_BIN="$GHIDRA_DIR/Ghidra/Features/Decompiler/os/$NATIVE_OS_DIR/decompile"
if [ -x "$NATIVE_BIN" ]; then
  echo "[4/5] native decompiler 已就绪：$NATIVE_OS_DIR"
elif [ "$SKIP_NATIVE" = "1" ]; then
  echo "[4/5] SKIP_NATIVE=1，跳过 native decompiler 自动构建（如需：bash scripts/build-ghidra-native.sh）"
else
  echo "[4/5] 未发现 $NATIVE_OS_DIR native decompiler，从源码构建（需 Xcode 命令行工具）..."
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "      未检测到 Xcode 命令行工具，尝试触发安装（可能需要你在弹窗中确认）..."
    xcode-select --install 2>/dev/null || true
    echo "      请在完成 'xcode-select --install' 后重跑本脚本；bison 可用 Homebrew 安装（brew install bison）。" >&2
  fi
  if GHIDRA_INSTALL_DIR="$GHIDRA_DIR" bash "$SCRIPT_DIR/scripts/build-ghidra-native.sh"; then
    echo "      native decompiler 构建完成"
  else
    rc=$?
    echo "      [警告] native decompiler 未就绪（退出码 ${rc}）。请安装 Xcode CLT（xcode-select --install）" >&2
    echo "      后手动运行：bash scripts/build-ghidra-native.sh" >&2
  fi
fi

# ---- 5. 配置环境变量（zsh 为主，兼容 bash）----------------------------------
# v3.0：原子维护 current-ghidra / current-jdk 软链（BSD ln 支持 -sfn）
ln -sfn "$GHIDRA_DIR" "$TOOLS_DIR/current-ghidra"
ln -sfn "$JDK_HOME"   "$TOOLS_DIR/current-jdk"
echo "      current 软链已指向：$(basename "$GHIDRA_DIR") / $(basename "$JDK_HOME")"
BLOCK_START="# >>> REA + Ghidra env >>>"
BLOCK_END="# <<< REA + Ghidra env <<<"
EXTRA_PATH=""; [ -n "$NODE_HOME" ] && EXTRA_PATH=":$NODE_HOME/bin"
# v4.0.5（D1）：与 install.sh 同款缺陷——路径加引号，\$PATH 转义保持原样。
ENV_BLOCK="$(cat <<EOF
$BLOCK_START
export JAVA_HOME="$JDK_HOME"
export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
export PATH="$JDK_HOME/bin:$GHIDRA_DIR/support${EXTRA_PATH}:\$PATH"
$BLOCK_END
EOF
)"
update_rc() {
  local rc="$1"
  touch "$rc"
  if grep -qF "$BLOCK_START" "$rc" 2>/dev/null; then
    awk -v s="$BLOCK_START" -v e="$BLOCK_END" \
      '$0==s{skip=1;next} $0==e{skip=0;next} !skip{print}' \
      "$rc" > "$TMP_DIR/rc.new"
    printf '%s\n' "$ENV_BLOCK" >> "$TMP_DIR/rc.new"
    mv "$TMP_DIR/rc.new" "$rc"
  else
    printf '\n%s\n' "$ENV_BLOCK" >> "$rc"
  fi
  echo "      已同步：$rc"
}
echo "[5/5] 写入环境变量 ..."
update_rc "$HOME/.zshrc"                                   # Catalina 起默认 zsh
touch "$HOME/.bash_profile"; update_rc "$HOME/.bash_profile"   # 兼容 bash 用户

# GitHub Actions：写 GITHUB_ENV / GITHUB_PATH
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "JAVA_HOME=$JDK_HOME" >> "$GITHUB_ENV"
  echo "GHIDRA_INSTALL_DIR=$GHIDRA_DIR" >> "$GITHUB_ENV"
fi
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$JDK_HOME/bin" >> "$GITHUB_PATH"
  echo "$GHIDRA_DIR/support" >> "$GITHUB_PATH"
  [ -n "$NODE_HOME" ] && echo "$NODE_HOME/bin" >> "$GITHUB_PATH"
fi

# ---- 验证 -------------------------------------------------------------------
echo
echo "== 验证 =="
export JAVA_HOME="$JDK_HOME"
export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
[ -n "$NODE_HOME" ] && export PATH="$NODE_HOME/bin:$PATH"
"$JDK_HOME/bin/java" -version 2>&1 | head -1
test -x "$GHIDRA_DIR/support/analyzeHeadless" && echo "Ghidra headless：OK"
if [ -x "$NATIVE_BIN" ]; then echo "native decompiler（${NATIVE_OS_DIR}）：OK"; else
  echo "native decompiler：缺失（请运行 scripts/build-ghidra-native.sh）"; fi

if command -v npx >/dev/null 2>&1 || [ -n "$NODE_HOME" ]; then
  echo
  echo "REA 就绪检查："
  if [ "$(rea_mode)" = "cn" ]; then export npm_config_registry="https://registry.npmmirror.com"; fi
  ( [ -n "$NODE_HOME" ] && export PATH="$NODE_HOME/bin:$PATH"; npx -y "rea-agents@${REA_VERSION}" doctor --provider ghidra 2>/dev/null) || true
  echo "如需全局安装：npm install --global --omit=optional rea-agents"
  echo "  （--omit=optional 跳过 frida 等可选依赖：静态反编译用不到，受限网络下可避免其 prebuild 失败触发极慢源码编译；需要动态插桩再自行全量安装）"
fi

echo
echo "============ 安装完成（macOS/${ARCH}）============"
echo "下一步："
echo "  1) source ~/.zshrc（bash 用户：source ~/.bash_profile）"
echo "  2) 自检：bash verify-macos.sh   诊断：bash scripts/doctor.sh"
if [ "$(rea_mode)" = "cn" ]; then
  echo "  （当前镜像模式=cn；海外/CI 可用 REA_MIRROR=global 走官方）"
fi
echo "  3) 把 REA 接到 MCP 客户端（先预览再确认）：bash scripts/mcp-setup.sh --list"
echo "     bash scripts/mcp-setup.sh --client claude-desktop --yes   （或 --dry-run 预览；--check 自检）"

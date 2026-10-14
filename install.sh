#!/usr/bin/env bash
# =============================================================================
# REA + Ghidra 一键部署脚本（Linux：x86_64 完整支持 / arm64 需自建 native）
#
# 作用：在本机安装 Temurin JDK 21 + Ghidra +（可选）便携 Node 22，并配置 REA
#       环境变量；arm64 上自动从源码构建 Ghidra native decompiler。
# 适用环境：物理本机、虚拟机、WSL2、ChromeOS Crostini、云电脑（VDI）——同一套
#           Linux 流程，仅在启动时打印检测到的环境。
# 特点：无需 root、幂等（可重复运行）、文件装在 $HOME/tools。
# 用法：bash install.sh
#   可覆盖：TOOLS_DIR=... SKIP_NODE=1 GHIDRA_VERSION=... bash install.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_versions   # 从 config/versions.env 载入默认版本；已 export 的同名变量优先

# ---- 可调参数 ---------------------------------------------------------------
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
SKIP_NODE="${SKIP_NODE:-0}"     # 设为 1 则不安装便携 Node（使用系统/已有 Node）
ARCH="$(normalize_arch)"
case "$ARCH" in
  x64)     JDK_ARCH=x64 ;;
  aarch64) JDK_ARCH=aarch64 ;;
  *) echo "不支持的 CPU 架构：$ARCH（仅支持 x86_64 / aarch64）" >&2; exit 1 ;;
esac
GHIDRA_URL="$(ghidra_release_url)"
JDK_API="$(adoptium_jdk_url linux "$JDK_ARCH")"

# ---- 运行环境识别（信息性，不影响安装）--------------------------------------
detect_environment() {
  local where="物理本机"
  if is_wsl; then
    where="WSL2（Windows 上的 Linux 子系统）"
  elif is_crostini; then
    where="ChromeOS Crostini（Linux 开发环境）"
  elif command -v systemd-detect-virt >/dev/null 2>&1; then
    local v
    v="$(systemd-detect-virt 2>/dev/null || echo none)"
    case "$v" in
      none) where="物理本机" ;;
      *)    where="虚拟机/容器（$v）" ;;
    esac
  fi
  echo "$where"
}
ENV_NAME="$(detect_environment)"
. /etc/os-release 2>/dev/null || true
echo "=========================================================="
echo " REA + Ghidra 部署（Linux）"
echo " 系统   : ${PRETTY_NAME:-未知}"
echo " 环境   : $ENV_NAME"
echo " 架构   : $ARCH"
echo " 目录   : $TOOLS_DIR"
echo " Ghidra : $GHIDRA_VERSION ｜ JDK: $JDK_FEATURE ｜ Node: $REA_NODE_VERSION ｜ REA: $REA_VERSION"
echo "=========================================================="

# ---- 前置检查 ---------------------------------------------------------------
command -v curl >/dev/null 2>&1 || { echo "缺少 curl，请先安装" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "缺少 unzip，请先安装（apt install unzip）" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "缺少 tar，请先安装" >&2; exit 1; }

mkdir -p "$TOOLS_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---- 磁盘空间检查 -----------------------------------------------------------
TOOLS_NEED_KB=2700000   # TOOLS_DIR 约需 2.6GB
TMP_NEED_KB=800000      # 临时目录约需 0.8GB
avail_kb="$(df -P "$TOOLS_DIR" | awk 'NR==2{print $4}')"
if [[ "${avail_kb:-0}" -lt "$TOOLS_NEED_KB" ]]; then
  echo "$TOOLS_DIR 可用空间不足（需约 2.6GB，当前约 $((avail_kb/1024/1024))GB）" >&2
  exit 1
fi
tmp_kb="$(df -P "$TMP_DIR" | awk 'NR==2{print $4}')"
if [[ "${tmp_kb:-0}" -lt "$TMP_NEED_KB" ]]; then
  echo "临时目录 $TMP_DIR 可用空间不足（需约 0.8GB）" >&2
  exit 1
fi

# ---- 1. 安装 JDK 21 ---------------------------------------------------------
JDK_DIR="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' 2>/dev/null | head -1 || true)"
if [[ -n "$JDK_DIR" && -x "$JDK_DIR/bin/java" ]]; then
  echo "[1/5] JDK 21 已存在：$JDK_DIR"
else
  echo "[1/5] 下载 Temurin JDK 21（$JDK_ARCH）..."
  curl -fSL "$JDK_API" -o "$TMP_DIR/jdk21.tar.gz"
  tar -xzf "$TMP_DIR/jdk21.tar.gz" -C "$TOOLS_DIR"
  JDK_DIR="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' | head -1)"
  echo "      已安装：$JDK_DIR"
fi

# ---- 2. 安装 Node（满足 REA 版本要求；已满足则跳过）-------------------------
NODE_HOME=""
if node_satisfies_rea; then
  echo "[2/5] Node 已满足 REA 要求：$(node --version)"
elif [ "$SKIP_NODE" = "1" ]; then
  echo "[2/5] SKIP_NODE=1，跳过便携 Node 安装（请自行确保 Node 22.19+/24.11+/26+）"
else
  echo "[2/5] 未检测到满足要求的 Node，下载便携 Node $REA_NODE_VERSION（$ARCH）..."
  NODE_HOME="$(install_node_portable "$TOOLS_DIR" linux "$ARCH")"
  echo "      已安装：$NODE_HOME（$("$NODE_HOME/bin/node" --version)）"
fi

# ---- 3. 安装 Ghidra ---------------------------------------------------------
GHIDRA_DIR="$TOOLS_DIR/$(ghidra_dir_name)"
if [[ -x "$GHIDRA_DIR/support/analyzeHeadless" ]]; then
  echo "[3/5] Ghidra $GHIDRA_VERSION 已存在：$GHIDRA_DIR"
else
  echo "[3/5] 下载 Ghidra $GHIDRA_VERSION ..."
  curl -fSL "$GHIDRA_URL" -o "$TMP_DIR/ghidra.zip"
  unzip -q -o "$TMP_DIR/ghidra.zip" -d "$TOOLS_DIR"
  echo "      已安装：$GHIDRA_DIR"
fi

# ---- 4. 确保 native decompiler（x86_64 官方自带；arm64 从源码构建）----------
NATIVE_OS_DIR="linux_x86_64"; [ "$ARCH" = "aarch64" ] && NATIVE_OS_DIR="linux_arm_64"
NATIVE_BIN="$GHIDRA_DIR/Ghidra/Features/Decompiler/os/$NATIVE_OS_DIR/decompile"
if [ -x "$NATIVE_BIN" ]; then
  echo "[4/5] native decompiler 已就绪：$NATIVE_OS_DIR"
else
  echo "[4/5] 未发现 $NATIVE_OS_DIR native decompiler，尝试从源码构建 ..."
  if GHIDRA_INSTALL_DIR="$GHIDRA_DIR" bash "$SCRIPT_DIR/scripts/build-ghidra-native.sh"; then
    echo "      native decompiler 构建完成"
  else
    rc=$?
    echo "      [警告] native decompiler 未就绪（退出码 $rc）。Ghidra 已安装，但反编译" >&2
    echo "      引擎暂不可用；请装好 build-essential/bison 后手动运行：" >&2
    echo "        bash scripts/build-ghidra-native.sh" >&2
  fi
fi

# ---- 5. 配置环境变量（幂等写入 .bashrc / .zshrc；升级时同步最新路径）--------
BLOCK_START="# >>> REA + Ghidra env >>>"
BLOCK_END="# <<< REA + Ghidra env <<<"
EXTRA_PATH=""; [ -n "$NODE_HOME" ] && EXTRA_PATH=":$NODE_HOME/bin"
ENV_BLOCK="$(cat <<EOF
$BLOCK_START
export JAVA_HOME=$JDK_DIR
export GHIDRA_INSTALL_DIR=$GHIDRA_DIR
export PATH=$JDK_DIR/bin:$GHIDRA_DIR/support${EXTRA_PATH}:\$PATH
$BLOCK_END
EOF
)"
# 替换/追加标记块到指定 rc 文件（标记块之外的用户配置原样保留）
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
update_rc "$HOME/.bashrc"
# zsh 用户（存在 .zshrc 或装了 zsh）也写一份
if [ -f "$HOME/.zshrc" ] || command -v zsh >/dev/null 2>&1; then
  touch "$HOME/.zshrc"; update_rc "$HOME/.zshrc"
fi

# GitHub Actions：非交互步骤不读取 rc 文件，改写 GITHUB_ENV / GITHUB_PATH
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "JAVA_HOME=$JDK_DIR" >> "$GITHUB_ENV"
  echo "GHIDRA_INSTALL_DIR=$GHIDRA_DIR" >> "$GITHUB_ENV"
  echo "      已写入 GITHUB_ENV（供后续 CI 步骤）"
fi
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$JDK_DIR/bin" >> "$GITHUB_PATH"
  echo "$GHIDRA_DIR/support" >> "$GITHUB_PATH"
  [ -n "$NODE_HOME" ] && echo "$NODE_HOME/bin" >> "$GITHUB_PATH"
  echo "      已写入 GITHUB_PATH"
fi

# ---- 验证 -------------------------------------------------------------------
echo
echo "== 验证 =="
export JAVA_HOME="$JDK_DIR"
export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
[ -n "$NODE_HOME" ] && export PATH="$NODE_HOME/bin:$PATH"
"$JDK_DIR/bin/java" -version 2>&1 | head -1
test -x "$GHIDRA_DIR/support/analyzeHeadless" && echo "Ghidra headless：OK"
if [ -x "$NATIVE_BIN" ]; then
  echo "native decompiler（$NATIVE_OS_DIR）：OK"
else
  echo "native decompiler：缺失（请运行 scripts/build-ghidra-native.sh）"
fi

# ---- REA 就绪检查（无需安装，直接用 npx；装好 Node 时可直接体检）-----------
if command -v npx >/dev/null 2>&1 || [ -n "$NODE_HOME" ]; then
  echo
  echo "REA 就绪检查（直接用 npx 调用，无需安装）："
  ( [ -n "$NODE_HOME" ] && export PATH="$NODE_HOME/bin:$PATH"; npx -y "rea-agents@${REA_VERSION}" doctor --provider ghidra 2>/dev/null) || true
  echo
  echo "如需全局安装：npm install --global rea-agents"
fi

echo
echo "============ 安装完成（$ENV_NAME / $ARCH）============"
echo "请执行：source ~/.bashrc（zsh 用户：source ~/.zshrc）"
echo "自检：bash verify.sh"
echo "分析示例："
echo "  npx -y rea-agents@latest analyze <二进制路径> --provider ghidra --format json"

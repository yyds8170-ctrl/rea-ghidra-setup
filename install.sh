#!/usr/bin/env bash
# =============================================================================
# REA + Ghidra 一键部署脚本（Linux x86_64）
# 作用：在本机/云电脑安装 Temurin JDK 21 + Ghidra 12.1.x，并配置 REA 环境变量
# 特点：无需 root、幂等（可重复运行）、所有文件装在 $HOME/tools
# 用法：bash install.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
load_versions   # 从 config/versions.env 载入默认版本；已 export 的同名变量优先

# ---- 可调参数（可通过环境变量覆盖）-----------------------------------------
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
GHIDRA_URL="$(ghidra_release_url)"
JDK_API="$(adoptium_jdk_url linux x64)"

# ---- 前置检查 ---------------------------------------------------------------
ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "本脚本仅支持 x86_64，当前架构：$ARCH" >&2
  exit 1
fi
command -v curl >/dev/null || { echo "缺少 curl，请先安装" >&2; exit 1; }
command -v unzip >/dev/null || { echo "缺少 unzip，请先安装（apt install unzip）" >&2; exit 1; }

mkdir -p "$TOOLS_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---- 磁盘空间检查（Ghidra 解压约 1.5GB，JDK 约 0.3GB，安装包在临时目录）----
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
  echo "[1/4] JDK 21 已存在：$JDK_DIR"
else
  echo "[1/4] 下载 Temurin JDK 21 ..."
  curl -fSL "$JDK_API" -o "$TMP_DIR/jdk21.tar.gz"
  tar -xzf "$TMP_DIR/jdk21.tar.gz" -C "$TOOLS_DIR"
  JDK_DIR="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' | head -1)"
  echo "      已安装：$JDK_DIR"
fi

# ---- 2. 安装 Ghidra ---------------------------------------------------------
GHIDRA_DIR="$TOOLS_DIR/ghidra_${GHIDRA_VERSION}_PUBLIC"
if [[ -x "$GHIDRA_DIR/support/analyzeHeadless" ]]; then
  echo "[2/4] Ghidra $GHIDRA_VERSION 已存在：$GHIDRA_DIR"
else
  echo "[2/4] 下载 Ghidra $GHIDRA_VERSION ..."
  curl -fSL "$GHIDRA_URL" -o "$TMP_DIR/ghidra.zip"
  unzip -q -o "$TMP_DIR/ghidra.zip" -d "$TOOLS_DIR"
  echo "      已安装：$GHIDRA_DIR"
fi

# ---- 3. 配置环境变量（幂等同步 ~/.bashrc；升级版本时自动更新为最新路径）-----
BLOCK_START="# >>> REA + Ghidra env >>>"
BLOCK_END="# <<< REA + Ghidra env <<<"
RC_FILE="$HOME/.bashrc"
ENV_BLOCK="$(cat <<EOF
$BLOCK_START
export JAVA_HOME=$JDK_DIR
export GHIDRA_INSTALL_DIR=$GHIDRA_DIR
export PATH=\$JAVA_HOME/bin:\$GHIDRA_INSTALL_DIR:\$PATH
$BLOCK_END
EOF
)"
touch "$RC_FILE"
if grep -qF "$BLOCK_START" "$RC_FILE" 2>/dev/null; then
  # 删除旧标记块后写入最新路径；标记块之外的用户配置原样保留
  awk -v s="$BLOCK_START" -v e="$BLOCK_END" \
    '$0==s{skip=1;next} $0==e{skip=0;next} !skip{print}' \
    "$RC_FILE" > "$TMP_DIR/bashrc.new"
  printf '%s\n' "$ENV_BLOCK" >> "$TMP_DIR/bashrc.new"
  mv "$TMP_DIR/bashrc.new" "$RC_FILE"
  echo "[3/4] 环境变量已在 $RC_FILE 中（同步为最新路径）"
else
  printf '\n%s\n' "$ENV_BLOCK" >> "$RC_FILE"
  echo "[3/4] 环境变量已写入 $RC_FILE"
fi

# GitHub Actions：非交互步骤不读取 .bashrc，改写 GITHUB_ENV / GITHUB_PATH 生效
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "JAVA_HOME=$JDK_DIR" >> "$GITHUB_ENV"
  echo "GHIDRA_INSTALL_DIR=$GHIDRA_DIR" >> "$GITHUB_ENV"
  echo "      已写入 GITHUB_ENV（供后续 CI 步骤）"
fi
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$JDK_DIR/bin" >> "$GITHUB_PATH"
  echo "      已写入 GITHUB_PATH（JDK 加入 PATH）"
fi

# ---- 4. 验证 ---------------------------------------------------------------
echo "[4/4] 验证 ..."
export JAVA_HOME="$JDK_DIR"
export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
"$JDK_DIR/bin/java" -version 2>&1 | head -1
test -x "$GHIDRA_DIR/support/analyzeHeadless" && echo "Ghidra headless：OK"

# ---- 可选：安装 REA（Node 22.19+ / 24.11+ / 26+）---------------------------
if command -v npx >/dev/null 2>&1; then
  echo
  echo "REA 就绪检查（无需安装，直接用 npx 调用）："
  npx -y rea-agents@latest doctor --provider ghidra 2>/dev/null || true
  echo
  echo "如需全局安装：npm install --global rea-agents"
fi

echo
echo "============ 安装完成 ============"
echo "请执行：source ~/.bashrc"
echo "分析示例："
echo "  npx -y rea-agents@latest analyze <二进制路径> --provider ghidra --format json"
echo "  npx -y rea-agents@latest decompile <二进制路径> --procedure <函数名> --provider ghidra"

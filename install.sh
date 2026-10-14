#!/usr/bin/env bash
# =============================================================================
# REA + Ghidra 一键部署脚本（Linux x86_64）
# 作用：在本机/云电脑安装 Temurin JDK 21 + Ghidra 12.1.x，并配置 REA 环境变量
# 特点：无需 root、幂等（可重复运行）、所有文件装在 $HOME/tools
# 用法：bash install.sh
# =============================================================================
set -euo pipefail

# ---- 可调参数（可通过环境变量覆盖）-----------------------------------------
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
GHIDRA_VERSION="${GHIDRA_VERSION:-12.1.4}"
GHIDRA_BUILD="${GHIDRA_BUILD:-Ghidra_12.1.4_build}"
GHIDRA_DATE="${GHIDRA_DATE:-20260921}"
GHIDRA_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_BUILD}/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip"
JDK_API="https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"

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

# ---- 1. 安装 JDK 21 ---------------------------------------------------------
JDK_DIR="$(ls -d "$TOOLS_DIR"/jdk-21* 2>/dev/null | head -1 || true)"
if [[ -n "$JDK_DIR" && -x "$JDK_DIR/bin/java" ]]; then
  echo "[1/4] JDK 21 已存在：$JDK_DIR"
else
  echo "[1/4] 下载 Temurin JDK 21 ..."
  curl -fSL "$JDK_API" -o "$TMP_DIR/jdk21.tar.gz"
  tar -xzf "$TMP_DIR/jdk21.tar.gz" -C "$TOOLS_DIR"
  JDK_DIR="$(ls -d "$TOOLS_DIR"/jdk-21* | head -1)"
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

# ---- 3. 配置环境变量（幂等写入 ~/.bashrc）-----------------------------------
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
if grep -qF "$BLOCK_START" "$RC_FILE" 2>/dev/null; then
  echo "[3/4] 环境变量已在 $RC_FILE 中（保持不变）"
else
  printf '\n%s\n' "$ENV_BLOCK" >> "$RC_FILE"
  echo "[3/4] 环境变量已写入 $RC_FILE"
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

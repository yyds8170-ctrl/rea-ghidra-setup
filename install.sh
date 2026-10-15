#!/usr/bin/env bash
# =============================================================================
# REA + Ghidra 一键部署脚本（Linux：x86_64 完整支持 / arm64 需自建 native）
#
# 作用：在本机安装 Temurin JDK 21 + Ghidra +（可选）便携 Node 24.22.0，并配置 REA
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
# shellcheck source=lib/checksums.sh
source "$SCRIPT_DIR/lib/checksums.sh"

# ---- 命令行参数解析（在 load_versions 与任何平台/下载动作之前）---------------
INSTALLER_NAME="install.sh"
parse_install_args "$@"
if [ "$ARG_HELP" = "1" ]; then install_usage "$INSTALLER_NAME"; exit 0; fi

load_versions   # 从 config/versions.env 载入默认版本；已 export 的同名变量优先
print_dry_run_if_requested "Linux"

# ---- 可调参数（命令行/环境变量已在 args.sh 设好，这里补默认值）---------------
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
SKIP_NODE="${SKIP_NODE:-0}"     # 设为 1 则不安装便携 Node（使用系统/已有 Node）
SKIP_NATIVE="${SKIP_NATIVE:-0}" # 设为 1 则跳过 native decompiler 自动构建
ARCH="$(normalize_arch)"
case "$ARCH" in
  x64)     JDK_ARCH=x64 ;;
  aarch64) JDK_ARCH=aarch64 ;;
  # v4.1：架构不受支持属于环境不匹配 → RC_UPSTREAM(12)（详见 docs/exit-codes.md）
  *) fatal "$RC_UPSTREAM" "不支持的 CPU 架构：${ARCH}（仅支持 x86_64 / aarch64）" ;;
esac
GHIDRA_URL="$(ghidra_release_url)"
JDK_API="$(adoptium_jdk_url linux "$JDK_ARCH")"
# 离线包内 JDK 的稳定文件名（prepare-offline.sh 一致）
JDK_PKG="jdk21-linux-${JDK_ARCH}.tar.gz"

# ---- 运行环境识别（信息性，不影响安装）--------------------------------------
ENV_NAME="$(env_label)"
. /etc/os-release 2>/dev/null || true
echo "=========================================================="
echo " REA + Ghidra 部署（Linux）"
echo " 系统   : ${PRETTY_NAME:-未知}"
echo " 环境   : $ENV_NAME"
echo " 架构   : $ARCH"
echo " 目录   : $TOOLS_DIR"
echo " Ghidra : $GHIDRA_VERSION ｜ JDK: $JDK_FEATURE ｜ Node: $REA_NODE_VERSION ｜ REA: $REA_VERSION"
echo "=========================================================="

# ---- 前置检查（v4.1：缺本地依赖 → RC_DEPENDENCY 10）--------------------------
command -v curl >/dev/null 2>&1 || fatal "$RC_DEPENDENCY" "缺少 curl，请先安装"
command -v unzip >/dev/null 2>&1 || fatal "$RC_DEPENDENCY" "缺少 unzip，请先安装（apt install unzip）"
command -v tar >/dev/null 2>&1 || fatal "$RC_DEPENDENCY" "缺少 tar，请先安装"

mkdir -p "$TOOLS_DIR"
# v4.3：WSL 下 /mnt/* 安装目录性能提示
warn_if_wsl_mnt "$TOOLS_DIR"
# v4.2：安装原子锁——防止两个 install 并发写同一 TOOLS_DIR；死锁（上次崩溃残留）自动接管
acquire_install_lock "$TOOLS_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"; release_install_lock' EXIT

# ---- 磁盘空间检查 -----------------------------------------------------------
TOOLS_NEED_KB=2700000   # TOOLS_DIR 约需 2.6GB
TMP_NEED_KB=800000      # 临时目录约需 0.8GB
avail_kb="$(df -P "$TOOLS_DIR" | awk 'NR==2{print $4}')"
if [[ "${avail_kb:-0}" -lt "$TOOLS_NEED_KB" ]]; then
  fatal "$RC_DISK" "$TOOLS_DIR 可用空间不足（需约 2.6GB，当前约 $((avail_kb/1024/1024))GB）"
fi
tmp_kb="$(df -P "$TMP_DIR" | awk 'NR==2{print $4}')"
if [[ "${tmp_kb:-0}" -lt "$TMP_NEED_KB" ]]; then
  fatal "$RC_DISK" "临时目录 $TMP_DIR 可用空间不足（需约 0.8GB）"
fi

# ---- 1. 安装 JDK 21 ---------------------------------------------------------
JDK_DIR="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' 2>/dev/null | head -1 || true)"
if [[ -n "$JDK_DIR" && -x "$JDK_DIR/bin/java" ]]; then
  echo "[1/5] JDK 21 已存在：$JDK_DIR"
else
  echo "[1/5] 下载 Temurin JDK 21（${JDK_ARCH}）..."
  # v4.2：自愈——清理上次解压到一半的 jdk-21 目录（缺 bin/java 标志）
  for d in "$TOOLS_DIR"/jdk-21*; do [ -e "$d" ] && self_heal_partial "$d" bin/java; done
  # v4.1：fetch_artifact 1=校验和失败→11，2=下载失败→12（用 || rc=$? 捕获原始码）
  rc=0
  fetch_artifact jdk "$JDK_PKG" "$JDK_API" "$TMP_DIR/jdk21.tar.gz" || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 1 ] && fatal "$RC_CHECKSUM" "JDK 下载物校验和失败（${JDK_PKG}）"
    fatal "$RC_UPSTREAM" "JDK 下载失败（${JDK_API}）"
  fi
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
  # v4.0.4：文案不写死“下载”——install_node_portable 内部会优先复用 TOOLS_DIR 下
  # 已满足 REA 的便携 Node（FIX-5 幂等），实际下载/复用由它打 stderr 日志说明。
  echo "[2/5] 准备便携 Node ${REA_NODE_VERSION}（${ARCH}；已存在则复用，不重复下载）..."
  NODE_HOME="$(install_node_portable "$TOOLS_DIR" linux "$ARCH")"
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

# ---- 4. 确保 native decompiler（x86_64 官方自带；arm64 从源码构建）----------
NATIVE_OS_DIR="linux_x86_64"; [ "$ARCH" = "aarch64" ] && NATIVE_OS_DIR="linux_arm_64"
NATIVE_BIN="$GHIDRA_DIR/Ghidra/Features/Decompiler/os/$NATIVE_OS_DIR/decompile"
if [ -x "$NATIVE_BIN" ]; then
  echo "[4/5] native decompiler 已就绪：$NATIVE_OS_DIR"
elif [ "$SKIP_NATIVE" = "1" ]; then
  echo "[4/5] SKIP_NATIVE=1，跳过 native decompiler 自动构建（如需：bash scripts/build-ghidra-native.sh）"
else
  echo "[4/5] 未发现 $NATIVE_OS_DIR native decompiler，尝试从源码构建 ..."
  if GHIDRA_INSTALL_DIR="$GHIDRA_DIR" bash "$SCRIPT_DIR/scripts/build-ghidra-native.sh"; then
    echo "      native decompiler 构建完成"
  else
    rc=$?
    echo "      [警告] native decompiler 未就绪（退出码 ${rc}）。Ghidra 已安装，但反编译" >&2
    echo "      引擎暂不可用；请装好 build-essential/bison 后手动运行：" >&2
    echo "        bash scripts/build-ghidra-native.sh" >&2
  fi
fi

# ---- 5. 配置环境变量（幂等写入 .bashrc / .zshrc；升级时同步最新路径）--------
# v3.0：原子维护 current-ghidra / current-jdk 软链（发现逻辑优先读 current）
ln -sfn "$GHIDRA_DIR" "$TOOLS_DIR/current-ghidra"
ln -sfn "$JDK_DIR"    "$TOOLS_DIR/current-jdk"
echo "      current 软链已指向：$(basename "$GHIDRA_DIR") / $(basename "$JDK_DIR")"
BLOCK_START="# >>> REA + Ghidra env >>>"
BLOCK_END="# <<< REA + Ghidra env <<<"
EXTRA_PATH=""; [ -n "$NODE_HOME" ] && EXTRA_PATH=":$NODE_HOME/bin"
# v4.0.5（D1）：路径必须用引号包裹——TOOLS_DIR 含空格/中文时，未加引号的
# JAVA_HOME 等写法写入 .bashrc 后会被分词，PATH 也会在空格处断开。
# heredoc 里末尾 PATH 前的反斜杠转义保持原样，输出为字面量，不展开当前 shell 变量。
ENV_BLOCK="$(cat <<EOF
$BLOCK_START
export JAVA_HOME="$JDK_DIR"
export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
export PATH="$JDK_DIR/bin:$GHIDRA_DIR/support${EXTRA_PATH}:\$PATH"
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
  echo "native decompiler（${NATIVE_OS_DIR}）：OK"
else
  echo "native decompiler：缺失（请运行 scripts/build-ghidra-native.sh）"
fi

# ---- REA 就绪检查（无需安装，直接用 npx；装好 Node 时可直接体检）-----------
if command -v npx >/dev/null 2>&1 || [ -n "$NODE_HOME" ]; then
  echo
  echo "REA 就绪检查（直接用 npx 调用，无需安装）："
  if [ "$(rea_mode)" = "cn" ]; then export npm_config_registry="https://registry.npmmirror.com"; fi
  ( [ -n "$NODE_HOME" ] && export PATH="$NODE_HOME/bin:$PATH"; npx -y "rea-agents@${REA_VERSION}" doctor --provider ghidra 2>/dev/null) || true
  echo
  echo "如需全局安装：npm install --global rea-agents"
fi

echo
echo "============ 安装完成（$ENV_NAME / ${ARCH}）============"
echo "下一步："
echo "  1) source ~/.bashrc（zsh 用户：source ~/.zshrc）"
echo "  2) 自检：bash verify.sh      诊断：bash scripts/doctor.sh"
if [ "$(rea_mode)" = "cn" ]; then
  echo "  （当前镜像模式=cn；海外/CI 可用 REA_MIRROR=global 走官方）"
fi
echo "  3) 把 REA 接到 MCP 客户端（Claude Desktop / Cursor 等，先预览再确认）："
echo "     bash scripts/mcp-setup.sh --list"
echo "     bash scripts/mcp-setup.sh --dry-run --client claude-desktop"
echo "     bash scripts/mcp-setup.sh --client claude-desktop --yes"
echo "     bash scripts/mcp-setup.sh --check        # 连接自检"
echo "  4) 分析示例："
echo "     npx -y rea-agents@latest analyze <二进制路径> --provider ghidra --format json"

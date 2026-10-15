#!/usr/bin/env bash
# =============================================================================
# lib/args.sh — 三平台 bash 安装器共享的命令行参数解析（install.sh / install-macos.sh）
#
# 只被 source（由 common.sh 引入）。约定调用顺序：
#   source common.sh          # 提供 normalize_arch / env_label / rea_mode 等
#   parse_install_args "$@"   # 解析参数；--help 直接退出；未知参数退出 2
#   load_versions             # 此时已 export 的版本覆盖优先生效
#   print_dry_run_if_requested "Linux"   # --dry-run 在此打印并退出（不做任何动作）
#   ... 正式安装 ...
#
# 这样 --help/--dry-run 在任意机器（含 CI 的 ubuntu 上跑 install-macos.sh、
# 或 mac 上跑 install.sh）都能在触碰平台专属命令之前提前退出。
#
# 兼容 macOS 自带 bash 3.2（普通索引/位置参数，无关联数组/mapfile/|&）。
#
# shellcheck disable=SC2034  # ARG_HELP/ARG_DRY_RUN 等开关由调用脚本 install.sh 读取，单文件检查看不到
# =============================================================================

# ---- 解析后的全局开关（默认值与历史环境变量一致，保持默认行为不变）-----------
ARG_HELP=0
ARG_DRY_RUN=0
ARG_YES=0
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
SKIP_NODE="${SKIP_NODE:-0}"
SKIP_NATIVE="${SKIP_NATIVE:-0}"            # v2.5 新增：跳过 native decompiler 自动构建
REA_ANALYSIS_PROVIDER="${REA_ANALYSIS_PROVIDER:-}"
OFFLINE_DIR="${OFFLINE_DIR:-}"

# 打印用法（$1=安装脚本名，如 install.sh / install-macos.sh）
install_usage() {
  local me="${1:-install.sh}"
  cat <<EOF
用法：bash $me [选项]

非交互参数化安装（默认不带任何参数时行为与历史一致）。

选项：
  -h, --help                    打印本用法并退出
      --dry-run                 只解析并打印「将要执行的安装计划」，不下载/解压/写 rc
  -y, --yes, --non-interactive  显式声明非交互（不阻塞；当前安装本就无交互）
      --prefix <dir>            安装根目录（同 --tools-dir）
      --tools-dir <dir>
      --mirror <auto|cn|global> 镜像模式（默认 auto：短探测官方可达性）
      --skip-node               不安装便携 Node（使用系统/已有 Node）
      --no-native               跳过 native decompiler 自动源码构建
      --provider <名>           设置 REA_ANALYSIS_PROVIDER（如 ghidra）
      --offline-dir <dir>      离线包目录（OFFLINE_DIR）
      --ghidra-version <ver>    覆盖 Ghidra 版本（需配套 build/date，可用环境变量另设）
      --node-version <ver>      覆盖便携 Node 版本
      --rea-version <ver>       覆盖 rea-agents 版本

示例：
  bash $me                                  # 默认（幂等可重复）
  bash $me --dry-run --mirror cn            # 预览国内镜像安装计划
  REA_MIRROR=cn bash $me -y --prefix \$HOME/tools
  bash $me --yes --skip-node --no-native
EOF
}

# 解析命令行参数。--help 打印并退出 0；未知参数打印用法到 stderr 并退出 2。
parse_install_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) ARG_HELP=1; shift ;;
      --dry-run) ARG_DRY_RUN=1; shift ;;
      -y|--yes|--non-interactive) ARG_YES=1; shift ;;
      --prefix|--tools-dir)
        [ $# -ge 2 ] || { install_usage "$INSTALLER_NAME" >&2; fatal "$RC_USAGE" "错误：$1 需要一个目录参数"; }
        TOOLS_DIR="$2"; shift 2 ;;
      --mirror)
        [ $# -ge 2 ] || fatal "$RC_USAGE" "错误：$1 需要 auto|cn|global"
        case "$2" in auto|cn|global) export REA_MIRROR="$2"; shift 2 ;; *) fatal "$RC_USAGE" "错误：--mirror 仅接受 auto|cn|global" ;; esac ;;
      --skip-node) SKIP_NODE=1; shift ;;
      --no-native) SKIP_NATIVE=1; shift ;;
      --provider)
        [ $# -ge 2 ] || fatal "$RC_USAGE" "错误：$1 需要一个名字"
        REA_ANALYSIS_PROVIDER="$2"; export REA_ANALYSIS_PROVIDER; shift 2 ;;
      --offline-dir)
        [ $# -ge 2 ] || fatal "$RC_USAGE" "错误：$1 需要一个目录"
        OFFLINE_DIR="$2"; export OFFLINE_DIR; shift 2 ;;
      --ghidra-version)
        [ $# -ge 2 ] || fatal "$RC_USAGE" "错误：$1 需要一个版本号"
        export GHIDRA_VERSION="$2"; shift 2 ;;
      --node-version)
        [ $# -ge 2 ] || fatal "$RC_USAGE" "错误：$1 需要一个版本号"
        export REA_NODE_VERSION="$2"; shift 2 ;;
      --rea-version)
        [ $# -ge 2 ] || fatal "$RC_USAGE" "错误：$1 需要一个版本号"
        export REA_VERSION="$2"; shift 2 ;;
      *)
        install_usage "$INSTALLER_NAME" >&2
        fatal "$RC_USAGE" "错误：未知参数：$1" ;;
    esac
  done
}

# 打印 dry-run 计划并退出 0（不做任何下载/解压/写 rc/构建）。
# $1=平台标签（Linux / macOS）。需在 load_versions 之后调用（要拿到版本号）。
print_dry_run_if_requested() {
  [ "$ARG_DRY_RUN" = "1" ] || return 0
  local platform="${1:-Linux}"
  local arch mode offline skip_native prov
  arch="$(normalize_arch 2>/dev/null || echo unknown)"
  mode="$(rea_mode 2>/dev/null || echo auto)"
  [ -n "$OFFLINE_DIR" ] && offline="是（${OFFLINE_DIR}）" || offline="否"
  [ "$SKIP_NATIVE" = "1" ] && skip_native="是" || skip_native="否"
  if [ -n "$REA_ANALYSIS_PROVIDER" ]; then prov="$REA_ANALYSIS_PROVIDER"; else prov="(自动选择)"; fi
  echo "========== Dry-run：将要执行的安装计划（不会做任何改动）=========="
  echo "  平台/环境   : $platform / $(env_label 2>/dev/null || echo unknown)"
  echo "  架构        : $arch"
  echo "  镜像模式    : $(printf '%s' "${REA_MIRROR:-auto}") → 有效 = $mode"
  echo "  安装目录    : $TOOLS_DIR"
  echo "  组件版本    : Ghidra $GHIDRA_VERSION ｜ JDK $JDK_FEATURE ｜ Node $REA_NODE_VERSION ｜ REA $REA_VERSION"
  echo "  provider    : $prov"
  echo "  离线包      : $offline"
  echo "  跳过 Node   : $([ "$SKIP_NODE" = "1" ] && echo 是 || echo 否)"
  echo "  跳过 native : $skip_native"
  echo "  非交互      : $([ "$ARG_YES" = "1" ] && echo 是 || echo 否)"
  echo "  预计磁盘    : 约 2.6GB（TOOLS_DIR）+ 0.8GB（临时目录）"
  echo "  步骤预览    : [1]JDK [2]Node [3]Ghidra [4]native [5]写环境变量 → verify/doctor"
  echo "=================================================================="
  exit 0
}

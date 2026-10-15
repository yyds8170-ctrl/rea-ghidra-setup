#!/usr/bin/env bash
# =============================================================================
# ghidra-export.sh — 用 Ghidra 原生 analyzeHeadless 把二进制静态分析导出为机器可读产物
#
# 不依赖 REA / Node / npm。产物：functions/strings/symbols/calls/decompiled 的 JSON。
#
# 用法：
#   scripts/ghidra-export.sh <二进制> [--out DIR] [--kind functions|strings|symbols|calls|decompiled|all]
#   scripts/ghidra-export.sh --help
#
# 示例：
#   scripts/ghidra-export.sh ./examples/demo --out /tmp/out --kind all
#   scripts/ghidra-export.sh ./examples/demo --kind functions
# END USAGE
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

# v4.0.5（D2）：目标用 bash 数组按 argv 原样累加（本工具语义为“单目标”，恰好允许
# 1 个二进制）。旧实现 BIN="${BIN} $1" 后 `echo "$BIN" | xargs` 会对路径重新分词、
# 折叠多空格——路径含空格/引号时静默损坏；数组按参数原样保留，零分词风险。
BIN_ARGS=()
OUT_DIR="./ghidra-export"
KIND="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      sed -n '2,/^# END USAGE/p' "$0" | sed 's/^# \?//; /^END USAGE$/d'; exit 0 ;;
    --out)  [ $# -ge 2 ] || fatal "$RC_USAGE" "--out 需要目录"; OUT_DIR="$2"; shift 2 ;;
    --kind) [ $# -ge 2 ] || fatal "$RC_USAGE" "--kind 需要类型"; KIND="$2"; shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do BIN_ARGS+=("$1"); shift; done ;;
    -*) fatal "$RC_USAGE" "未知参数：$1（见 --help）" ;;
    *)  BIN_ARGS+=("$1"); shift ;;
  esac
done
if [ "${#BIN_ARGS[@]}" -eq 0 ]; then
  fatal "$RC_USAGE" "缺少目标二进制（见 --help）"
elif [ "${#BIN_ARGS[@]}" -gt 1 ]; then
  fatal "$RC_USAGE" "仅支持单个目标二进制（当前传入 ${#BIN_ARGS[@]} 个：${BIN_ARGS[*]}）"
fi
BIN="${BIN_ARGS[0]}"
# v4.1：目标二进制不存在 = 资源不可用 → RC_UPSTREAM(12)
[ -f "$BIN" ] || fatal "$RC_UPSTREAM" "二进制不存在：$BIN"

case "$KIND" in
  functions)   SCRIPT="ExportFunctions.java" ;;
  strings)     SCRIPT="ExportStrings.java" ;;
  symbols)     SCRIPT="ExportSymbols.java" ;;
  calls)       SCRIPT="ExportCalls.java" ;;
  decompiled)  SCRIPT="ExportDecompiled.java" ;;
  all)         SCRIPT="ExportAll.java" ;;
  *) fatal "$RC_USAGE" "--kind 仅接受 functions|strings|symbols|calls|decompiled|all" ;;
esac

# ---- 定位 Ghidra / JDK（v3.0 集中发现：显式 env ＞ current 软链 ＞ 枚举）----
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
GHIDRA_INSTALL_DIR="$(resolve_ghidra_dir || true)"
if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]; then
  fatal "$RC_DEPENDENCY" "未找到 Ghidra（设 GHIDRA_INSTALL_DIR 或先跑 install.sh）"
fi

# 取某个 JAVA_HOME 的 major 版本（写 stdout；取不出输出 0）。Ghidra 12.1.4 要求 JDK21。
jdk_major() {
  local jh="$1"
  [ -x "$jh/bin/java" ] || { printf '0'; return; }
  local line v
  line="$("$jh/bin/java" -version 2>&1 | head -1)"
  # version 形如 openjdk version "21.0.2" 或 "1.8.0_..."
  v="$(printf '%s' "$line" | sed -n 's/.*version "\([0-9.]*\).*/\1/p')"
  case "$v" in
    1.*) printf '%s' "${v#1.}" | cut -d. -f1 ;;   # 1.8 -> 8
    *)   printf '%s' "$v" | cut -d. -f1 ;;
  esac
}

# CI runner 可能注入 JAVA_HOME=JDK17；集中发现：显式 env(major>=21) ＞ current-jdk ＞ 枚举
JH="$(resolve_jdk_home || true)"
if [ -z "$JH" ] || [ "$(jdk_major "$JH")" -lt 21 ]; then
  fatal "$RC_DEPENDENCY" "未找到 JDK21（要求 major>=21）。当前 JAVA_HOME=${JAVA_HOME:-（空）}；请先跑 install.sh 或设置 JAVA_HOME 指向 JDK21。"
fi
export JAVA_HOME="$JH"
export PATH="$JH/bin:$PATH"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
PROJ_DIR="$(mktemp -d)"
trap 'rm -rf "$PROJ_DIR"' EXIT

# v4.0.5（D2）：Ghidra analyzeHeadless 的 checkValidFilename 只放行 ASCII 白名单
# （A-Za-z0-9._-）作为“被导入文件的叶子名”，中文/空格/引号叶子名会抛
# InvalidInputException（目录段含中文/空格不受影响，实测可正常遍历）。这里把叶子名
# 不合法的目标逐字节复制到 ASCII 临时名再导入；批量缓存按原始文件 sha256，不受影响。
STAGE_BIN=""
trap 'rm -rf "$PROJ_DIR" ${STAGE_BIN:+"$STAGE_BIN"}' EXIT
BN="$(basename "$BIN")"
if ! printf '%s' "$BN" | LC_ALL=C grep -q '^[A-Za-z0-9._-]*$'; then
  STAGE_BIN="$(mktemp "${TMPDIR:-/tmp}/rea_import_XXXXXX")"
  cp "$BIN" "$STAGE_BIN"
  echo "  注意：叶子名含非 ASCII/特殊字符，已暂存为 ASCII 临时文件后导入"
fi
BIN_TO_IMPORT="$BIN"; [ -n "$STAGE_BIN" ] && BIN_TO_IMPORT="$STAGE_BIN"

# 跨平台超时：优先 timeout（GNU），其次 gtimeout（macOS coreutils），都没有则不套
run_headless() {
  local to="${REA_EXPORT_TIMEOUT:-1800}"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$to" "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$to" "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$@"
  else
    "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$@"
  fi
}

echo "导出：$BIN"
echo "  Ghidra=$GHIDRA_INSTALL_DIR  JAVA_HOME=${JAVA_HOME:-}(默认)  kind=$KIND"
echo "  产物目录：$OUT_DIR"

run_headless "$PROJ_DIR" Proj \
  -import "$BIN_TO_IMPORT" \
  -scriptPath "$SCRIPT_DIR/ghidra" \
  -postScript "$SCRIPT" "$OUT_DIR" \
  -deleteProject

echo "完成。产物："
for f in functions strings symbols calls decompiled; do
  p="$OUT_DIR/$f.json"
  if [ -f "$p" ]; then printf '  %-14s %s (%s bytes)\n' "$f.json" "$p" "$(wc -c < "$p" | tr -d ' ')"; fi
done

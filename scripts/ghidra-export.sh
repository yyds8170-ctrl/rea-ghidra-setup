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
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

BIN=""
OUT_DIR="./ghidra-export"
KIND="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
    --out)  [ $# -ge 2 ] || { echo "--out 需要目录" >&2; exit 2; }; OUT_DIR="$2"; shift 2 ;;
    --kind) [ $# -ge 2 ] || { echo "--kind 需要类型" >&2; exit 2; }; KIND="$2"; shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do BIN="${BIN} $1"; shift; done ;;
    -*) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
    *)  BIN="${BIN} $1"; shift ;;
  esac
done
BIN="$(echo "$BIN" | xargs)"
[ -n "$BIN" ] || { echo "缺少目标二进制（见 --help）" >&2; exit 2; }
[ -f "$BIN" ] || { echo "二进制不存在：$BIN" >&2; exit 2; }

case "$KIND" in
  functions)   SCRIPT="ExportFunctions.java" ;;
  strings)     SCRIPT="ExportStrings.java" ;;
  symbols)     SCRIPT="ExportSymbols.java" ;;
  calls)       SCRIPT="ExportCalls.java" ;;
  decompiled)  SCRIPT="ExportDecompiled.java" ;;
  all)         SCRIPT="ExportAll.java" ;;
  *) echo "--kind 仅接受 functions|strings|symbols|calls|decompiled|all" >&2; exit 2 ;;
esac

# ---- 定位 Ghidra / JDK（环境变量优先，其次 tools 目录）---------------------
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-$(find "$TOOLS_DIR" -maxdepth 1 -name 'ghidra_*_PUBLIC' 2>/dev/null | head -1 || true)}"
if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]; then
  die "未找到 Ghidra（设 GHIDRA_INSTALL_DIR 或先跑 install.sh）"
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

# CI runner 可能注入 JAVA_HOME=JDK17，盲目采用会被 analyzeHeadless 拒绝；
# 只有当现有 JAVA_HOME 的 major>=21 才采用，否则回退 tools 目录下的 jdk-21*。
JH=""
if [ -n "${JAVA_HOME:-}" ] && [ "$(jdk_major "${JAVA_HOME}")" -ge 21 ]; then
  JH="$JAVA_HOME"
fi
if [ -z "$JH" ]; then
  JH="$(find "$TOOLS_DIR" -maxdepth 1 -name 'jdk-21*' 2>/dev/null | head -1 || true)"
fi
if [ -z "$JH" ] || [ "$(jdk_major "$JH")" -lt 21 ]; then
  die "未找到 JDK21（要求 major>=21）。当前 JAVA_HOME=${JAVA_HOME:-（空）}；请先跑 install.sh 或设置 JAVA_HOME 指向 JDK21。"
fi
export JAVA_HOME="$JH"
export PATH="$JH/bin:$PATH"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
PROJ_DIR="$(mktemp -d)"
trap 'rm -rf "$PROJ_DIR"' EXIT

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
  -import "$BIN" \
  -scriptPath "$SCRIPT_DIR/ghidra" \
  -postScript "$SCRIPT" "$OUT_DIR" \
  -deleteProject

echo "完成。产物："
for f in functions strings symbols calls decompiled; do
  p="$OUT_DIR/$f.json"
  if [ -f "$p" ]; then printf '  %-14s %s (%s bytes)\n' "$f.json" "$p" "$(wc -c < "$p" | tr -d ' ')"; fi
done

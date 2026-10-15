#!/usr/bin/env bash
# =============================================================================
# ghidra-report.sh — 用 Ghidra 原生 analyzeHeadless 生成结构化静态分析报告
#
# 不依赖 REA / Node / npm。单次 headless 产出：
#   meta.json / functions.json / strings.json / symbols.json / calls.json
#   imports.json / exports.json / constants.json / xrefs.json / decompiled.json
#   report.md（结构化 Markdown）
#   report.html（自包含单文件 HTML，内联 CSS，无 CDN/JS，可离线分发）
#
# 用法：
#   scripts/ghidra-report.sh <二进制> [--out DIR] [--format md|html|both|json]
#   scripts/ghidra-report.sh --help
#
# 示例：
#   scripts/ghidra-report.sh ./examples/demo --out ./report-out
#   scripts/ghidra-report.sh ./examples/demo --out /tmp/r --format html
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

BIN=""
OUT_DIR="./report-out"
FORMAT="both"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
    --out)  [ $# -ge 2 ] || { echo "--out 需要目录" >&2; exit 2; }; OUT_DIR="$2"; shift 2 ;;
    --format)
      [ $# -ge 2 ] || { echo "--format 需要 md|html|both|json" >&2; exit 2; }
      case "$2" in md|html|both|json) FORMAT="$2" ;; *) echo "--format 仅支持 md|html|both|json" >&2; exit 2 ;; esac
      shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do BIN="${BIN} $1"; shift; done ;;
    -*) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
    *)  BIN="${BIN} $1"; shift ;;
  esac
done
BIN="$(echo "$BIN" | xargs)"
[ -n "$BIN" ] || { echo "缺少目标二进制（见 --help）" >&2; exit 2; }
[ -f "$BIN" ] || { echo "二进制不存在：$BIN" >&2; exit 2; }
BIN="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"
ORIG_BIN="$BIN"   # 原始路径，用于报告 meta；导入可能用 ASCII 临时副本
IMPORT_BIN="$BIN"

# ---- 定位 Ghidra / JDK（集中发现：显式 env ＞ current 软链 ＞ 枚举）----
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
GHIDRA_INSTALL_DIR="$(resolve_ghidra_dir || true)"
if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]; then
  die "未找到 Ghidra（设 GHIDRA_INSTALL_DIR 或先跑 install.sh）"
fi
JH="$(resolve_jdk_home || true)"
if [ -z "$JH" ] || [ "$(jdk_major_of "$JH")" -lt 21 ]; then
  die "未找到 JDK21（要求 major>=21）。请先跑 install.sh 或设置 JAVA_HOME 指向 JDK21。"
fi
export JAVA_HOME="$JH"
export PATH="$JH/bin:$PATH"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
PROJ_DIR="$(mktemp -d)"
trap 'rm -rf "$PROJ_DIR"' EXIT

# ---- 自愈：Ghidra headless 的 checkValidFilename 拒绝非 ASCII 文件名（目录可含非 ASCII）----
# 若目标文件名含非 ASCII 字符，复制为 ASCII 临时名再导入；报告仍记录原始路径。
ORIG_BASE="$(basename "$ORIG_BIN")"
if printf '%s' "$ORIG_BASE" | LC_ALL=C grep -qP '[^\x00-\x7F]'; then
  SAFE_DIR="$PROJ_DIR/safe"
  mkdir -p "$SAFE_DIR"
  SAFE_EXT=""
  case "$ORIG_BASE" in
    *.*) SAFE_EXT=".${ORIG_BASE##*.}" ;;
  esac
  IMPORT_BIN="$SAFE_DIR/target${SAFE_EXT}"
  cp -f "$ORIG_BIN" "$IMPORT_BIN"
  echo "  自愈：原文件名含非 ASCII 字符（Ghidra 不接受），已复制为 ASCII 临时名导入；报告中原路径不变。"
fi

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

echo "生成报告：$BIN"
echo "  Ghidra=$GHIDRA_INSTALL_DIR  JAVA_HOME=${JAVA_HOME:-}(默认)  format=$FORMAT"
echo "  产物目录：$OUT_DIR"

run_headless "$PROJ_DIR" Proj \
  -import "$IMPORT_BIN" \
  -overwrite \
  -scriptPath "$SCRIPT_DIR/ghidra" \
  -postScript ExportReport.java "$OUT_DIR" "$ORIG_BIN" \
  -deleteProject

echo "完成。报告与数据："
for f in report.md report.html meta.json functions.json strings.json calls.json imports.json exports.json constants.json xrefs.json symbols.json decompiled.json; do
  p="$OUT_DIR/$f"
  if [ -f "$p" ]; then printf '  %-17s %s (%s bytes)\n' "$f" "$p" "$(wc -c < "$p" | tr -d ' ')"; fi
done

# --format 仅控制“重点产物”的存在性提示；JSON 始终生成（报告依赖其数据）
case "$FORMAT" in
  md)
    [ -s "$OUT_DIR/report.md" ] || die "未生成 report.md"
    echo "报告（Markdown）：$OUT_DIR/report.md" ;;
  html)
    [ -s "$OUT_DIR/report.html" ] || die "未生成 report.html"
    echo "报告（HTML）：$OUT_DIR/report.html" ;;
  json)
    [ -s "$OUT_DIR/meta.json" ] || die "未生成数据"
    echo "数据目录：$OUT_DIR" ;;
  both)
    if [ ! -s "$OUT_DIR/report.md" ] || [ ! -s "$OUT_DIR/report.html" ]; then
      die "报告不完整"
    fi
    echo "报告：$OUT_DIR/report.md"
    echo "报告：$OUT_DIR/report.html" ;;
esac

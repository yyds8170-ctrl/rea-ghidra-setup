#!/usr/bin/env bash
# =============================================================================
# benchmark.sh — Ghidra headless 报告管线性能基准
#
# 做什么：
#   对同一目标重复运行 ghidra-report.sh（默认 3 次），测量每次的墙钟耗时，
#   并从 headless 日志里解析 Ghidra 自动分析阶段的 "Total Time"；
#   汇总 min / median / max，产出 benchmark.md 与 benchmark.json。
#
# 用法：
#   scripts/benchmark.sh [二进制] [--runs N] [--out DIR]
#   scripts/benchmark.sh --help
# 示例：
#   scripts/benchmark.sh examples/demo --runs 3 --out /tmp/bench
# 说明：
#   - 首次运行含 JVM/类加载冷启动，后续更快；建议 runs>=3 看中位数。
#   - 计时用 date +%s.%N（macOS 无 %N，回退秒级）。
# END USAGE
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

BIN="examples/demo"
RUNS=3
OUT_DIR="./benchmark"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) sed -n '2,/^# END USAGE/p' "$0" | sed 's/^# \?//; /^END USAGE$/d'; exit 0 ;;
    --runs) [ $# -ge 2 ] || { echo "--runs 需要数字" >&2; exit 2; }; RUNS="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || { echo "--out 需要目录" >&2; exit 2; }; OUT_DIR="$2"; shift 2 ;;
    -*) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
    *)  BIN="$1"; shift ;;
  esac
done
[ -f "$BIN" ] || { echo "目标不存在：$BIN" >&2; exit 2; }
case "$RUNS" in ''|*[!0-9]*) echo "--runs 需为正整数" >&2; exit 2 ;; esac
[ "$RUNS" -ge 1 ] || { echo "--runs 需 >=1" >&2; exit 2; }

# 计时原语：秒（带小数，平台不支持 %N 时退化为整数）
now_sec() {
  local t
  t="$(date +%s.%N 2>/dev/null || true)"
  case "$t" in *N|'') date +%s ;; *) printf '%s' "$t" ;; esac
}

# 解析 ghidra 日志里 "Total Time   N secs" 行的分析阶段秒数
parse_analysis_sec() {
  # 形如 "     Total Time   4 secs"
  awk '/Total Time/ { for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+(\.[0-9]+)?$/ && $(i+1)=="secs") { print $i; exit } }' "$1"
}

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
# 确保 Ghidra/JDK 可用（ghidra-report 会报错，这里提前触发同一套解析）
export JAVA_HOME
JAVA_HOME="$(resolve_jdk_home || true)"
[ -n "$JAVA_HOME" ] && export PATH="$JAVA_HOME/bin:$PATH"

WALLS=""
ANALYSIS=""
for i in $(seq 1 "$RUNS"); do
  RUN_OUT="$OUT_DIR/run-$i"
  RUN_LOG="$OUT_DIR/run-$i.log"
  rm -rf "$RUN_OUT"
  echo "==> 第 $i/$RUNS 次运行"
  t0="$(now_sec)"
  bash "$SCRIPT_DIR/ghidra-report.sh" "$BIN" --out "$RUN_OUT" --format json >"$RUN_LOG" 2>&1 \
    || { echo "第 $i 次运行失败，见 $RUN_LOG" >&2; exit 1; }
  t1="$(now_sec)"
  wall="$(awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.2f", b-a }')"
  ana="$(parse_analysis_sec "$RUN_LOG" || true)"
  [ -z "$ana" ] && ana="0"
  WALLS="${WALLS}${wall} "
  ANALYSIS="${ANALYSIS}${ana} "
  echo "    墙钟 ${wall}s，Ghidra 分析 ${ana}s"
done

# 计算 min/median/max（输入空格分隔的数）
stats() {
  # shellcheck disable=SC2086
  sorted="$(printf '%s\n' $1 | sort -n)"
  min="$(printf '%s\n' "$sorted" | head -1)"
  max="$(printf '%s\n' "$sorted" | tail -1)"
  n="$(printf '%s\n' "$sorted" | wc -l | tr -d ' ')"
  mid="$(( (n + 1) / 2 ))"
  median="$(printf '%s\n' "$sorted" | sed -n "${mid}p")"
  printf '%s %s %s' "$min" "$median" "$max"
}

read -r wmin wmed wmax <<EOF
$(stats "$WALLS")
EOF
read -r amin amed amax <<EOF
$(stats "$ANALYSIS")
EOF

# 汇总
{
  echo "# 性能基准 / Benchmark"
  echo
  echo "- 目标：\`$BIN\`"
  echo "- 运行次数：${RUNS}（每次全新临时工程、无缓存复用）"
  echo "- 时间：$(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "| 指标 | min | median | max | 单位 |"
  echo "|---|---|---|---|---|"
  echo "| 端到端墙钟（含 JVM 启动/导入/分析/导出） | $wmin | $wmed | $wmax | 秒 |"
  echo "| Ghidra 自动分析阶段（日志 Total Time） | $amin | $amed | $amax | 秒 |"
} > "$OUT_DIR/benchmark.md"

python3 -c '
import json,sys
d={"target":sys.argv[1],"runs":int(sys.argv[2]),
   "wall_sec":{"min":float(sys.argv[3]),"median":float(sys.argv[4]),"max":float(sys.argv[5])},
   "analysis_sec":{"min":float(sys.argv[6]),"median":float(sys.argv[7]),"max":float(sys.argv[8])}}
json.dump(d,open(sys.argv[9],"w",encoding="utf-8"),ensure_ascii=False,indent=2)
' "$BIN" "$RUNS" "$wmin" "$wmed" "$wmax" "$amin" "$amed" "$amax" "$OUT_DIR/benchmark.json"

echo
echo "汇总（墙钟秒）：min=$wmin median=$wmed max=$wmax"
echo "汇总（分析秒）：min=$amin median=$amed max=$amax"
echo "报告：$OUT_DIR/benchmark.md"

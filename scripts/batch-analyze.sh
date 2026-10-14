#!/usr/bin/env bash
# =============================================================================
# batch-analyze.sh — 批量并行 Ghidra 静态分析（在 v2.7 单目标导出之上编排）
#
# 不依赖 REA / Node。多目标并行、失败隔离、按 sha256 快照缓存、可断点续跑。
# 每个目标作为子进程调用 ghidra-export.sh（JDK21/Ghidra 自动发现逻辑复用）。
#
# 用法：
#   scripts/batch-analyze.sh <bin> [bin2 ...] [--dir DIR] [--recurse] [--pattern '*.elf']
#                            [--out DIR] [--kind all] [--jobs N] [--retries M]
#                            [--snapshot DIR] [--continue] [--help]
#
# 示例：
#   scripts/batch-analyze.sh ./bins/ --recurse --out ./batch-out --kind functions --jobs 4 --snapshot ./cache
#   第二次跑同样命令：全部命中快照缓存，显著更快。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SCHEMA_VERSION=1   # v2.7 导出脚本/schema 变化时 bump，自动使旧缓存失效

# ---- sha256 兼容（GNU sha256sum / macOS shasum）---------------------------
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else echo "NO_SHA256"; fi
}
# kind 对应的“产物标记文件”（用于判断是否已成功）
product_for_kind() {
  case "$1" in
    functions) echo "functions.json" ;; strings) echo "strings.json" ;;
    symbols) echo "symbols.json" ;; calls) echo "calls.json" ;;
    decompiled) echo "decompiled.json" ;; all) echo "functions.json" ;;
  esac
}

# ============================ worker 模式（xargs 调起）=======================
# 由主进程以 `--worker <target> <outRoot> <kind> <retries> <snapshotDir> <continue>` 调起。
# 每个 worker 永远 exit 0，结果写 <outRoot>/.results/<sha12>.json。
if [ "${1:-}" = "--worker" ]; then
  shift
  TARGET="$1"; OUT_ROOT="$2"; KIND="$3"; RETRIES="$4"; SNAP="${5:-}"; CONTINUE="$6"
  SHA="$(sha256_of "$TARGET")"; SHA12="${SHA:0:12}"
  T_OUT="$OUT_ROOT/targets/$SHA12"
  RES_DIR="$OUT_ROOT/.results"; mkdir -p "$RES_DIR" "$T_OUT"
  MARK="$(product_for_kind "$KIND")"
  start=$(date +%s)

  write_result() { # status cached error
    local status="$1" cached="$2" err="$3"
    local el=$(( $(date +%s) - start ))
    INPUT="$TARGET" SHA="$SHA" STATUS="$status" CACHED="$cached" EL="$el" TRIES="$TRIED" \
    OUTD="$T_OUT" ERR="$err" python3 - "$RES_DIR/$SHA12.json" <<'PY'
import json, os, sys
r = {
  "input": os.environ["INPUT"], "sha256": os.environ["SHA"], "status": os.environ["STATUS"],
  "cached": os.environ["CACHED"] == "true", "elapsed_sec": int(os.environ["EL"]),
  "retries": int(os.environ["TRIES"]), "out_dir": os.environ["OUTD"],
  "error": os.environ["ERR"],
}
json.dump(r, open(sys.argv[1], "w"), ensure_ascii=False)
PY
  }

  # 快照命中：直接还原缓存产物
  if [ -n "$SNAP" ] && [ -f "$SNAP/${SHA}_${KIND}_v${EXPORT_SCHEMA_VERSION}/$MARK" ]; then
    cp -f "$SNAP/${SHA}_${KIND}_v${EXPORT_SCHEMA_VERSION}/"*.json "$T_OUT/" 2>/dev/null || true
    TRIED=0; write_result success true ""; exit 0
  fi
  # --continue：已有完整产物则跳过
  if [ "$CONTINUE" = "1" ] && [ -f "$T_OUT/$MARK" ]; then
    TRIED=0; write_result skipped false ""; exit 0
  fi

  TRIED=0; ok=0; last_err=""
  while [ "$TRIED" -le "$RETRIES" ]; do
    TRIED=$((TRIED+1))
    if "$SCRIPT_DIR/ghidra-export.sh" "$TARGET" --out "$T_OUT" --kind "$KIND" >/dev/null 2>>"$T_OUT/headless.log"; then
      ok=1; break
    else
      last_err="$(tail -3 "$T_OUT/headless.log" 2>/dev/null | tr '\n' ' ')"
    fi
  done

  if [ "$ok" = "1" ]; then
    # 写快照缓存
    if [ -n "$SNAP" ]; then
      CDIR="$SNAP/${SHA}_${KIND}_v${EXPORT_SCHEMA_VERSION}"; mkdir -p "$CDIR"
      cp -f "$T_OUT/"*.json "$CDIR/" 2>/dev/null || true
    fi
    write_result success false ""
  else
    write_result failed false "$last_err"
  fi
  exit 0
fi

# ============================ 主模式 =========================================
BIN_ARGS=(); DIR=""; RECURSE=0; PATTERN=""
OUT_DIR="./batch-out"; KIND="all"; JOBS=""; RETRIES=1; SNAP=""; CONTINUE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) sed -n '2,22p' "$0" | sed 's/^# \?//'; exit 0 ;;
    --dir) DIR="$2"; shift 2 ;;
    --recurse) RECURSE=1; shift ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    --snapshot) SNAP="$2"; shift 2 ;;
    --continue) CONTINUE=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do BIN_ARGS+=("$1"); shift; done ;;
    -*) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
    *) BIN_ARGS+=("$1"); shift ;;
  esac
done

# 收集目标清单（NUL 分隔，防空格路径）
LIST="$(mktemp)"; trap 'rm -f "$LIST"' EXIT
add_target() { [ -f "$1" ] && printf '%s\0' "$1" >> "$LIST"; }
for b in "${BIN_ARGS[@]:-}"; do [ -n "$b" ] && add_target "$b"; done
if [ -n "$DIR" ]; then
  match() { # $1=path, $2=pattern
    [ -z "$2" ] && return 0
    # shellcheck disable=SC2254
    case "$1" in $2) return 0 ;; *) return 1 ;; esac
  }
  if [ "$RECURSE" = "1" ]; then
    while IFS= read -r -d '' f; do match "$f" "$PATTERN" && add_target "$f"; done < <(find "$DIR" -type f -print0)
  else
    for f in "$DIR"/*; do [ -f "$f" ] && match "$f" "$PATTERN" && add_target "$f"; done
  fi
fi
N="$(grep -zc '' "$LIST" 2>/dev/null || true)"
[ "$N" -gt 0 ] || { echo "未收集到任何目标文件" >&2; exit 2; }

mkdir -p "$OUT_DIR/targets" "$OUT_DIR/.results"
[ -n "$SNAP" ] && mkdir -p "$SNAP"

# jobs：nproc（Linux）/ sysctl hw.ncpu（macOS），封顶 4，且不超过目标数
if [ -z "$JOBS" ]; then
  if command -v nproc >/dev/null 2>&1; then JOBS="$(nproc)"
  else JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)"; fi
fi
[ "$JOBS" -gt 4 ] && JOBS=4
[ "$JOBS" -gt "$N" ] && JOBS="$N"
[ "$JOBS" -lt 1 ] && JOBS=1

echo "[batch] 目标数=$N  jobs=$JOBS  kind=$KIND  retries=$RETRIES  snapshot=${SNAP:-（无）}"
T0=$(date +%s)

# 并行：xargs -P；worker 永远 exit 0，失败不传染主进程
xargs -0 -P "$JOBS" -I{} \
  bash "$0" --worker "{}" "$OUT_DIR" "$KIND" "$RETRIES" "${SNAP:-}" "$CONTINUE" < "$LIST"

T1=$(date +%s)

# ---- 汇总 ------------------------------------------------------------------
python3 - "$OUT_DIR" "$T0" "$T1" <<'PY'
import json, glob, sys, os
out_root = sys.argv[1]; t0, t1 = int(sys.argv[2]), int(sys.argv[3])
rows = []
for f in sorted(glob.glob(os.path.join(out_root, ".results", "*.json"))):
    rows.append(json.load(open(f)))
succ = sum(1 for r in rows if r["status"] == "success")
fail = sum(1 for r in rows if r["status"] == "failed")
skip = sum(1 for r in rows if r["status"] == "skipped")
cached = sum(1 for r in rows if r.get("cached"))
summary = {
  "export_schema_version": 1,
  "total": len(rows), "success": succ, "failed": fail, "skipped": skip,
  "cached": cached, "total_elapsed_sec": t1 - t0, "targets": rows,
}
with open(os.path.join(out_root, "summary.json"), "w") as w:
    json.dump(summary, w, ensure_ascii=False, indent=2)
print(f"[batch] 完成：成功 {succ} / 失败 {fail} / 跳过 {skip}（其中缓存命中 {cached}），总耗时 {t1-t0}s")
for r in rows:
    tag = r["status"].upper() + ("(cached)" if r.get("cached") else "")
    print(f"  - {tag:16s} {os.path.basename(r['input']):24s} {r['elapsed_sec']}s -> {r['out_dir']}")
sys.exit(1 if fail else 0)
PY

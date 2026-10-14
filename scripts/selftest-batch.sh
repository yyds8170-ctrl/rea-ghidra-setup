#!/usr/bin/env bash
# =============================================================================
# selftest-batch.sh — 批量并行 + 快照缓存回归（不依赖 REA）。
# 对 examples/demo 的多份副本跑 batch-analyze.sh --kind functions（控时）：
#   ① 首次批量：3 个目标全部 success，退出 0；
#   ② 第二次同 snapshot：全部命中缓存（cached=3），秒回；
#   ③ 失败隔离：worker 在无效 Ghidra 环境下写 status=failed，好目标不受影响、退出码非 0。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO="$REPO_DIR/examples/demo"
[ -f "$DEMO" ] || { echo "selftest-batch: 缺少 $DEMO" >&2; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp "$DEMO" "$WORK/t1"; cp "$DEMO" "$WORK/t2"; cp "$DEMO" "$WORK/t3"
printf 'PATCH1\x00' >> "$WORK/t2"   # 让三个目标内容/sha 各异，避免结果文件碰撞
printf 'PATCHED\x00\x01' >> "$WORK/t3"

SNAP="$WORK/snap"; OUT1="$WORK/out1"; OUT2="$WORK/out2"
pass() { echo "  PASS $1"; }; fail() { echo "  FAIL $1"; FAILED=1; }
FAILED=0

echo "[selftest-batch] ① 首次批量（3 目标，functions，snapshot）"
set +e
timeout 600 bash "$SCRIPT_DIR/batch-analyze.sh" "$WORK/t1" "$WORK/t2" "$WORK/t3" \
  --out "$OUT1" --kind functions --jobs 3 --snapshot "$SNAP" >/tmp/batch1.log 2>&1
rc1=$?
set -e
pc1=0; python3 - "$OUT1" "$rc1" <<'PY'
import json,sys
d=json.load(open(f"{sys.argv[1]}/summary.json")); rc=int(sys.argv[2])
print(f"    success={d['success']} failed={d['failed']} cached={d['cached']} rc={rc}")
sys.exit(0 if (d['success']==3 and d['failed']==0 and rc==0) else 1)
PY
pc1=$?
if [ "$pc1" -eq 0 ]; then pass "首次批量 3 成功"; else fail "首次批量 3 成功"; fi

echo "[selftest-batch] ② 第二次同 snapshot（应全命中缓存）"
set +e
bash "$SCRIPT_DIR/batch-analyze.sh" "$WORK/t1" "$WORK/t2" "$WORK/t3" \
  --out "$OUT2" --kind functions --jobs 3 --snapshot "$SNAP" >/tmp/batch2.log 2>&1
rc2=$?
set -e
pc2=0; python3 - "$OUT2" "$rc2" <<'PY'
import json,sys
d=json.load(open(f"{sys.argv[1]}/summary.json")); rc=int(sys.argv[2])
print(f"    success={d['success']} failed={d['failed']} cached={d['cached']} rc={rc}")
sys.exit(0 if (d['cached']==3 and d['success']==3 and rc==0) else 1)
PY
pc2=$?
if [ "$pc2" -eq 0 ]; then pass "二次批量全命中缓存"; else fail "二次批量全命中缓存"; fi

echo "[selftest-batch] ③ 失败隔离（worker 在无效 Ghidra 环境下应 failed）"
BADOUT="$WORK/bad"; mkdir -p "$BADOUT"
set +e
TOOLS_DIR=/nonexistent GHIDRA_INSTALL_DIR=/nonexistent \
  bash "$SCRIPT_DIR/batch-analyze.sh" --worker "$WORK/t1" "$BADOUT" functions 1 "" 0 >/dev/null 2>&1
wr=$?
set -e
st="$(python3 -c "import json,glob;print(json.load(open(glob.glob('$BADOUT/.results/*.json')[0]))['status'])")"
if [ "$st" = "failed" ] && [ "$wr" = "0" ]; then
  pass "worker 失败不传染退出(status=failed, worker_exit=0)"
else
  fail "失败隔离(status=$st, exit=$wr)"
fi

if [ "$FAILED" = "0" ]; then
  echo "[selftest-batch] 全部通过"
else
  echo "[selftest-batch] 存在失败"; exit 1
fi

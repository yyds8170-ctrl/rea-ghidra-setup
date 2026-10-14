#!/usr/bin/env bash
# =============================================================================
# selftest-export.sh — Ghidra 导出回归：对 examples/demo 跑 --kind all 并断言产物。
# 不依赖 REA / Node。analyzeHeadless 较慢，只对最小 demo 跑一次。
# 退出码：全部断言通过为 0，否则非 0。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN="$REPO_DIR/examples/demo"
[ -f "$BIN" ] || { echo "selftest-export: 缺少 $BIN" >&2; exit 1; }

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "[selftest-export] 运行 ghidra-export --kind all（首次导入较慢）…"
REA_EXPORT_TIMEOUT="${REA_EXPORT_TIMEOUT:-900}" \
  "$SCRIPT_DIR/ghidra-export.sh" "$BIN" --out "$OUT" --kind all >/tmp/rea-export.log 2>&1 \
  || { echo "[selftest-export] ghidra-export 失败，日志尾部：" >&2; tail -20 /tmp/rea-export.log >&2; exit 1; }

python3 - "$OUT" <<'PY'
import json, sys, os
d = sys.argv[1]
def load(n):
    p = os.path.join(d, n)
    if not os.path.exists(p):
        sys.exit(f"[selftest-export] 缺少产物 {n}")
    return json.load(open(p))

funcs = load("functions.json")
strs  = load("strings.json")
syms  = load("symbols.json")
calls = load("calls.json")
dec   = load("decompiled.json")

names = [f.get("name","") for f in funcs]
checks = [
    ("函数 >= 1", len(funcs) >= 1),
    ("main 函数存在", "main" in names),
    ("字符串非空", len(strs) >= 1),
    ("符号非空", len(syms) >= 1),
    ("调用边非空", len(calls) >= 1),
    ("伪代码非空", len(dec) >= 1 and any(v.strip() for v in dec.values())),
]
bad = [msg for msg, ok in checks if not ok]
for msg, ok in checks:
    print(("  PASS " if ok else "  FAIL ") + msg)
if bad:
    sys.exit("[selftest-export] 断言失败: " + ", ".join(bad))
print(f"[selftest-export] 通过：functions={len(funcs)} strings={len(strs)} symbols={len(syms)} calls={len(calls)} decompiled={len(dec)}")
PY

#!/usr/bin/env bash
# =============================================================================
# build-domain-fixtures.sh — 生成 v5.6.0 领域案例所需的多格式小样本
#
# 产物写入 examples/domain-fixtures/（gitignore，不入库）；
# 必要源文件入库在 examples/domain-fixtures_src/（sample.py / add.wat / sub.wat）。
#
# 生成内容：
#   sample.pyc        由 sample.py 经 py_compile 生成（CPython 当前 ABI，3.7-3.13 可解析）
#   sample.db         用 stdlib sqlite3 建库（items / meta 两张表）
#   sample.pcap       用 struct 手工拼 libpcap 全局头 + 1 个以太网/IP/TCP 包
#   add.wasm/sub.wasm wat2wasm 把 .wat 编译成 wasm（wabt 缺失则 skip，不假装成功）
#
# 离线 ELF/PE 多架构 fixture 复用 scripts/build-fixtures.sh 的产物
# （examples/fixtures/linux_x86_64 等），本脚本不重复编译二进制。
#
# 用法：scripts/build-domain-fixtures.sh
# =============================================================================
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_DIR/examples/domain-fixtures_src"
OUT="$REPO_DIR/examples/domain-fixtures"

[ -f "$SRC/sample.py" ] || { echo "build-domain-fixtures: 缺少 $SRC/sample.py" >&2; exit 1; }

mkdir -p "$OUT"
find "$OUT" -mindepth 1 -delete

built=0; skipped=0
note_build() { echo "[gen] $1 -> $OUT/$2"; built=$((built+1)); }
note_skip() { echo "[skip] $1：$2" >&2; skipped=$((skipped+1)); }

# ---- 1) pyc：py_compile 直接落到 OUT（避免污染源目录 __pycache__）-------------
if command -v python3 >/dev/null 2>&1; then
  python3 - "$SRC/sample.py" "$OUT/sample.pyc" <<'PY'
import sys, py_compile
src, out = sys.argv[1], sys.argv[2]
py_compile.compile(src, cfile=out, doraise=True)
PY
  if [ -s "$OUT/sample.pyc" ]; then
    note_build "pyc" "sample.pyc"
  else
    note_skip "pyc" "生成后 sample.pyc 为空"
  fi
else
  note_skip "pyc" "未找到 python3"
fi

# ---- 2) SQLite：stdlib 建库 --------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  python3 - "$OUT/sample.db" <<'PY'
import os, sqlite3, sys
path = sys.argv[1]
if os.path.exists(path):
    os.remove(path)
con = sqlite3.connect(path)
cur = con.cursor()
cur.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT, qty INTEGER)")
cur.executemany("INSERT INTO items(name,qty) VALUES(?,?)",
                [("alpha", 3), ("beta", 7), ("gamma", 42)])
cur.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)")
cur.executemany("INSERT INTO meta(key,value) VALUES(?,?)",
                [("build", "domain-fixture"), ("version", "5.6.0")])
con.commit(); con.close()
PY
  if [ -s "$OUT/sample.db" ]; then
    note_build "sqlite" "sample.db"
  else
    note_skip "sqlite" "生成后 sample.db 为空"
  fi
else
  note_skip "sqlite" "未找到 python3"
fi

# ---- 3) pcap：手工拼 libpcap 全局头 + 1 个以太网/IPv4/TCP 包 -----------------
if command -v python3 >/dev/null 2>&1; then
  python3 - "$OUT/sample.pcap" <<'PY'
import struct, sys
path = sys.argv[1]
# global header: magic, ver_major=2, ver_minor=4, thiszone=0, sigfigs=0,
# snaplen=65535, network=1 (LINKTYPE_ETHERNET)
gh = struct.pack("<IHHIIII", 0xA1B2C3D4, 2, 4, 0, 0, 65535, 1)
eth = bytes.fromhex("001122334455") + bytes.fromhex("66778899aabb") + struct.pack(">H", 0x0800)
ip  = struct.pack(">BBHHHHH", 0x45, 0, 40, 0x1234, 0x4000, 64, 6) \
    + bytes([127, 0, 0, 1]) + bytes([127, 0, 0, 1])
tcp = struct.pack(">HHIIHH", 12345, 80, 1, 1, 0x18 << 8, 1024)
pkt = eth + ip + tcp + b"DOMFIX"
ph  = struct.pack("<IIII", 0, 0, len(pkt), len(pkt))  # ts_sec, ts_usec, incl, orig
open(path, "wb").write(gh + ph + pkt)
PY
  if [ -s "$OUT/sample.pcap" ]; then
    note_build "pcap" "sample.pcap"
  else
    note_skip "pcap" "生成后 sample.pcap 为空"
  fi
else
  note_skip "pcap" "未找到 python3"
fi

# ---- 4) wasm：wat2wasm 编译两个 .wat（REA 钉死 WABT 1.0.42）-----------------
if command -v wat2wasm >/dev/null 2>&1; then
  wat2wasm_one() { # <src.wat> <out.wasm>
    if wat2wasm "$SRC/$1" -o "$OUT/$2" 2>"$OUT/$2.log" && [ -s "$OUT/$2" ]; then
      note_build "wasm($1)" "$2"
    else
      note_skip "wasm($1)" "wat2wasm 失败（见 $OUT/$2.log）"
    fi
  }
  wat2wasm_one "add.wat" "add.wasm"
  wat2wasm_one "sub.wat" "sub.wasm"
else
  note_skip "wasm" "未找到 wat2wasm（REA 需要钉死的 WABT 1.0.42；缺失则相关案例在运行器中 skip）"
fi

echo "build-domain-fixtures: built=$built skipped=$skipped"
# pyc/sqlite/pcap 是 stdlib 必成项；任一缺失视为生成失败（环境异常，不静默）
[ -s "$OUT/sample.pyc" ] && [ -s "$OUT/sample.db" ] && [ -s "$OUT/sample.pcap" ]

#!/usr/bin/env bash
# =============================================================================
# scripts/selftest-download.sh — 健壮下载内核单测（本地 http，离线可跑）
#
# 用一个支持 Range、对越界 Range 返回 416 的本地 Python http 服务，验证：
#   ① 主源 404 → 自动 failover 到第二源成功，且产物 SHA-256 正确；
#   ② 全部坏源 → 非零退出，且不留半截目标文件；
#   ③ 预放与远端等大的 .part（模拟上次崩溃残留）→ curl -C - 续传遇到 416
#      被视为成功，原子落地后 SHA-256 正确（幂等/续传）。
#
# 用法：bash scripts/selftest-download.sh    全部通过退出 0。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; [ -n "${SRV_PID:-}" ] && kill "$SRV_PID" 2>/dev/null || true' EXIT

cd "$TMP" || exit 1

# ---- 造一个已知文件 ----------------------------------------------------------
printf 'REA-GHIDRA-SETUP-DOWNLOAD-KERNEL-TEST-0123456789-ABCDEFGHIJKLMNOP' > payload.bin
EXPECTED="$(cs_sha256 payload.bin 2>/dev/null || sha256sum payload.bin | awk '{print $1}')"

# ---- 起一个支持 Range / 416 的本地 http 服务 ---------------------------------
cat > srv.py <<'PY'
import http.server, os, re
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split('?')[0].lstrip('/')
        if not os.path.isfile(path):
            self.send_response(404); self.end_headers(); return
        data = open(path, 'rb').read()
        m = re.match(r'bytes=(\d+)-(\d*)', self.headers.get('Range', '') or '')
        if m:
            start = int(m.group(1)); end = int(m.group(2)) if m.group(2) else len(data) - 1
            if start >= len(data):
                self.send_response(416)
                self.send_header('Content-Range', 'bytes */%d' % len(data))
                self.end_headers(); return
            end = min(end, len(data) - 1)
            self.send_response(206)
            self.send_header('Content-Range', 'bytes %d-%d/%d' % (start, end, len(data)))
            self.send_header('Content-Length', str(end - start + 1))
            self.end_headers(); self.wfile.write(data[start:end + 1]); return
        self.send_response(200)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers(); self.wfile.write(data)
    def log_message(self, *a): pass
socketserver = __import__('socketserver')
socketserver.TCPServer(('127.0.0.1', 0), H).serve_forever()
PY

PORT=0
# 用一个占位脚本拿随机端口不便，改为固定高端口（单测环境）
PORT=$(( ( RANDOM % 1000 ) + 21000 ))
sed -i "s/('127.0.0.1', 0)/('127.0.0.1', $PORT)/" srv.py
python3 srv.py >/dev/null 2>&1 &
SRV_PID=$!
sleep 0.7
BASE="http://127.0.0.1:$PORT"

# 单测提速：单源只重试 1 次
export REA_DL_RETRIES=1

fail=0
check() { # $1=描述 $2=0/1期望通过 $3=实际rc
  if [ "$2" = "$3" ]; then echo "[PASS] $1"; else echo "[FAIL] $1（期望 rc=$2 实际 rc=$3）"; fail=1; fi
}

# ---- ① 主源坏（404）→ 第二源成功 -------------------------------------------
rm -f out1 out1.part
download out1 "$BASE/does-not-exist.bin" "$BASE/payload.bin" >/dev/null 2>&1
rc=$?
check "① failover 到第二源成功" 0 "$rc"
if [ "$rc" -eq 0 ]; then
  got="$(sha256sum out1 | awk '{print $1}')"
  if [ "$got" = "$EXPECTED" ]; then
    echo "[PASS] ① 产物 SHA-256 正确"
  else
    echo "[FAIL] ① 产物哈希不符（$got != $EXPECTED）"; fail=1
  fi
  if [ -f out1.part ]; then echo "[FAIL] ① 成功后不应残留 .part"; fail=1; fi
fi

# ---- ② 全部坏源 → 非零退出，无半截目标 --------------------------------------
rm -f out2 out2.part
download out2 "$BASE/nope1.bin" "$BASE/nope2.bin" >/dev/null 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "[PASS] ② 全坏源非零退出（rc=$rc）"
else
  echo "[FAIL] ② 全坏源却成功"; fail=1
fi
if [ ! -e out2 ]; then echo "[PASS] ② 无半截目标 out2"; else echo "[FAIL] ② 残留 out2"; fail=1; fi
if [ ! -e out2.part ]; then echo "[PASS] ② 无残留 out2.part"; else echo "[FAIL] ② 残留 out2.part"; fail=1; fi

# ---- ③ 续传/幂等：预置与远端等大的 .part → 416 当成功 -----------------------
rm -f out3 out3.part
cp payload.bin out3.part   # 伪造“上次下完但还没 mv”的半成品
download out3 "$BASE/payload.bin" >/dev/null 2>&1
rc=$?
check "③ 续传(416)落地成功" 0 "$rc"
if [ "$rc" -eq 0 ]; then
  got="$(sha256sum out3 | awk '{print $1}')"
  if [ "$got" = "$EXPECTED" ]; then
    echo "[PASS] ③ 续传后产物 SHA-256 正确"
  else
    echo "[FAIL] ③ 产物哈希不符"; fail=1
  fi
fi

echo
if [ "$fail" -eq 0 ]; then echo "下载内核单测通过"; exit 0; else echo "下载内核单测失败"; exit 1; fi

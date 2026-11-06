#!/usr/bin/env bash
# =============================================================================
# run-mcp-e2e.sh — REA MCP server（rea-agents --mcp, stdio JSON-RPC）端到端自测
#
# 真启动 server，按 MCP 2025-11-25 协议走完整一轮：
#   initialize → notifications/initialized → tools/list → tools/call
# 并逐条校验 JSON-RPC 信封（jsonrpc=="2.0"、id 对齐、result/error、content 类型）。
#
# 选的离线工具：inspect_byte_entropy（对一个临时小文件算 Shannon 熵，
# 不需要 Ghidra / 真机 / 网络，在本环境可真实跑通）。
#
# 用法：
#   bash examples/web-samples/run-mcp-e2e.sh                # 跑完整序列
#   bash examples/web-samples/run-mcp-e2e.sh --out trans.log # 同时落盘收发报文
#
# 退出码：0 全部通过；1 某条校验失败；2 参数错。
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# 版本号不硬编码：优先 config/versions.env，缺了再退默认
# shellcheck source=../../config/versions.env
[ -f "$REPO_ROOT/config/versions.env" ] && . "$REPO_ROOT/config/versions.env"
REA_VERSION="${REA_VERSION:-6.8.0}"

TRANSCRIPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) [ $# -ge 2 ] || { echo "--out 需要路径" >&2; exit 2; }; TRANSCRIPT="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^# ====/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

# 临时样本文件（inspect_byte_entropy 的入参）
TMP_BIN="$(mktemp "${TMPDIR:-/tmp}/rea-mcp-sample.XXXXXX.bin")"
trap 'rm -f "$TMP_BIN"' EXIT
printf 'REA-MCP-E2E-SAMPLE-0123456789abcdef\n%.0s' {1..40} > "$TMP_BIN"

echo "== REA MCP 端到端自测（rea-agents@${REA_VERSION}，stdio JSONL）=="
python3 - "$REA_VERSION" "$TMP_BIN" "$TRANSCRIPT" <<'PYEOF'
import json, subprocess, sys, time, select

ver, sample_path, transcript = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = ["npx", "-y", f"rea-agents@{ver}", "--mcp"]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.PIPE, text=True, bufsize=1)
tf = open(transcript, "w", encoding="utf-8") if transcript else None

fails = []
def check(name, cond, detail=""):
    mark = "OK " if cond else "FAIL"
    if not cond:
        fails.append(name)
    print(f"  [{mark}] {name}{(' — ' + detail) if detail else ''}")

def send(obj):
    line = json.dumps(obj, ensure_ascii=False)
    p.stdin.write(line + "\n"); p.stdin.flush()
    if tf: tf.write(">>> " + line + "\n"); tf.flush()

def recv(timeout=180):
    deadline = time.time() + timeout
    while time.time() < deadline:
        rl, _, _ = select.select([p.stdout], [], [], 1.0)
        if not rl:
            continue
        ln = p.stdout.readline()
        if not ln:
            return None
        ln = ln.strip()
        if not ln:
            continue
        if tf: tf.write("<<< " + ln + "\n"); tf.flush()
        try:
            return json.loads(ln)
        except Exception:
            continue
    return None

# 1) initialize
send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
      "params": {"protocolVersion": "2025-11-25", "capabilities": {},
                 "clientInfo": {"name": "rea-mcp-e2e", "version": "1.0.0"}}})
init = recv(180)
check("initialize 收到响应", init is not None)
check("initialize.jsonrpc==2.0", init and init.get("jsonrpc") == "2.0")
check("initialize.id==1", init and init.get("id") == 1)
check("initialize 无 error", init and "error" not in init)
srv = (init or {}).get("result", {}).get("serverInfo", {})
check("initialize.result.serverInfo.name==rea", srv.get("name") == "rea", f"server={srv}")

# 2) notifications/initialized（通知，无 id，不期待响应）
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
time.sleep(0.5)

# 3) tools/list
send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
tl = recv(60)
check("tools/list 收到响应", tl is not None)
check("tools/list.id==2", tl and tl.get("id") == 2)
tools = (tl or {}).get("result", {}).get("tools", [])
check("tools/list.result.tools 是非空数组", isinstance(tools, list) and len(tools) > 0,
      f"count={len(tools)}")
names = {t.get("name") for t in tools if isinstance(t, dict)}
check("tools/list 包含 inspect_byte_entropy", "inspect_byte_entropy" in names)

# 4) tools/call（离线、低依赖）：inspect_byte_entropy on 临时小文件
send({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
      "params": {"name": "inspect_byte_entropy",
                 "arguments": {"path": sample_path, "detail": "summary"}}})
tc = recv(180)
check("tools/call 收到响应", tc is not None)
check("tools/call.id==3", tc and tc.get("id") == 3)
check("tools/call 无 error", tc and "error" not in tc)
res = (tc or {}).get("result", {})
check("tools/call.result.isError != true", res.get("isError") is not True)
content = res.get("content", [])
check("tools/call.result.content 非空且元素为 text",
      isinstance(content, list) and len(content) > 0 and
      all(c.get("type") == "text" for c in content),
      f"items={len(content)}")
# text 体内应是 Evidence JSON，且 file_entropy 是数字
try:
    ev = json.loads(content[0]["text"])
    summ = ev["normalized_result"]["summary"]
    check("Evidence.normalized_result.summary.file_entropy 是数字",
          isinstance(summ.get("file_entropy"), (int, float)),
          f"file_entropy={summ.get('file_entropy')}")
except Exception as e:
    check("Evidence text 可解析且含 summary.file_entropy", False, repr(e))

p.stdin.close()
try:
    p.wait(timeout=10)
except Exception:
    p.kill()
if tf:
    tf.write("=== stderr ===\n" + p.stderr.read() + "\n")
    tf.close()

print()
if fails:
    print(f"FAILED: {len(fails)} 项不通过 -> {fails}")
    sys.exit(1)
print("ALL CHECKS PASSED")
PYEOF

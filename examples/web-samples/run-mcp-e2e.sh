#!/usr/bin/env bash
# =============================================================================
# run-mcp-e2e.sh — REA MCP server（rea-agents --mcp, stdio JSON-RPC）端到端自测
#
# 真启动 server，按 MCP 2025-11-25 协议走完整一轮：
#   initialize → notifications/initialized → tools/list → 多个离线 tools/call
# 并逐条校验 JSON-RPC 信封（jsonrpc=="2.0"、id 对齐、result/error、content 类型）。
#
# 已实跑的离线 tools/call（无需 Ghidra/真机/网络）：
#   - inspect_byte_entropy     对临时小文件算 Shannon 熵
#   - inspect_analysis_settings 读运行时设置清单
#   - list_unknowns            列 residual unknowns（空会话）
#   - binary_session            报告当前无打开目标
# 错误用例（断言信封形状）：
#   - 调用未声明工具        -> 顶层 JSON-RPC error（code=-32602）
#   - 缺必填参数            -> result.isError==true（MCP 业务错误）
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

dead = False
def send(obj):
    global dead
    if dead:
        return
    line = json.dumps(obj, ensure_ascii=False)
    try:
        p.stdin.write(line + "\n"); p.stdin.flush()
        if tf: tf.write(">>> " + line + "\n"); tf.flush()
    except BrokenPipeError:
        dead = True

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

def call_tool(cid, name, args, timeout=120):
    send({"jsonrpc": "2.0", "id": cid, "method": "tools/call",
          "params": {"name": name, "arguments": args}})
    return recv(timeout)

def first_text(res):
    c = res.get("result", {}).get("content", [])
    return c[0]["text"] if c and isinstance(c[0], dict) else ""

# 5) 离线工具 #2：inspect_analysis_settings（会话级，无需文件/目标）
r4 = call_tool(4, "inspect_analysis_settings", {})
check("tools/call#4 inspect_analysis_settings 有响应", r4 is not None and r4.get("id") == 4)
try:
    s4 = json.loads(first_text(r4 or {}))
    check("inspect_analysis_settings.settings 是非空数组",
          isinstance(s4.get("settings"), list) and len(s4["settings"]) > 0,
          f"count={len(s4.get('settings', []))}")
except Exception as e:
    check("inspect_analysis_settings text 可解析", False, repr(e))

# 6) 离线工具 #3：list_unknowns（会话级空清单）
r5 = call_tool(5, "list_unknowns", {})
check("tools/call#5 list_unknowns 有响应", r5 is not None and r5.get("id") == 5)
try:
    s5 = json.loads(first_text(r5 or {}))
    items = s5.get("result", {}).get("items")
    check("list_unknowns.result.items 是数组", isinstance(items, list), f"items={items}")
except Exception as e:
    check("list_unknowns text 可解析", False, repr(e))

# 7) 离线工具 #4：binary_session（报告当前无打开目标）
r6 = call_tool(6, "binary_session", {})
check("tools/call#6 binary_session 有响应", r6 is not None and r6.get("id") == 6)
try:
    s6 = json.loads(first_text(r6 or {}))
    check("binary_session.result.open 是布尔（无目标打开）",
          isinstance(s6.get("result", {}).get("open"), bool),
          f"open={s6.get('result', {}).get('open')}")
except Exception as e:
    check("binary_session text 可解析", False, repr(e))

# 8) 错误用例 A：调用未声明的工具 -> 标准 JSON-RPC error 信封（-32602）
r7 = call_tool(7, "no_such_tool_does_not_exist", {})
check("tools/call#7 未知工具返回 JSON-RPC error 信封",
      r7 is not None and "error" in r7 and r7.get("id") == 7,
      f"code={(r7 or {}).get('error', {}).get('code')}")
check("tools/call#7 error.code==-32602",
      r7 is not None and r7.get("error", {}).get("code") == -32602)

# 9) 错误用例 B：缺必填参数 -> result.isError==true（MCP 业务错误信封，非 JSON-RPC 级）
r8 = call_tool(8, "inspect_byte_entropy", {})
check("tools/call#8 缺必填参数 result.isError==true",
      r8 is not None and r8.get("result", {}).get("isError") is True
      and r8.get("id") == 8,
      f"isError={(r8 or {}).get('result', {}).get('isError')}")

try:
    p.stdin.close()
except (BrokenPipeError, OSError):
    pass
try:
    p.wait(timeout=10)
except Exception:
    p.kill()
if tf:
    try:
        tf.write("=== stderr ===\n" + p.stderr.read() + "\n")
    except Exception:
        pass
    tf.close()

print()
if fails:
    print(f"FAILED: {len(fails)} 项不通过 -> {fails}")
    sys.exit(1)
print("ALL CHECKS PASSED")
PYEOF

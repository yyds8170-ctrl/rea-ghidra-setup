#!/usr/bin/env bash
# =============================================================================
# run-domain-cases.sh — v5.6.0 领域案例自动化断言
#
# 对 examples/domain-fixtures/ 下的多格式样本 + examples/fixtures/ 下的 ELF，
# 逐条走 lib/rea-wrap.sh 包装器调用 REA，断言：
#   - 成功：rea-wrap 退出 0 且 stdout JSON 含预期字段；
#   - 失败：非 0 退出即 FAIL；
#   - 工具/样本/运行时前置不可得：计 SKIP 并打印原因（绝不假装成功）。
#
# 前置探测在调用 REA 之前完成，因此：
#   - objdump/gdb/rizin/wabt/tshark/pwntools 缺失 → SKIP；
#   - REA 钉死的版本轮廓（WABT 1.0.42 / Wireshark 4.x / pwntools 4.15.0 组合 /
#     Node>=24.15 的 sqlite provider）不满足 → SKIP 并写明 CI 侧如何补齐。
#
# 用法：
#   bash scripts/run-domain-cases.sh
#   WABT_BIN=/opt/wabt-1.0.42/bin REA_PWNTOOLS_PYTHON=/opt/rea-pwn-env/bin/python \
#     bash scripts/run-domain-cases.sh
# 退出：有 FAIL 则非 0；仅 PASS/SKIP 则 0。
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/rea-wrap.sh
. "$REPO_DIR/lib/rea-wrap.sh"

FIX="$REPO_DIR/examples/domain-fixtures"
WORK="$(mktemp -d "${TMPDIR:-/tmp}"/rea-domain-cases.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0; SKIP=0
pass(){ printf '  \033[32m[PASS]\033[0m %-30s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
skip(){ printf '  \033[33m[SKIP]\033[0m %-30s %s\n' "$1" "$2"; SKIP=$((SKIP+1)); }
fail(){ printf '  \033[31m[FAIL]\033[0m %-30s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# 前置探测
# ---------------------------------------------------------------------------
have(){ command -v "$1" >/dev/null 2>&1; }

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"

# REA_PWNTOOLS_PYTHON：必须是绝对路径且钉死三件套版本
PWNT_OK=0
if [ -n "${REA_PWNTOOLS_PYTHON:-}" ] && [ -x "${REA_PWNTOOLS_PYTHON:-/nonexistent}" ]; then
  if "${REA_PWNTOOLS_PYTHON}" -c 'import importlib.metadata as m, sys
sys.exit(0 if (m.version("pwntools"), m.version("pyelftools"), m.version("unicorn")) == ("4.15.0", "0.33", "2.1.2") else 1)' \
      >/dev/null 2>&1; then
    PWNT_OK=1
  fi
fi

# REA_WABT_BIN_DIRECTORY：REA 钉死 wasm-objdump/wasm2wat/wasm-validate == 1.0.42
WABT_OK=0
WABT_DIR="${REA_WABT_BIN_DIRECTORY:-}"
if [ -n "$WABT_DIR" ] && [ -x "$WABT_DIR/wasm-objdump" ]; then
  if [ "$("$WABT_DIR/wasm-objdump" --version 2>/dev/null | head -1)" = "1.0.42" ]; then
    WABT_OK=1
  fi
fi

# tshark：REA 要求 Wireshark 4.x
TSHARK_MAJOR=0
if have tshark; then
  TSHARK_MAJOR="$(tshark --version 2>/dev/null | head -1 | sed -n 's/.* \([0-9]\{1,\}\)\.[0-9].*/\1/p')"
  [ -n "$TSHARK_MAJOR" ] || TSHARK_MAJOR=0
fi

# ELF fixture：优先复用 examples/fixtures/linux_x86_64；缺失则尝试现编
ELF="$REPO_DIR/examples/fixtures/linux_x86_64"
if [ ! -s "$ELF" ]; then
  bash "$SCRIPT_DIR/build-fixtures.sh" >/dev/null 2>&1 || true
fi
ELF_OK=0; [ -s "$ELF" ] && ELF_OK=1

echo "== 环境探测 =="
echo "  node major            = ${NODE_MAJOR}"
echo "  objdump/gdb/rizin     = $(have objdump && echo -n objdump:y || echo -n objdump:n) $(have gdb && echo gdb:y || echo gdb:n) $(have rizin && echo rizin:y || echo rizin:n)"
echo "  wabt profile(1.0.42)  = ${WABT_OK} (dir=${WABT_DIR:-<unset>})"
echo "  tshark major          = ${TSHARK_MAJOR} (REA 需 4.x)"
echo "  pwntools pinned env   = ${PWNT_OK} (REA_PWNTOOLS_PYTHON=${REA_PWNTOOLS_PYTHON:-<unset>})"
echo "  ELF fixture           = ${ELF_OK} ($ELF)"
echo

# ---------------------------------------------------------------------------
# 断言执行助手
#   run_rea <case> <expected-json-file> -- <passthrough...>
#   通过后用 CASE=<case> python3 断言脚本校验字段。
# ---------------------------------------------------------------------------
ASSERT_PY="$WORK/assert.py"
cat > "$ASSERT_PY" <<'PY'
import json, os, sys

case = os.environ["CASE"]
path = os.environ["JSON_OUT"]
with open(path, encoding="utf-8") as fh:
    d = json.load(fh)

ok = True
def need(cond, msg):
    global ok
    if not cond:
        ok = False
        print(f"    [assert-fail] {msg}")

nr = d.get("normalized_result") or {}
raw = d.get("raw_result") or {}

if case == "inspect-python-pyc":
    hdr = nr.get("header") or {}
    need(str(hdr.get("python_version", "")).startswith("3."), f"header.python_version 形如 3.x（实得 {hdr.get('python_version')}）")
    objs = nr.get("code_objects") or []
    names = set()
    for o in objs:
        names.update(o.get("names") or [])
    need("greet" in names, f"code_objects names 含 greet（实得 {sorted(names)}）")
    flat = json.dumps(nr, ensure_ascii=False)
    need("DOMFIX-2026" in flat, "pyc 常量中含 DOMFIX-2026")

elif case == "inspect-sqlite-database":
    need(isinstance(nr, dict) and nr, "normalized_result 非空")
    need("items" in json.dumps(nr), "SQLite 结果中含表 items")

elif case == "inspect-wasm-artifact":
    need(nr.get("validation") == "valid", f"validation==valid（实得 {nr.get('validation')}）")
    entries = (nr.get("interface") or {}).get("entries") or []
    names = [e.get("name") for e in entries]
    need("add" in names, f"interface.entries 导出含 add（实得 {names}）")

elif case == "compare-wasm-interfaces":
    need(nr.get("scope") == "exports", f"scope==exports（实得 {nr.get('scope')}）")
    changes = nr.get("changes") or []
    need(len(changes) >= 1, f"changes 非空（实得 {len(changes)}）")

elif case == "inspect-pcap-client":
    need(isinstance(d, dict) and ("provider" in d or "normalized_result" in d), "pcap-client 返回 Evidence 信封")
    need("tshark" in json.dumps(d).lower(), "结果中提到 tshark 客户端")

elif case == "inspect-pcap-capture":
    need(isinstance(nr, dict) and nr, "pcap-capture normalized_result 非空")

elif case == "inspect-with-objdump":
    out = raw.get("stdout") or ""
    need("elf64-x86-64" in out, f"objdump file-header 输出含 elf64-x86-64（前 120 字：{out[:120]!r}）")

elif case == "list-objdump-architectures":
    out = raw.get("stdout") or ""
    need("elf64-x86-64" in out, f"objdump -i 列表含 elf64-x86-64")

elif case == "inspect-binary-layout":
    arch = nr.get("architecture") or {}
    need(arch.get("bits") == 64, f"architecture.bits==64（实得 {arch}）")
    need(len(nr.get("sections") or []) >= 1, "sections 非空")

elif case == "debug-with-gdb":
    recs = raw.get("records") or []
    blob = "\n".join(str(r) for r in recs) + "\n" + str(raw.get("stdout") or "")
    need("GNU gdb" in blob, "gdb MI 输出中含 GNU gdb 版本横幅")

elif case == "execute-rizin-command":
    need(isinstance(d, dict) and ("normalized_result" in d or "raw_result" in d), "rizin 命令返回 Evidence 信封")

elif case == "debug-with-rizin":
    need(isinstance(d, dict) and ("normalized_result" in d or "raw_result" in d), "rizin 调试返回 Evidence 信封")

elif case == "inspect-byte-entropy":
    fe = nr.get("file_entropy")
    need(isinstance(fe, (int, float)) and 0.0 <= float(fe) <= 8.0, f"file_entropy 为 0..8 数值（实得 {fe}）")

elif case == "inspect-elf-notes":
    need(nr.get("machine") == 62, f"machine==62(EM_X86_64)（实得 {nr.get('machine')}）")

elif case == "inspect-artifact":
    obs = nr.get("observations") or []
    need(isinstance(obs, list) and len(obs) >= 1, f"observations 非空（实得 {len(obs)}）")

elif case == "capabilities":
    caps = d.get("capabilities") or []
    need(isinstance(caps, list) and len(caps) >= 1, f"capabilities 非空（实得 {len(caps)}）")

else:
    need(False, f"未知断言用例 {case}")

sys.exit(0 if ok else 1)
PY

# run_rea <case> <label> -- <passthrough...>
run_rea() {
  local case="$1"; local label="$2"; shift 2
  local out="$WORK/${case}.json"
  local rc=0
  rea_wrap_exec "$case" --json --out "$out" -- "$@" || rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "$label" "rea-wrap 退出 rc=${rc}（详见 $out 与上方 stderr）"
    return 1
  fi
  if ! CASE="$case" JSON_OUT="$out" python3 "$ASSERT_PY"; then
    fail "$label" "JSON 字段断言未通过"
    return 1
  fi
  pass "$label" "exit 0 + 字段断言命中"
  return 0
}

echo "== 领域案例 =="

# ---- 多格式：pyc ------------------------------------------------------------
if [ -s "$FIX/sample.pyc" ]; then
  run_rea inspect-python-pyc "inspect-python-pyc" "$FIX/sample.pyc"
else
  skip "inspect-python-pyc" "缺少样本 $FIX/sample.pyc（先跑 build-domain-fixtures.sh）"
fi

# ---- 多格式：SQLite（REA sqlite provider 需 Node>=24.15）---------------------
if [ "$NODE_MAJOR" -lt 24 ]; then
  skip "inspect-sqlite-database" "Node major=${NODE_MAJOR}：REA sqlite provider 需 Node>=24.15（CI 用 Node 24 跑）"
elif [ -s "$FIX/sample.db" ]; then
  run_rea inspect-sqlite-database "inspect-sqlite-database" \
    "$FIX/sample.db" --table items --row-limit 5
else
  skip "inspect-sqlite-database" "缺少样本 $FIX/sample.db"
fi

# ---- 多格式：WASM（REA 钉死 WABT 1.0.42）------------------------------------
if [ "$WABT_OK" -ne 1 ]; then
  skip "inspect-wasm-artifact" "未提供 REA_WABT_BIN_DIRECTORY 且 wasm-objdump==1.0.42（CI 下载官方 1.0.42 release）"
  skip "compare-wasm-interfaces" "同上：依赖 WABT 1.0.42 的两份 inspect Evidence"
elif [ ! -s "$FIX/add.wasm" ] || [ ! -s "$FIX/sub.wasm" ]; then
  skip "inspect-wasm-artifact" "缺少 add.wasm/sub.wasm（wat2wasm 未生成）"
  skip "compare-wasm-interfaces" "缺少 add.wasm/sub.wasm"
else
  run_rea inspect-wasm-artifact "inspect-wasm-artifact" "$FIX/add.wasm"
  # compare：先取两份完整 Evidence，再拼 left/right/scope 输入
  L="$WORK/wasm-left.json"; R="$WORK/wasm-right.json"; CMP="$WORK/wasm-cmp.json"
  rc=0
  rea_wrap_exec inspect-wasm-artifact --json --out "$L" -- "$FIX/add.wasm" || rc=$?
  rea_wrap_exec inspect-wasm-artifact --json --out "$R" -- "$FIX/sub.wasm" || rc=$((rc + $?))
  if [ "$rc" -ne 0 ]; then
    fail "compare-wasm-interfaces" "生成左右 Evidence 失败（rc=${rc}）"
  else
    python3 - "$L" "$R" "$CMP" <<'PY'
import json, sys
l = json.load(open(sys.argv[1])); r = json.load(open(sys.argv[2]))
json.dump({"left": l, "right": r, "scope": "exports"}, open(sys.argv[3], "w"))
PY
    run_rea compare-wasm-interfaces "compare-wasm-interfaces" "$CMP"
  fi
fi

# ---- 多格式：pcap（REA 需 Wireshark 4.x）------------------------------------
if [ "$TSHARK_MAJOR" -lt 4 ]; then
  skip "inspect-pcap-client" "tshark major=${TSHARK_MAJOR}：REA pcap provider 需 Wireshark 4.x（CI ubuntu-24.04 为 4.x）"
  skip "inspect-pcap-capture" "同上：依赖 Wireshark 4.x + 样本 sample.pcap"
else
  run_rea inspect-pcap-client "inspect-pcap-client"
  if [ -s "$FIX/sample.pcap" ]; then
    run_rea inspect-pcap-capture "inspect-pcap-capture" "$FIX/sample.pcap"
  else
    skip "inspect-pcap-capture" "缺少样本 $FIX/sample.pcap"
  fi
fi

# ---- 离线二进制：objdump（binutils）-----------------------------------------
if [ "$ELF_OK" -ne 1 ]; then
  skip "inspect-with-objdump" "缺少 ELF fixture（build-fixtures.sh 未产出 linux_x86_64）"
  skip "list-objdump-architectures" "同上"
elif ! have objdump; then
  skip "inspect-with-objdump" "未找到 objdump（binutils）"
  skip "list-objdump-architectures" "未找到 objdump（binutils）"
else
  run_rea inspect-with-objdump "inspect-with-objdump" "$ELF" file_headers
  run_rea list-objdump-architectures "list-objdump-architectures"
fi

# ---- 离线二进制：pwntools 布局（钉死 pwntools 4.15.0 组合）------------------
if [ "$ELF_OK" -ne 1 ]; then
  skip "inspect-binary-layout" "缺少 ELF fixture"
elif [ "$PWNT_OK" -ne 1 ]; then
  skip "inspect-binary-layout" "REA_PWNTOOLS_PYTHON 未设置或未含钉死组合 pwntools4.15.0/pyelftools0.33/unicorn2.1.2"
else
  run_rea inspect-binary-layout "inspect-binary-layout" "$ELF"
fi

# ---- 动态：GDB（受控本地进程，--inferior-tty 走 pty）------------------------
if ! have gdb; then
  skip "debug-with-gdb" "未找到 gdb"
else
  PTY="$(script -qec 'tty' /dev/null 2>/dev/null | tail -1)"
  case "$PTY" in /dev/pts/*) ;; *) PTY="" ;; esac
  if [ -z "$PTY" ]; then
    fail "debug-with-gdb" "无法分配 pty 作为 --inferior-tty"
  else
    run_rea debug-with-gdb "debug-with-gdb" "show version" --inferior-tty "$PTY"
  fi
fi

# ---- 动态：Rizin（若可装）----------------------------------------------------
if ! have rizin; then
  skip "execute-rizin-command" "未找到 rizin（CI 尝试装官方 release，失败则 skip）"
  skip "debug-with-rizin" "未找到 rizin"
elif [ "$ELF_OK" -ne 1 ]; then
  skip "execute-rizin-command" "缺少 ELF fixture"
  skip "debug-with-rizin" "缺少 ELF fixture"
else
  run_rea execute-rizin-command "execute-rizin-command" "$ELF" "ij"
  # debug-with-rizin 与 gdb 同源，flags 含 --inferior-tty；但 rizin 会 realpath 校验
  # 该 tty 在调用时仍存活——`script -qec 'tty'` 打印完即退出、pts 随即销毁，会报
  # ENOENT。故用 python3 pty.openpty() 常驻持有 master，把 tty 名写进临时文件。
  RIZIN_PTY_FILE="$WORK/rizin.pty"
  RIZIN_HOLDER=""
  python3 -c '
import pty, os, sys, time
m, s = pty.openpty()
open(sys.argv[1], "w").write(os.ttyname(s))
time.sleep(600)
' "$RIZIN_PTY_FILE" >/dev/null 2>&1 &
  RIZIN_HOLDER=$!
  PTY=""
  for _ in $(seq 1 30); do [ -s "$RIZIN_PTY_FILE" ] && break; sleep 0.1; done
  [ -s "$RIZIN_PTY_FILE" ] && PTY="$(tr -d '\r\n' < "$RIZIN_PTY_FILE")"
  case "$PTY" in /dev/pts/*) ;; *) PTY="" ;; esac
  if [ -z "$PTY" ]; then
    fail "debug-with-rizin" "无法分配存活 pty 作为 --inferior-tty"
  else
    run_rea debug-with-rizin "debug-with-rizin" "$ELF" "dr" --inferior-tty "$PTY"
  fi
  if [ -n "$RIZIN_HOLDER" ]; then kill "$RIZIN_HOLDER" 2>/dev/null || true; fi
fi

# ---- Evidence/工程化与平台自检（纯内置，Linux 可断言）------------------------
if [ "$ELF_OK" -ne 1 ]; then
  skip "inspect-artifact" "缺少 ELF fixture"
  skip "inspect-byte-entropy" "缺少 ELF fixture"
  skip "inspect-elf-notes" "缺少 ELF fixture"
else
  run_rea inspect-artifact "inspect-artifact" "$ELF"
  run_rea inspect-byte-entropy "inspect-byte-entropy" "$ELF"
  run_rea inspect-elf-notes "inspect-elf-notes" "$ELF"
fi
run_rea capabilities "capabilities"

# ---- 汇总 -------------------------------------------------------------------
echo "------------------------------------------------------------------"
echo "汇总：passed=${PASS} failed=${FAIL} skipped=${SKIP}"
if [ "$FAIL" -ne 0 ]; then
  echo "存在失败案例（见上方 [FAIL]）"
  exit 1
fi
echo "OK：failed=0（skipped 为环境前置缺失的显式跳过）"
exit 0

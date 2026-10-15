#!/usr/bin/env bash
# =============================================================================
# scripts/mcp-setup.sh — REA MCP server 一键注册 + 连接自检（Linux / macOS）
#
# 真实能力（rea-agents@6.5.0，2026-10-15 实测）：
#   - MCP over stdio 用【换行分隔 JSONL】，无 Content-Length 帧；
#     发一行 initialize，回一行 {"result":{...},"jsonrpc":"2.0","id":1}。
#   - `rea mcp doctor --json` 是官方握手校验（healthy / initialize / tools 对账）。
#   - `rea doctor --provider ghidra --format json` 的 providerInspections[].id=ghidra.available
#
# 本脚本【自己写标准 MCP stdio JSON】而非调 `rea setup`，原因：
#   - rea setup 会顺带装 skill / 改多处 identity，自动化里不可控；
#   - 我们只做“备份 → 合并本项目 server 条目 → 不动其它条目 → 幂等”，最小副作用。
#
# 安全：默认不写盘；--dry-run 只渲染；--client <名> --yes 才写，写前备份 .bak。
#
# 用法：
#   bash scripts/mcp-setup.sh --list                 # 只检测客户端，不改
#   bash scripts/mcp-setup.sh --dry-run --client claude-desktop
#   bash scripts/mcp-setup.sh --client claude-desktop --yes
#   bash scripts/mcp-setup.sh --check                # 原生 stdio 握手 + (有 Ghidra 时) doctor
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
load_versions 2>/dev/null || true

# v3.0 集中发现：env 未设/不合法时回退 current 软链 → 枚举（不覆盖合法显式 env）
_MJ="$(resolve_jdk_home || true)";     [ -n "$_MJ" ] && export JAVA_HOME="$_MJ"
_MG="$(resolve_ghidra_dir || true)";  [ -n "$_MG" ] && export GHIDRA_INSTALL_DIR="$_MG"

MODE_LIST=0; MODE_DRY=0; MODE_CHECK=0; MODE_YES=0
CLIENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list) MODE_LIST=1; shift ;;
    --dry-run) MODE_DRY=1; shift ;;
    --check) MODE_CHECK=1; shift ;;
    --yes|-y) MODE_YES=1; shift ;;
    --client) [ $# -ge 2 ] || { echo "--client 需要客户端名" >&2; exit 2; }; CLIENT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
  esac
done

UNAME_S="$(uname -s)"

# 跨平台超时执行：GNU coreutils 用 timeout，macOS（BSD）有 coreutils 时用 gtimeout，
# 都没有时退回 perl 的 alarm+exec（Linux/macOS 自带 perl）；再否则直接执行。
# 用法：timeout_run <秒> 命令 [参数...]
timeout_run() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "$@"
  else
    local _t="$1"; shift
    "$@"
  fi
}

# ---- 客户端配置注册表（按真实 MCP 约定路径）----------------------------------
# 输出：$1=client 名 → 打印 "配置文件路径|JSON 顶层 key"。已存在则视为“已安装客户端”。
client_config_path() {
  local c="$1"
  case "$c" in
    claude-desktop)
      case "$UNAME_S" in
        Darwin) echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json|mcpServers" ;;
        *)      echo "$HOME/.config/Claude/claude_desktop_config.json|mcpServers" ;;
      esac ;;
    cursor)
      case "$UNAME_S" in
        Darwin) echo "$HOME/Library/Application Support/Cursor/User/globalStorage/mcp.json|mcpServers" ;;
        *)      echo "$HOME/.config/Cursor/User/globalStorage/mcp.json|mcpServers" ;;
      esac ;;
    vscode)
      case "$UNAME_S" in
        Darwin) echo "$HOME/Library/Application Support/Code/User/mcp.json|servers" ;;
        *)      echo "$HOME/.config/Code/User/mcp.json|servers" ;;
      esac ;;
    claude-code)
      echo "$HOME/.claude.json|mcpServers" ;;
    *) echo "" ;;
  esac
}

KNOWN_CLIENTS="claude-desktop cursor vscode claude-code"

# ---- 构造 stdio 条目 --------------------------------------------------------
# 解析 npx 绝对路径（更稳）；找不到则回退 "npx"
NPX_BIN="$(command -v npx 2>/dev/null || true)"
[ -n "$NPX_BIN" ] || NPX_BIN="npx"

# env：带上 Ghidra/JDK 环境与镜像模式（仅当已设置时）
build_entry_json() {
  local env_pairs="{}"
  env_pairs="$(python3 - "${JAVA_HOME:-}" "${GHIDRA_INSTALL_DIR:-}" "$(rea_mode 2>/dev/null || echo auto)" <<'PY'
import json, sys
jh, gh, mode = sys.argv[1], sys.argv[2], sys.argv[3]
env = {}
if jh: env["JAVA_HOME"] = jh
if gh: env["GHIDRA_INSTALL_DIR"] = gh
if mode == "cn": env["REA_MIRROR"] = "cn"
print(json.dumps(env, ensure_ascii=False))
PY
)"
  python3 - "$NPX_BIN" "$REA_VERSION" "$env_pairs" <<'PY'
import json, sys
npx, ver, env_raw = sys.argv[1], sys.argv[2], sys.argv[3]
entry = {
  "command": npx,
  "args": ["-y", f"rea-agents@{ver}", "--mcp"],
  "env": json.loads(env_raw),
}
print(json.dumps(entry, ensure_ascii=False, indent=2))
PY
}

# ---- --list ----------------------------------------------------------------
if [ "$MODE_LIST" = "1" ]; then
  echo "== 检测到的 MCP 客户端配置（${UNAME_S}）=="
  for c in $KNOWN_CLIENTS; do
    line="$(client_config_path "$c")"
    f="${line%%|*}"
    if [ -f "$f" ]; then st="已安装"; else st="未安装"; fi
    printf '  %-14s %-8s → %s\n' "$c" "$st" "$f"
  done
  echo
  echo "将注册的 server 名：rea  （command=$NPX_BIN -y rea-agents@$REA_VERSION --mcp）"
  echo "下一步：bash scripts/mcp-setup.sh --dry-run --client <名>"
  exit 0
fi

# ---- --check：连接自检（不需要 --client）-----------------------------------
if [ "$MODE_CHECK" = "1" ]; then
  echo "== [a] MCP stdio 原生握手（JSON-RPC initialize）=="
  init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"rea-setup","version":"1.0.0"}}}'
  resp="$(printf '%s\n' "$init" | timeout_run 90 npx -y "rea-agents@${REA_VERSION}" --mcp 2>/dev/null | head -n 1)"
  if printf '%s' "$resp" | grep -q '"result"'; then
    srv="$(printf '%s' "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("result",{}).get("serverInfo",{}).get("name","?"),d.get("result",{}).get("serverInfo",{}).get("version","?"))' 2>/dev/null || echo "?")"
    echo "  [OK] initialize 成功，server=$srv"
  else
    echo "  [FAIL] 未收到合法 initialize result（响应：${resp:-<空>}）" >&2
    exit 1
  fi

  echo "== [b] Ghidra provider 体检（有 Ghidra/JDK 环境时）=="
  if [ -n "${GHIDRA_INSTALL_DIR:-}" ] && [ -n "${JAVA_HOME:-}" ]; then
    doc="$(timeout_run 180 npx -y "rea-agents@${REA_VERSION}" doctor --provider ghidra --format json 2>/dev/null || true)"
    gh_ok="$(printf '%s' "$doc" | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin)
  for p in d.get("providerInspections",[]):
    if p.get("id")=="ghidra":
      print("yes" if p.get("available") else "no"); break
  else: print("no")
except Exception: print("no")' 2>/dev/null || echo no)"
    if [ "$gh_ok" = "yes" ]; then
      ver="$(printf '%s' "$doc" | python3 -c 'import sys,json
d=json.load(sys.stdin)
for p in d.get("providerInspections",[]):
  if p.get("id")=="ghidra": print(p.get("providerVersion") or "?"); break' 2>/dev/null || echo "?")"
      echo "  [OK] Ghidra provider 可用（version=${ver}）"
    else
      echo "  [FAIL] Ghidra provider 不可用（检查 JAVA_HOME/GHIDRA_INSTALL_DIR）" >&2; exit 1
    fi
  else
    echo "  [跳过] 未设置 GHIDRA_INSTALL_DIR/JAVA_HOME（仅做握手 a）"
  fi
  echo "连接自检通过。"
  exit 0
fi

# ---- 渲染（--dry-run 或 --client --yes 共用，需要客户端）---------------------
[ -n "$CLIENT" ] || { echo "需要 --client <名>（或 --list/--check）" >&2; exit 2; }
line="$(client_config_path "$CLIENT")"
[ -n "$line" ] || { echo "未知客户端：${CLIENT}（已知：${KNOWN_CLIENTS}）" >&2; exit 2; }
CFG_FILE="${line%%|*}"; CFG_KEY="${line##*|}"
ENTRY_JSON="$(build_entry_json)"

if [ "$MODE_DRY" = "1" ]; then
  echo "== Dry-run：将把以下条目合并进 $CFG_FILE 的 \"$CFG_KEY\" 下（server 名 rea）=="
  echo "（不写盘；写前会自动备份 .bak，且不删除其它 server 条目）"
  echo
  echo "$ENTRY_JSON"
  exit 0
fi

# ---- --client <名> --yes：真正写盘 ------------------------------------------
if [ "$MODE_YES" != "1" ]; then
  echo "这将修改 ${CFG_FILE}。确认请加 --yes（或先 --dry-run 预览）。" >&2
  exit 1
fi

mkdir -p "$(dirname "$CFG_FILE")"
[ -f "$CFG_FILE" ] && cp -a "$CFG_FILE" "$CFG_FILE.bak" && echo "已备份：$CFG_FILE.bak"

python3 - "$CFG_FILE" "$CFG_KEY" "$ENTRY_JSON" <<'PY'
import json, sys, os
path, key, entry_raw = sys.argv[1], sys.argv[2], sys.argv[3]
entry = json.loads(entry_raw)
data = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}
if not isinstance(data, dict):
    data = {}
data.setdefault(key, {})
data[key]["rea"] = entry   # 只合并/更新 rea，不动其它条目
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print(f"已写入：{path}（{key}.rea）")
PY

echo "完成。请重启 $CLIENT 让 MCP server 生效；可用 bash scripts/mcp-setup.sh --check 自检。"

#!/usr/bin/env bash
# =============================================================================
# web-analyze.sh —— 给一个 URL/网站，一键做被动逆向观察
#
# 这是 REA「网站分析」能力的一键封装。REA 通过 CDP（Chrome DevTools
# Protocol）被动 attach 一个【你自己已经打开目标页的】Chrome 系浏览器，
# 产出结构化 Evidence（DOM 结构、脚本/资源清单、网络/console/WebSocket
# 观察、JS bundle 静态解析、视口截图）。REA 不替你启动/导航/关闭浏览器。
#
# 用法：
#   scripts/web-analyze.sh --doctor
#       检查本机浏览器、CDP 端点、rea CLI 是否就绪，并打印"如何用调试
#       端口起浏览器"的现成命令。
#
#   scripts/web-analyze.sh --cdp http://127.0.0.1:9222 [--origin https://example.com]
#                          [--out DIR] [--deep] [--bundle] [--screenshot]
#                          [--observation-ms 1000]
#       attach 已开着目标页的浏览器，做一次完整观察并把 Evidence JSON 落盘。
#
#   scripts/web-analyze.sh --har 文件.har
#       离线复盘 HAR 抓包（请求/响应、暴露的 payload 与源码位置）。
#
# 前置（一次）：用独立 profile + 调试端口起浏览器，手动打开目标 URL：
#   google-chrome --remote-debugging-port=9222 \
#     --user-data-dir=/tmp/rea-browser-profile \
#     --password-store=basic "https://example.com"
#   （Chromium/Brave 同理；macOS 用 .app/Contents/MacOS 下的可执行文件）
#
# 注意：
#   - CDP endpoint 只认 loopback：http://127.0.0.1:PORT（不接受 localhost /
#     带路径 / 带凭证）。--origin 只写 scheme+host+port。
#   - 这是被动观察，不是浏览器自动化/沙箱；只看你授权的站点，用专用 profile。
#
# 退出码：0 成功；2 参数错；10 缺依赖（浏览器/rea 不可用）；12 CDP 不可达
#          或观察失败；1 其他未归类错误。
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/../lib/common.sh" 2>/dev/null || true
# shellcheck source=lib/exitcodes.sh
[ -f "$HERE/../lib/exitcodes.sh" ] && . "$HERE/../lib/exitcodes.sh"
RC_OK="${RC_OK:-0}"; RC_USAGE="${RC_USAGE:-2}"; RC_DEPENDENCY="${RC_DEPENDENCY:-10}"; RC_UPSTREAM="${RC_UPSTREAM:-12}"

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

REA_BIN="${REA_BIN:-npx -y rea-agents@${REA_VERSION:-6.5.0}}"

CDP=""
ORIGIN=""
OUT=""
DEEP=0
BUNDLE=0
SHOT=0
HAR=""
OBS_MS=1000
DOCTOR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --cdp) CDP="${2:-}"; shift 2 ;;
    --origin) ORIGIN="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --har) HAR="${2:-}"; shift 2 ;;
    --deep) DEEP=1; shift ;;
    --bundle) BUNDLE=1; shift ;;
    --screenshot|--shot) SHOT=1; shift ;;
    --observation-ms) OBS_MS="${2:-1000}"; shift 2 ;;
    --doctor) DOCTOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERR] 未知参数：${1}" >&2; usage; exit "$RC_USAGE" ;;
  esac
done

# 找本机可用的 Chrome 系浏览器（只探测，不启动）
find_browser() {
  local b
  for b in google-chrome google-chrome-stable chromium chromium-browser \
           microsoft-edge brave brave-browser; do
    if command -v "$b" >/dev/null 2>&1; then printf '%s' "$b"; return 0; fi
  done
  # macOS 典型路径
  for b in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
    [ -x "$b" ] && { printf '%s' "$b"; return 0; }
  done
  return 1
}

run_rea() {
  # shellcheck disable=SC2086
  $REA_BIN "$@"
}

if [ "$DOCTOR" = "1" ]; then
  echo "== web-analyze 环境检查 =="
  if B="$(find_browser)"; then
    echo "  [OK] 浏览器：${B}"
  else
    echo "  [缺] 未找到 Chrome 系浏览器（google-chrome/chromium/brave…）"
    echo "       Linux: sudo apt-get install -y chromium-browser"
    echo "       macOS: brew install --cask google-chrome"
  fi
  if command -v curl >/dev/null 2>&1; then echo "  [OK] curl"; else echo "  [缺] curl"; fi
  echo
  echo "== 用调试端口起浏览器（一次）=="
  cat <<'TIP'
  google-chrome --remote-debugging-port=9222 \
    --user-data-dir=/tmp/rea-browser-profile \
    --password-store=basic "https://你要分析的网站"
  # Chromium/Brave 同理；保持这个浏览器窗口开着，再回到本脚本观察。
TIP
  echo "== 然后跑 =="
  echo "  scripts/web-analyze.sh --cdp http://127.0.0.1:9222 --deep --bundle --screenshot"
  exit 0
fi

if [ -n "$HAR" ]; then
  [ -f "$HAR" ] || { echo "[ERR] HAR 文件不存在：${HAR}" >&2; exit "$RC_USAGE"; }
  echo "== 离线复盘 HAR：${HAR} =="
  run_rea analyze "$HAR" --format json
  exit "$?"
fi

[ -n "$CDP" ] || { echo "[ERR] 需要 --cdp http://127.0.0.1:PORT（或 --har 文件 / --doctor）" >&2; usage; exit "$RC_USAGE"; }
# CDP endpoint 只认 loopback（官方约束）
case "$CDP" in
  http://127.0.0.1:*|http://\[::1\]:*) : ;;
  *) echo "[ERR] CDP endpoint 只认 http://127.0.0.1:PORT（不接受 localhost/路径/凭证）：${CDP}" >&2; exit "$RC_USAGE" ;;
esac

# 探测 CDP 可达
if ! curl -s --max-time 5 "${CDP}/json/version" >/dev/null; then
  echo "[ERR] CDP 端点不可达：${CDP}（先用 --doctor 看怎么起浏览器）" >&2
  exit "$RC_UPSTREAM"
fi

OUT="${OUT:-/tmp/web-analyze-out}"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"

# 1) 列目标
echo "== 列浏览器目标（--origin ${ORIGIN:-全部}）=="
LIST_ARGS=( list-browser-targets "$CDP" --json )
[ -n "$ORIGIN" ] && LIST_ARGS+=( --allowed-origins "$ORIGIN" )
run_rea "${LIST_ARGS[@]}" > "$OUT/targets.json" || { echo "[ERR] list-browser-targets 失败" >&2; exit "$RC_UPSTREAM"; }
TID="$(python3 -c '
import json,sys
try:
    d=json.load(open("'"$OUT"'/targets.json"))
    ts=d.get("normalized_result",{}).get("targets",[])
    print(ts[0]["target_id"] if ts else "")
except Exception:
    print("")
')"
if [ -z "$TID" ]; then
  echo "[ERR] 没有可观察的页面目标。请确认浏览器里已打开 http(s) 页面（about:blank 会被排除），" >&2
  echo "      或用 --origin 缩小范围。targets.json 内容见 $OUT/targets.json" >&2
  exit "$RC_UPSTREAM"
fi
echo "  选中目标：${TID}"

# 2) inspect-web-page
INSPECT_ARGS=( inspect-web-page "$CDP" "$TID" --observation-ms "$OBS_MS" --json )
if [ "$DEEP" = "1" ]; then
  INSPECT_ARGS+=( --include-accessibility-text --include-console-text \
    --include-json-body-shapes --include-websocket-shapes --include-script-sources \
    --include-storage-keys --include-storage-fingerprints )
fi
echo "== 页面观察（inspect-web-page, 窗口 ${OBS_MS}ms）=="
run_rea "${INSPECT_ARGS[@]}" > "$OUT/inspect.json" || { echo "[ERR] inspect-web-page 失败" >&2; exit "$RC_UPSTREAM"; }
echo "  -> $OUT/inspect.json"

# 3) bundle 静态解析（可选）
if [ "$BUNDLE" = "1" ]; then
  echo "== JS bundle 静态解析（analyze-web-bundle，不执行代码）=="
  run_rea analyze-web-bundle "$CDP" "$TID" --json > "$OUT/bundle.json" \
    && echo "  -> $OUT/bundle.json" \
    || echo "  [warn] analyze-web-bundle 失败（页面可能无可解析脚本），跳过"
fi

# 4) 截图（可选）
if [ "$SHOT" = "1" ]; then
  echo "== 视口截图（capture-web-screenshot）=="
  run_rea capture-web-screenshot "$CDP" "$TID" --json > "$OUT/screenshot.json" \
    && echo "  -> $OUT/screenshot.json（base64 PNG 内嵌于 JSON）" \
    || echo "  [warn] 截图失败，跳过"
fi

echo
echo "完成。产物目录：${OUT}"
ls -1 "$OUT"

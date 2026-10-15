#!/usr/bin/env bash
# =============================================================================
# lib/exitcodes.sh — 命名退出码与机器可读错误输出（v4.1 新增）
#
# 本文件只被 source，不直接执行。提供：
#   - 命名退出码常量：
#       RC_OK=0            成功
#       RC_USAGE=2         用法/参数错误：未知参数、缺少/多余目标、--out 缺值等
#       RC_DEPENDENCY=10   缺少本地依赖：curl/unzip/tar 缺失、未找到 JDK21/
#                          Ghidra/满足版本要求的 Node
#       RC_CHECKSUM=11     校验和校验失败（SHA-256 不匹配）
#       RC_UPSTREAM=12    上游/资源不可用：下载失败、URL 不可达、目标二进制不存在、
#                          CPU 架构不受支持（环境不匹配）
#       RC_DISK=13         磁盘空间不足
#   - fatal <rc> <msg...>：
#       人类可读的 [ERR] 行照旧打到 stderr（沿用本项目既有日志风格）；
#       当 stderr 不是 TTY（CI / 管道 / 重定向）时，额外输出一行机器可读 JSON
#       envelope 到 stderr，供上层脚本与 CI 解析：
#         {"error":{"code":<数字>,"name":"RC_XXX","message":"<msg>","tool":"<脚本名>"}}
#   - die <msg...>：旧接口兼容，内部转调 fatal 1 <msg>。
#       退出码 1 = 未归类错误（历史行为保留，新代码请改用 fatal + 命名码）。
#
# bash 3.2 兼容（macOS 自带 bash）：无关联数组/mapfile/进程替换。
# =============================================================================

RC_OK=0
RC_USAGE=2
RC_DEPENDENCY=10
RC_CHECKSUM=11
RC_UPSTREAM=12
RC_DISK=13

# fatal <rc> <msg...>
#   参数 1 为命名退出码数字；其余参数拼接为错误消息。
#   消息可含中文/引号/特殊字符：JSON 侧统一用 python3 json.dumps 转义，保证安全。
fatal() {
  local rc="$1"; shift
  local msg="$*"
  local tool="${0##*/}"
  # 颜色若未由 common.sh 预置，按 stderr 是否 TTY 决定（允许不经 common.sh 直接 source 本文件）
  if [ -z "${C_RED:-}" ]; then
    if [ -t 2 ]; then C_RED='\033[31m'; C_RESET='\033[0m'; else C_RED=''; C_RESET=''; fi
  fi
  printf '%b[ERR]%b %s\n' "$C_RED" "$C_RESET" "$msg" >&2
  # 非 TTY（CI/管道/重定向）：额外输出一行机器可读 JSON envelope
  if [ ! -t 2 ]; then
    local name
    case "$rc" in
      "$RC_OK")         name="RC_OK" ;;
      "$RC_USAGE")      name="RC_USAGE" ;;
      "$RC_DEPENDENCY") name="RC_DEPENDENCY" ;;
      "$RC_CHECKSUM")   name="RC_CHECKSUM" ;;
      "$RC_UPSTREAM")   name="RC_UPSTREAM" ;;
      "$RC_DISK")       name="RC_DISK" ;;
      *)                name="RC_UNCLASSIFIED" ;;
    esac
    local json
    json="$(RC="$rc" NAME="$name" TOOL="$tool" MSG="$msg" python3 -c '
import os, json
print(json.dumps({
  "error": {
    "code": int(os.environ["RC"]),
    "name": os.environ["NAME"],
    "message": os.environ["MSG"],
    "tool": os.environ["TOOL"],
  }
}, ensure_ascii=False))' 2>/dev/null)" || json=""
    [ -n "$json" ] && printf '%s\n' "$json" >&2
  fi
  exit "$rc"
}

# die <msg...>：旧接口兼容——未归类错误统一走 fatal 1（历史退出码 1 保持不变）
die() { fatal 1 "$*"; }

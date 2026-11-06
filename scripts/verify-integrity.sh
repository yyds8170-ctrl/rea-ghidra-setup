#!/usr/bin/env bash
# =============================================================================
# scripts/verify-integrity.sh — 离线工件依赖完整性验证（在 lib/checksums.sh 之上，
# 不修改它）
#
# 核对：
#   1) 离线目录中四个期望工件（版本来自 config/versions.env，只读）都存在；
#   2) 每个工件的实际 SHA-256 与 $OFFLINE_DIR/SHA256SUMS.txt 清单一致；
#   3) 清单条目与 versions.env 派生的期望文件名一一对应（版本漂移告警）。
#
# 签名/校验边界（如实打印，不夸大）：
#   - Node：上游官方 SHASUMS256.txt 提供哈希（非签名）；
#   - Adoptium JDK：官方提供 GPG 签名 + checksum；本脚本只核对离线包内哈希；
#   - Ghidra：GitHub release 提供 asset digest；本脚本只核对离线包内哈希；
#   - rea-agents tgz：npm registry 侧 integrity；本脚本只核对离线包内哈希；
#   - 离线 SHA256SUMS.txt 本身由本仓库 prepare-offline.sh 生成，无上游签名——
#     即“仅哈希校验，无签名”。
#
# 退出码：0 全部一致；1 任一缺失/不匹配/漂移。
# 用法：OFFLINE_DIR=/abs/offline bash scripts/verify-integrity.sh
# =============================================================================
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=config/versions.env
. "$REPO_ROOT/config/versions.env"

OFFLINE_DIR="${OFFLINE_DIR:-$REPO_ROOT/offline}"
MANIFEST="$OFFLINE_DIR/SHA256SUMS.txt"

FAIL=0

say()  { printf '%s\n' "$*"; }
ok()   { say "  OK   $*"; }
bad()  { say "  FAIL $*"; FAIL=1; }
warn() { say "  WARN $*"; }

say "== 离线工件完整性校验 =="
say "OFFLINE_DIR : $OFFLINE_DIR"
say "清单        : $MANIFEST"
say

# 期望工件清单（文件名由锁定版本派生）
declare -a EXPECTED=(
  "jdk21-linux-x64.tar.gz"
  "node-v${REA_NODE_VERSION}-linux-x64.tar.gz"
  "ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip"
  "rea-agents-${REA_VERSION}.tgz"
)

if [ ! -d "$OFFLINE_DIR" ]; then
  bad "离线目录不存在：$OFFLINE_DIR"
  say; say "边界：未验证任何工件（仅哈希校验，无签名）。"
  exit 1
fi
if [ ! -f "$MANIFEST" ]; then
  bad "缺少离线清单 SHA256SUMS.txt"
  exit 1
fi

# 清单内容读到关联数组：name -> hash（bash 4+；本脚本只在 CI/开发机 bash5+ 跑）
declare -A MAN
while read -r h n; do
  [ -n "${h:-}" ] && [ -n "${n:-}" ] && MAN["$n"]="$h"
done < "$MANIFEST"

say "-- 逐件核对（期望 vs 实际 SHA-256）--"
for name in "${EXPECTED[@]}"; do
  f="$OFFLINE_DIR/$name"
  if [ ! -f "$f" ]; then
    bad "$name 缺失"
    continue
  fi
  want="${MAN[$name]:-}"
  if [ -z "$want" ]; then
    warn "$name 不在 SHA256SUMS.txt 中（版本漂移？），跳过哈希比对"
    FAIL=1
    continue
  fi
  have="$(sha256sum "$f" | awk '{print $1}')"
  if [ "$have" = "$want" ]; then
    ok "$name sha256 一致"
  else
    bad "$name sha256 不匹配"
    say "        期望: $want"
    say "        实际: $have"
  fi
done

say
say "-- 反向核对：清单里有、但 versions.env 未派生到的条目 --"
for n in "${!MAN[@]}"; do
  known=0
  for e in "${EXPECTED[@]}"; do [ "$n" = "$e" ] && known=1 && break; done
  if [ "$known" -eq 0 ]; then
    warn "清单含未跟踪工件：$n（版本漂移或多余文件）"
    FAIL=1
  fi
done

say
say "== 签名/校验边界 =="
say "  * 四个工件均只做本地 SHA-256 比对；SHA256SUMS.txt 由本仓库脚本生成，无上游签名。"
say "  * Node 上游仅提供 SHASUMS256.txt（哈希），无 GPG 签名。"
say "  * Adoptium JDK / Ghidra GitHub release / npm registry 上游另有签名或 attestation，"
say "    本脚本不联网拉取，故未验证签名；仅哈希校验，无签名。"
say

if [ "$FAIL" -eq 0 ]; then
  say "结果：全部工件哈希一致。"
  exit 0
else
  say "结果：存在失败项，见上。"
  exit 1
fi

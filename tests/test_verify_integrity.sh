#!/usr/bin/env bash
# =============================================================================
# tests/test_verify_integrity.sh — scripts/verify-integrity.sh 负向/安全回归（离线）
#
# 不复制 850MB 真工件：在临时目录造 4 个小夹具（文件名与 versions.env 派生一致），
# 按真实 SHA256SUMS.txt 格式生成清单。三类场景：
#   (a) 篡改工件一个字节   -> 检出哈希不符、非 0、点名文件
#   (b) 删除某个工件       -> 报缺失、非 0
#   (c) 篡改清单本身       -> 哈希不符/清单缺失项，非 0
# 另测：夹具完好时退出 0（正向基线）。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"

# shellcheck source=../config/versions.env
. "$REPO_ROOT/config/versions.env"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 造一套完好夹具：4 个期望文件名 + 对应清单
make_fixture() {
  local d="$1"
  rm -rf "$d"; mkdir -p "$d"
  printf 'fake-jdk-bytes\n'    > "$d/jdk21-linux-x64.tar.gz"
  printf 'fake-node-bytes\n'  > "$d/node-v${REA_NODE_VERSION}-linux-x64.tar.gz"
  printf 'fake-ghidra-bytes\n' > "$d/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip"
  printf 'fake-rea-bytes\n'    > "$d/rea-agents-${REA_VERSION}.tgz"
  (cd "$d" && sha256sum -- *.tar.gz *.zip *.tgz > SHA256SUMS.txt)
}

# 跑 verify-integrity.sh；$1=离线目录；回传 rc，输出进 $VI_OUT
VI_OUT=""
run_vi() {
  VI_OUT="$(OFFLINE_DIR="$1" bash "$REPO_ROOT/scripts/verify-integrity.sh" 2>&1)"
  return $?
}

# ---- 基线：完好夹具必须退出 0 ----
make_fixture "$WORK/good"
run_vi "$WORK/good"; rc=$?
assert_rc 0 "$rc" "完好夹具 verify-integrity 退出 0"

# ---- (a) 篡改工件一个字节 ----
make_fixture "$WORK/tamper"
printf 'X' >> "$WORK/tamper/rea-agents-${REA_VERSION}.tgz"
run_vi "$WORK/tamper"; rc=$?
assert_rc 1 "$rc" "篡改工件字节 -> 退出非 0"
assert_contains "rea-agents-${REA_VERSION}.tgz" "$VI_OUT" "报告中点名被篡改文件"
assert_contains "不匹配" "$VI_OUT" "报告指出哈希不匹配"

# ---- (b) 删除某个工件 ----
make_fixture "$WORK/missing"
rm -f "$WORK/missing/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip"
run_vi "$WORK/missing"; rc=$?
assert_rc 1 "$rc" "删除工件 -> 退出非 0"
assert_contains "ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" "$VI_OUT" "报告中点名缺失文件"
assert_contains "缺失" "$VI_OUT" "报告指出缺失"

# ---- (c1) 篡改清单里某条哈希（翻转一个十六进制字符）----
make_fixture "$WORK/manip"
mf="$WORK/manip/SHA256SUMS.txt"
# 把第一行哈希的首字符 0->1（若已是 1 则 1->0）
first="$(awk 'NR==1{print substr($1,1,1)}' "$mf")"
if [ "$first" = "0" ]; then repl=1; else repl=0; fi
awk -v r="$repl" 'NR==1{$1=r substr($1,2)}1' "$mf" > "$mf.tmp" && mv "$mf.tmp" "$mf"
run_vi "$WORK/manip"; rc=$?
assert_rc 1 "$rc" "清单哈希被篡改 -> 退出非 0"
assert_contains "不匹配" "$VI_OUT" "报告指出哈希不匹配"

# ---- (c2) 从清单删掉一个条目（期望工件不在清单中）----
make_fixture "$WORK/delentry"
grep -v 'jdk21-linux-x64.tar.gz' "$WORK/delentry/SHA256SUMS.txt" > "$WORK/delentry/SHA256SUMS.txt.tmp" \
  && mv "$WORK/delentry/SHA256SUMS.txt.tmp" "$WORK/delentry/SHA256SUMS.txt"
run_vi "$WORK/delentry"; rc=$?
assert_rc 1 "$rc" "清单删除条目 -> 退出非 0"
assert_contains "jdk21-linux-x64.tar.gz" "$VI_OUT" "报告点名缺失清单条目的工件"

tests_done

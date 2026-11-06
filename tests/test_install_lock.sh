#!/usr/bin/env bash
# =============================================================================
# tests/test_install_lock.sh — lib/install-lock.sh 原子锁/自愈单元测试
#
# 在临时 TOOLS_DIR 上驱动：A 正常拿锁/放锁；B 死锁（残留死 PID）自动接管；
# C 活锁（另一 install.sh 进程持锁）→ fatal RC_BUSY=14；D 半成品自愈。
# 不下载任何大文件。
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=harness.sh
. "$HERE/harness.sh"
# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A. 正常获取 + 释放
TD="$WORK/tools"; mkdir -p "$TD"
acquire_install_lock "$TD" >/dev/null
if [ -d "$TD/.install.lock" ] && [ -s "$TD/.install.lock/pid" ]; then
  printf 'PASS %s\n' "A1 拿锁后锁目录与 pid 文件存在"; T_PASS=$((T_PASS+1))
else
  printf 'FAIL %s\n' "A1 拿锁后锁目录与 pid 文件存在"; T_FAIL=$((T_FAIL+1))
fi
release_install_lock
if [ ! -e "$TD/.install.lock" ]; then
  printf 'PASS %s\n' "A2 release 后锁目录删除"; T_PASS=$((T_PASS+1))
else
  printf 'FAIL %s\n' "A2 release 后锁目录删除"; T_FAIL=$((T_FAIL+1))
fi

# B. 死锁自愈：残留锁里写一个必死的 PID
TDB="$WORK/tools-b"; mkdir -p "$TDB"
mkdir "$TDB/.install.lock"
echo "999999" > "$TDB/.install.lock/pid"
acquire_install_lock "$TDB" >"$WORK/b.log" 2>&1 || true
newpid="$(cat "$TDB/.install.lock/pid" 2>/dev/null || true)"
if [ "$newpid" != "999999" ] && [ -n "$newpid" ]; then
  printf 'PASS %s\n' "B1 死锁被接管，pid 换成本进程"; T_PASS=$((T_PASS+1))
else
  printf 'FAIL %s\n' "B1 死锁被接管，pid 换成本进程"; T_FAIL=$((T_FAIL+1)); printf '     pid=%s\n' "$newpid" >&2
fi
release_install_lock

# C. 活锁冲突：另一个名为 install.sh 的真进程持锁 -> 我方 fatal RC_BUSY(14)
TDC="$WORK/tools-c"; mkdir -p "$TDC"
FAKE="$WORK/fakebin"; mkdir -p "$FAKE"
cat > "$FAKE/install.sh" <<EOF
#!/usr/bin/env bash
. "$REPO_ROOT/lib/common.sh"
acquire_install_lock "$TDC" >/dev/null
sleep 3
release_install_lock
EOF
bash "$FAKE/install.sh" &
HOLDER=$!
sleep 0.8   # 等假安装器拿稳锁
rc=0
( acquire_install_lock "$TDC" ) >/dev/null 2>&1 || rc=$?
wait "$HOLDER" 2>/dev/null || true
assert_rc 14 "$rc" "活锁冲突返回 RC_BUSY=14"
release_install_lock 2>/dev/null || true
rm -rf "$TDC/.install.lock"

# D. self_heal_partial
PARTIAL="$TDB/ghidra_12.1.4_PUBLIC"; mkdir -p "$PARTIAL/Ghidra/Features"
COMPLETE="$TDB/jdk-21demo"; mkdir -p "$COMPLETE/bin"; touch "$COMPLETE/bin/java"
self_heal_partial "$PARTIAL" support/analyzeHeadline
self_heal_partial "$COMPLETE" bin/java
if [ ! -e "$PARTIAL" ]; then
  printf 'PASS %s\n' "D1 缺标志的半成品目录被清理"; T_PASS=$((T_PASS+1))
else
  printf 'FAIL %s\n' "D1 缺标志的半成品目录被清理"; T_FAIL=$((T_FAIL+1))
fi
if [ -e "$COMPLETE/bin/java" ]; then
  printf 'PASS %s\n' "D2 标志齐全的完整目录保留"; T_PASS=$((T_PASS+1))
else
  printf 'FAIL %s\n' "D2 标志齐全的完整目录保留"; T_FAIL=$((T_FAIL+1))
fi

tests_done

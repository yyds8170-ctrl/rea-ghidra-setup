#!/usr/bin/env bash
# =============================================================================
# scripts/selftest-install-lock.sh — 安装原子锁 + 半成品自愈自检（v4.2 新增）
#
# 不下载任何大文件：在临时 TOOLS_DIR 上直接驱动 lib/install-lock.sh。
# 覆盖：
#   A. 正常获取锁 → 锁目录带 pid
#   B. 活锁冲突：另一进程持锁时，本进程应 fatal RC_BUSY(14)
#   C. 死锁自愈：残留锁里 PID 已不存在 → 告警后接管、不阻塞
#   D. self_heal_partial：半成品目录被删、完整目录保留
# 全部通过退出 0，任一失败退出 1。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

PASS=0; FAIL=0
ok()   { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== A. 正常获取安装锁 =="
TD1="$WORK/tools1"; mkdir -p "$TD1"
acquire_install_lock "$TD1"
if [ -d "$TD1/.install.lock" ] && [ -s "$TD1/.install.lock/pid" ]; then
  ok "拿到锁且 pid 文件已写"
else
  bad "锁/pid 缺失"
fi
release_install_lock
if [ ! -e "$TD1/.install.lock" ]; then
  ok "释放后锁目录已删"
else
  bad "释放后锁残留"
fi

echo "== B. 活锁冲突 → RC_BUSY=14 =="
TD2="$WORK/tools2"; mkdir -p "$TD2"
# 用一个真正名为 install.sh 的脚本持锁：它是独立 bash 进程，$$ 即自身 PID，
# cmdline 含 install.sh，正好命中活锁判定（fatal RC_BUSY）。
FAKE="$WORK/fakebin"; mkdir -p "$FAKE"
cat > "$FAKE/install.sh" <<EOF
#!/usr/bin/env bash
source "$REPO_ROOT/lib/common.sh"
acquire_install_lock "$TD2"
sleep 3
release_install_lock
EOF
bash "$FAKE/install.sh" &
HOLDER=$!
sleep 0.7   # 等假安装器拿锁
# 主进程再次拿锁：应被 fatal RC_BUSY 中止。fatal 内部是 exit，须在子 shell 里跑才能用 || 捕获退出码。
rc=0
( acquire_install_lock "$TD2" ) || rc=$?
wait "$HOLDER" 2>/dev/null || true
if [ "$rc" -eq 14 ]; then
  ok "活锁冲突正确退出 RC_BUSY=14（实际 ${rc}）"
else
  bad "活锁应退 14，实际 ${rc}"
fi
release_install_lock 2>/dev/null || true
rm -rf "$TD2/.install.lock"

echo "== C. 死锁自愈（残留 pid 已不存在） =="
TD3="$WORK/tools3"; mkdir -p "$TD3"
mkdir "$TD3/.install.lock"
# 写一个几乎必然已死的 PID（999999），模拟上次崩溃残留
echo "999999" > "$TD3/.install.lock/pid"
acquire_install_lock "$TD3" 2>&1 | tee "$WORK/c.log" || true
if grep -q '残留锁' "$WORK/c.log"; then
  ok "打印死锁接管告警"
else
  bad "缺死锁告警"
fi
if [ -d "$TD3/.install.lock" ] && [ "$(cat "$TD3/.install.lock/pid")" != "999999" ]; then
  ok "接管后锁归本进程（pid 已更新）"
else
  bad "接管失败"
fi
release_install_lock

echo "== D. self_heal_partial =="
# 半成品：目录在但缺标志文件
PARTIAL="$TD3/ghidra_12.1.4_PUBLIC"; mkdir -p "$PARTIAL/Ghidra/Features"
# 完整目录：标志文件存在
COMPLETE="$TD3/jdk-21demo"; mkdir -p "$COMPLETE/bin"; touch "$COMPLETE/bin/java"
self_heal_partial "$PARTIAL" support/analyzeHeadless
self_heal_partial "$COMPLETE" bin/java
if [ ! -e "$PARTIAL" ]; then
  ok "半成品目录已被清理"
else
  bad "半成品未清理"
fi
if [ -e "$COMPLETE/bin/java" ]; then
  ok "完整目录保留未动"
else
  bad "完整目录被误删"
fi

echo
echo " 结果：$PASS 通过 / $FAIL 失败（install-lock）"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

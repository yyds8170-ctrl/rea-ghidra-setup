#!/usr/bin/env bash
# =============================================================================
# lib/install-lock.sh — 安装原子锁 + 半成品自愈（v4.2 新增）
#
# 本文件只被 source，不直接执行。依赖 lib/exitcodes.sh（fatal / RC_*）。
#
# 解决两类并发/中断问题：
#   1) 并发安装互相破坏：两个 install.sh 同时往同一个 TOOLS_DIR 解压 JDK/Ghidra，
#      会交错写盘、残留半截目录、current 软链指错。这里用「mkdir 目录」作为
#      POSIX 原子锁（mkdir 在同一父目录下创建唯一目录是原子的）。
#   2) 上次安装被 Ctrl-C / kill -9 中断：残留半截解压目录（缺标志二进制）或
#      死锁文件。下次安装时：死锁自动接管（不阻塞用户），半成品目录在解压前
#      自动清理（self_heal_partial），让重装干净重下。
#
# 提供：
#   acquire_install_lock <tools_dir>
#       拿到锁。若已有活锁（另一安装进程在跑）→ fatal RC_BUSY(14)。
#       若是死锁（上次崩溃残留，PID 已不在）→ 告警后自动接管。
#       成功后把 PID 写入 <tools_dir>/.install.lock/pid。
#   release_install_lock
#       释放锁（通常由安装器的 EXIT trap 自动调用）。
#   self_heal_partial <dir> <marker_relpath>
#       若 <dir> 存在但 <dir>/<marker> 缺失（上次解压到一半的半成品），删除它，
#       使后续解压落到干净目录。
#
# bash 3.2 兼容（macOS 自带 bash）：无关联数组/mapfile/进程替换。
# =============================================================================

INSTALL_LOCK_DIR=""

# acquire_install_lock <tools_dir>
acquire_install_lock() {
  local tools_dir="$1"
  INSTALL_LOCK_DIR="$tools_dir/.install.lock"

  # mkdir 是原子的：并发竞争只有一个会成功。
  if mkdir "$INSTALL_LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$INSTALL_LOCK_DIR/pid" 2>/dev/null || true
    date -u +%FT%TZ > "$INSTALL_LOCK_DIR/started" 2>/dev/null || true
    log "已获取安装锁：$INSTALL_LOCK_DIR"
    return 0
  fi

  # 锁已存在——判断是活锁（另一安装在跑）还是死锁（上次崩溃残留）。
  local other_pid=""
  [ -f "$INSTALL_LOCK_DIR/pid" ] && other_pid="$(cat "$INSTALL_LOCK_DIR/pid" 2>/dev/null || true)"

  if [ -n "$other_pid" ] && kill -0 "$other_pid" 2>/dev/null; then
    local cmd=""
    if [ -r "/proc/$other_pid/cmdline" ]; then
      cmd="$(tr '\0' ' ' < "/proc/$other_pid/cmdline" 2>/dev/null || true)"
    else
      cmd="$(ps -o command= -p "$other_pid" 2>/dev/null || true)"
    fi
    # PID 还活着且确实是本项目安装器 → 活锁，拒绝并发。
    case "$cmd" in
      *install.sh*|*install-macos.sh*)
        fatal "$RC_BUSY" "检测到另一个安装进程（PID ${other_pid}）正在操作 ${tools_dir}。为避免互相破坏安装，请等它结束或终止它；若确认当前无安装在跑，请手动删除 ${INSTALL_LOCK_DIR} 后重试。"
        ;;
    esac
  fi

  # 死锁：上次安装被中断、PID 已不在。告警后接管，不阻塞用户。
  warn "发现上次安装未正常退出的残留锁（PID ${other_pid:-未知} 已不存在），自动清理并继续。"
  rm -rf "$INSTALL_LOCK_DIR"
  mkdir "$INSTALL_LOCK_DIR" || fatal "$RC_BUSY" "无法获取安装锁 $INSTALL_LOCK_DIR"
  echo "$$" > "$INSTALL_LOCK_DIR/pid" 2>/dev/null || true
  log "已获取安装锁（接管自残留死锁）"
}

# release_install_lock
release_install_lock() {
  if [ -n "$INSTALL_LOCK_DIR" ]; then
    rm -rf "$INSTALL_LOCK_DIR" 2>/dev/null || true
    INSTALL_LOCK_DIR=""
  fi
}

# self_heal_partial <dir> <marker_relpath>
#   <dir> 存在但 <dir>/<marker> 缺失 = 上次解压到一半的半成品 → 删除后重装干净。
self_heal_partial() {
  local dir="$1" marker="$2"
  if [ -d "$dir" ] && [ ! -e "$dir/$marker" ]; then
    warn "[自愈] 检测到上次中断的半成品目录（缺 ${marker}），已清理：${dir}"
    rm -rf "$dir"
  fi
}

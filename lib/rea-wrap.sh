#!/usr/bin/env bash
# =============================================================================
# lib/rea-wrap.sh — v5.4.0 统一 REA 命令包装器（bash，仅被 source）
#
# 在 REA（rea-agents CLI）之上叠加一层：统一环境解析 + 包装器开关 + 稳定退出码。
# 运行时只依赖入库基线 config/command-baseline/command-domain.tsv（175 行），
# 不依赖 gitignored 的 research/。
#
# 提供：
#   rea_tsv_lookup <cmd>     打印 "domain<TAB>testability"；命令不在基线返回 1
#   rea_domains_table        打印 "domain<TAB>count"（10 行）
#   rea_domain_dispatch <dlabel> <cmd> [开关] [-- 透传...]
#                            dlabel=d1..d10；校验命令确属该领域后执行
#   rea_wrap_exec <cmd> [开关] [-- 透传...]
#                            真正的包装执行：校验→前置解析→调用 REA→映射退出码
#
# 包装器开关（在透传前解析；`--` 之后全部原样透传给 REA）：
#   --json              强制追加 --format json
#   --schema            透传 REA 的 --schema
#   --out <file>        把 REA 的 stdout 落盘到 <file>（自动建父目录）；
#                       不给则 stdout 原样透出
#   --quiet             压制 REA 的 stderr（包装器自身的错误信息仍走 stderr）
#   --                  其后所有参数原样透传给 REA
#
# 退出码（本包装器在 REA 之上叠加的稳定分类；REA 原生只有 0/1）：
#   0 成功
#   2 用法错误（命令不在基线 / 包装器开关错误 / 缺包装器必填值——调用 npx 前判定）
#   3 前置缺失（1-core-native 命令解析不到 JDK21 或 Ghidra——不调用 npx）
#   4 运行时失败（REA 已被执行但返回非 0）
#
# 注意：2/3/4 是本包装器根据预检查与 REA 退出码映射产生的分类，
#       并非 REA 原生返回码（REA 自身只返回 0 与 1）。
# =============================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIB_DIR/.." && pwd)"
COMMAND_DOMAIN_TSV="$REPO_ROOT/config/command-baseline/command-domain.tsv"

# 复用 common.sh：版本加载 / resolve_jdk_home / resolve_ghidra_dir / rea_mode
# shellcheck source=lib/common.sh
. "$LIB_DIR/common.sh"
load_versions

# ---- TSV 查询 ----------------------------------------------------------------
# 打印 "domain<TAB>testability"；找不到返回 1。命令名整词匹配第 1 列。
rea_tsv_lookup() {
  local cmd="$1"
  [ -f "$COMMAND_DOMAIN_TSV" ] || return 1
  awk -F'\t' -v c="$cmd" '$1==c { print $2"\t"$3; found=1 } END { exit(found?0:1) }' \
    "$COMMAND_DOMAIN_TSV"
}

# 打印 "domain<TAB>count"（10 行，按 domain 排序）
rea_domains_table() {
  awk -F'\t' '{ cnt[$2]++ } END { for (d in cnt) printf "%s\t%d\n", d, cnt[d] }' \
    "$COMMAND_DOMAIN_TSV" | sort
}

# d1..d10 标签 → 领域名
rea_domain_label_of() {
  case "$1" in
    d1)  printf '1-core-native' ;;
    d2)  printf '2-offline-binary' ;;
    d3)  printf '3-dynamic-debug' ;;
    d4)  printf '4-web-js-electron' ;;
    d5)  printf '5-android-adb' ;;
    d6)  printf '6-apple' ;;
    d7)  printf '7-multiformat' ;;
    d8)  printf '8-firmware-embedded' ;;
    d9)  printf '9-evidence-engineering' ;;
    d10) printf '10-platform-jeb' ;;
  esac
}

# ---- 解析环境（与 verify.sh 一致）---------------------------------------------
# 成功解析到 JDK/Ghidra 就 export；解析不到不在这里报错（是否硬失败由调用方定）。
# 返回 0。副作用：export JAVA_HOME / GHIDRA_INSTALL_DIR / PATH（仅当解析到）。
rea_resolve_env() {
  local jh gd
  jh="$(resolve_jdk_home || true)"
  [ -n "$jh" ] && export JAVA_HOME="$jh"
  gd="$(resolve_ghidra_dir || true)"
  [ -n "$gd" ] && export GHIDRA_INSTALL_DIR="$gd"
  [ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"
}

# 构造 REA 调用数组（全局 rea 优先；否则 npx 锁定版本；cn 模式注入 npmmirror）
# 结果放到全局 REA_WRAP_REA（数组）。
rea_build_argv() {
  if command -v rea >/dev/null 2>&1; then
    REA_WRAP_REA=(rea)
  else
    REA_WRAP_REA=(npx -y "rea-agents@${REA_VERSION}")
    if [ "$(rea_mode)" = "cn" ]; then
      REA_WRAP_REA=(env npm_config_registry="$REA_NPM_MIRROR_REGISTRY" "${REA_WRAP_REA[@]}")
    fi
  fi
}

# ---- 核心：执行包装 ----------------------------------------------------------
# rea_wrap_exec <cmd> [--json] [--schema] [--out <file>] [--quiet] [--] [透传...]
rea_wrap_exec() {
  local cmd="${1:-}"
  shift || true

  local force_json=0 want_schema=0 quiet=0 out_file=""
  local passthrough=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --) shift; passthrough=("$@"); break ;;
      --json)   force_json=1; shift ;;
      --schema) want_schema=1; shift ;;
      --quiet)  quiet=1; shift ;;
      --out)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
          echo "rea-wrap: --out 需要一个文件路径参数" >&2; return 2
        fi
        out_file="$2"; shift 2 ;;
      --out=*) out_file="${1#--out=}"; shift ;;
      *)
        echo "rea-wrap: 未知包装器开关：$1" >&2
        echo "        可用：--json --schema --out <file> --quiet --（其后透传 REA）" >&2
        return 2 ;;
    esac
  done

  # 1) 命令必须在基线（TSV 第 1 列），否则用法错误（退出 2，不调用 npx）
  [ -n "$cmd" ] || { echo "rea-wrap: 缺少命令名（用 run <命令>）" >&2; return 2; }
  local rec dom
  if ! rec="$(rea_tsv_lookup "$cmd")"; then
    echo "rea-wrap: 未知命令：$cmd（不在 rea-agents ${REA_VERSION} 基线的 175 个命令内）" >&2
    return 2
  fi
  IFS=$'\t' read -r dom _ <<<"$rec"

  # 2) 前置解析：d1 原生分析命令硬需要 JDK21 + Ghidra，缺一则退出 3（不调用 npx）；
  #    其余领域 best-effort 解析并 export（doctor/providers 等会读到），缺失不阻断。
  rea_resolve_env
  if [ "$dom" = "1-core-native" ]; then
    if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME:-/nonexistent}/bin/java" ]; then
      echo "rea-wrap: 命令 '$cmd' 属于 1-core-native，需要 JDK 21，但未解析到可用 JAVA_HOME（请先运行 ./rea-ghidra install）" >&2
      return 3
    fi
    if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -x "${GHIDRA_INSTALL_DIR:-/nonexistent}/support/analyzeHeadless" ]; then
      echo "rea-wrap: 命令 '$cmd' 属于 1-core-native，需要 Ghidra，但未解析到 GHIDRA_INSTALL_DIR（请先运行 ./rea-ghidra install）" >&2
      return 3
    fi
  fi

  # 3) 构造 REA 调用
  rea_build_argv

  # 注入开关放在透传参数之后，使 --json / --schema 对 REA 具权威性
  local injected=()
  [ "$force_json" = 1 ] && injected+=(--format json)
  [ "$want_schema" = 1 ] && injected+=(--schema)

  local final=("$cmd")
  if [ "${#passthrough[@]}" -gt 0 ]; then final+=("${passthrough[@]}"); fi
  if [ "${#injected[@]}" -gt 0 ];    then final+=("${injected[@]}");    fi

  # 4) 执行：--out 落盘 / 否则透出 stdout；--quiet 压制 REA stderr
  local rc=0
  if [ -n "$out_file" ]; then
    local parent
    parent="$(dirname "$out_file")"
    mkdir -p "$parent" || { echo "rea-wrap: 无法创建 --out 目录：$parent" >&2; return 2; }
    if [ "$quiet" = 1 ]; then
      "${REA_WRAP_REA[@]}" "${final[@]}" >"$out_file" 2>/dev/null
    else
      "${REA_WRAP_REA[@]}" "${final[@]}" >"$out_file"
    fi
    rc=$?
  else
    if [ "$quiet" = 1 ]; then
      "${REA_WRAP_REA[@]}" "${final[@]}" 2>/dev/null
    else
      "${REA_WRAP_REA[@]}" "${final[@]}"
    fi
    rc=$?
  fi

  # 5) 退出码映射：REA 原生 0=成功 / 1=一切错误；非 0 一律归为运行时失败(4)
  if [ "$rc" -eq 0 ]; then
    return 0
  else
    echo "rea-wrap: REA 执行 '$cmd' 返回非 0（rc=$rc）" >&2
    return 4
  fi
}

# ---- 领域路由：d1..d10 入口 --------------------------------------------------
# rea_domain_dispatch <dlabel=d1..d10> <cmd> [开关] [-- 透传...]
rea_domain_dispatch() {
  local dlabel="$1"; shift
  local expected cmd
  expected="$(rea_domain_label_of "$dlabel")"
  cmd="${1:-}"
  [ -n "$cmd" ] || { echo "rea-wrap: $dlabel 缺少命令名（用 ./rea-ghidra $dlabel <命令>）" >&2; return 2; }

  local rec dom
  if ! rec="$(rea_tsv_lookup "$cmd")"; then
    echo "rea-wrap: 未知命令：$cmd（不在 rea-agents ${REA_VERSION} 基线的 175 个命令内）" >&2
    return 2
  fi
  IFS=$'\t' read -r dom _ <<<"$rec"
  if [ "$dom" != "$expected" ]; then
    echo "rea-wrap: 命令 '$cmd' 属于领域 '$dom'，不是 '$expected'" >&2
    echo "        （用 ./rea-ghidra run $cmd 直接跑，或选对应 dN 领域入口）" >&2
    return 2
  fi
  shift   # 去掉 cmd，余下 = 包装器开关 + 透传
  rea_wrap_exec "$cmd" "$@"
}

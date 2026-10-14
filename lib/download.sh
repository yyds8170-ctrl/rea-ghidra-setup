#!/usr/bin/env bash
# =============================================================================
# lib/download.sh — 统一、健壮的「下载」内核（Linux / macOS / WSL / Crostini）
#
# 只被 source（由 lib/common.sh 引入）。提供：
#   - download <out> <url...>   多源 failover 下载到 <out>
#   - github_proxy_urls <raw>   生成「官方直连 + GitHub 代理前缀」候选 URL 列表
#
# 设计要点：
#   1) 指数退避重试：交给 curl `--retry`（自带指数退避），次数可用 REA_DL_RETRIES 覆盖。
#   2) 连接超时（REA_DL_CONNECT_TIMEOUT，默认 15s）与总超时（REA_DL_MAX_TIME，
#      默认 1800s，大文件可放宽）。
#   3) 断点续传：优先 `curl -fL -C -`，对「本地临时文件已与远端等大」产生的
#      HTTP 416 / curl exit 33 视为成功；无 curl 时回退 `wget -c`。
#   4) 先下到 <out>.part，成功后原子 `mv` 到 <out>，避免半截文件被当成成功。
#   5) 多源 failover：逐个尝试候选 URL；前一个失败（连接失败/非 2xx/后续校验失败）
#      才换下一个；换源时删除上一源留下的 .part（不可信），重新拉取。
#   6) bash 3.2 兼容：只用普通索引数组/位置参数，禁关联数组、mapfile、`|&`。
#   7) curl 新参数（--retry-connrefused 7.52+、--retry-all-errors 7.71+）先用
#      `curl --help all` 探测，老 curl 不支持就不加，避免报错。
#   8) 代理：不硬编码；curl/wget 本就读 http_proxy/https_proxy/no_proxy。这里把
#      大写写法（HTTP_PROXY/HTTPS_PROXY/NO_PROXY）在小写未设置时补导一份，
#      因为 curl 默认只认小写 http_proxy。
#
# 环境变量（均可覆盖）：
#   REA_DL_RETRIES          单源重试次数（默认 5）
#   REA_DL_CONNECT_TIMEOUT  连接超时秒数（默认 15）
#   REA_DL_MAX_TIME         单源总超时秒数（默认 1800）
#   REA_GITHUB_PROXIES      GitHub release 代理前缀列表（逗号/分号/空格分隔）；
#                           设为 none 或空则只走官方；未设置时内置 https://gh-proxy.com/
# =============================================================================

# ---- 默认值（调用方已 export 的优先）------------------------------------------
: "${REA_DL_RETRIES:=5}"
: "${REA_DL_CONNECT_TIMEOUT:=15}"
: "${REA_DL_MAX_TIME:=1800}"

# ---- 规范透传代理：curl 只认小写，把大写写法补过去（不覆盖已有小写）-----------
[ -z "${http_proxy:-}" ]  && [ -n "${HTTP_PROXY:-}" ]  && export http_proxy="$HTTP_PROXY"
[ -z "${https_proxy:-}" ] && [ -n "${HTTPS_PROXY:-}" ] && export https_proxy="$HTTPS_PROXY"
[ -z "${no_proxy:-}" ]    && [ -n "${NO_PROXY:-}" ]    && export no_proxy="$NO_PROXY"

# 探测 curl 是否支持某参数（老 curl 没有 --retry-all-errors 等）
_dl_curl_supports() {
  command -v curl >/dev/null 2>&1 || return 1
  curl --help all 2>/dev/null | grep -q -- "$1"
}

# 取远端文件字节数（用 Range: bytes=0-0 的 GET，跟随重定向；不依赖 HEAD）。
# 优先解析 206 的 Content-Range 总长度，其次回退 Content-Length。失败返回 0。
_dl_remote_size() {
  local url="$1"
  curl -sL -D - -o /dev/null \
    --connect-timeout "$REA_DL_CONNECT_TIMEOUT" --max-time 60 \
    -H "Range: bytes=0-0" "$url" 2>/dev/null \
  | awk '
      tolower($0) ~ /^content-range:/ {
        n = split($0, a, "/")
        if (n >= 2) { gsub(/[^0-9]/, "", a[n]); tot = a[n] }
      }
      tolower($0) ~ /^content-length:/ && tot == "" { v = $2; gsub(/[^0-9]/, "", v); tot = v }
      END { print tot + 0 }
    '
}

# 用 curl 把单个 URL 下载到 <out>.part（带续传），成功后原子 mv 到 <out>。
# 返回 0 成功；非 0 该源失败（.part 由调用方决定是否清理）。
_dl_one_curl() {
  local out="$1" url="$2" part="$3"
  local flags=( --fail --location --show-error
                --connect-timeout "$REA_DL_CONNECT_TIMEOUT"
                --max-time "$REA_DL_MAX_TIME"
                --retry "$REA_DL_RETRIES"
                --retry-delay 2
                -C - )
  if _dl_curl_supports --retry-connrefused; then
    flags+=( --retry-connrefused )
  fi
  if _dl_curl_supports --retry-all-errors; then
    flags+=( --retry-all-errors )
  fi
  echo "[下载] $url"
  curl "${flags[@]}" -o "$part" "$url"
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    if [ -s "$part" ]; then mv -f "$part" "$out"; return 0; fi
    echo "[下载失败] $url 未产出任何数据" >&2
    return 1
  fi

  # rc=22（--fail 把 HTTP 错误转为 22）或 rc=33（range error）：
  # 若本地 .part 已与远端等大，说明是“续传一个其实已下完的文件”→ 416，视为成功。
  # 否则是真·HTTP 错误（404/500/中途失败），失败。后续还有 SHA-256 强校验兜底。
  if [ "$rc" -eq 22 ] || [ "$rc" -eq 33 ]; then
    local rsize lsize
    rsize="$(_dl_remote_size "$url")"
    if [ -n "$rsize" ] && [ "$rsize" != "0" ] && [ -s "$part" ]; then
      lsize="$(wc -c < "$part" | tr -d '[:space:]')"
      if [ "$lsize" = "$rsize" ]; then
        echo "[续传] 本地文件已完整（HTTP ${rc}），直接落地" >&2
        mv -f "$part" "$out"
        return 0
      fi
    fi
  fi
  echo "[下载失败] ${url}（curl exit ${rc}）" >&2
  return 1
}

# wget 回退（无 curl 时）。wget -c 自带断点续传。
_dl_one_wget() {
  local out="$1" url="$2" part="$3"
  echo "[下载] ${url}（wget）"
  wget -c --tries="$REA_DL_RETRIES" \
       --timeout="$REA_DL_CONNECT_TIMEOUT" \
       -O "$part" "$url"
  local rc=$?
  # wget 0 成功；4 = 网络失败但可能已下完，按非空兜底
  if [ "$rc" -eq 0 ] && [ -s "$part" ]; then
    mv -f "$part" "$out"
    return 0
  fi
  echo "[下载失败] ${url}（wget exit ${rc}）" >&2
  return 1
}

# 多源 failover 下载。$1=目标路径，其余=候选 URL（按顺序尝试）。
# 成功返回 0 并产出完整 <out>；全部失败返回非 0，且不留半截 <out>。
download() {
  local out="$1"; shift
  local url part ok=0
  [ -n "$out" ] || { echo "download: 缺少目标路径" >&2; return 2; }
  mkdir -p "$(dirname "$out")"
  part="${out}.part"

  local url tried=0
  for url in "$@"; do
    [ -z "$url" ] && continue
    # 换源时才清理上一源留下的（可能不可信的）.part；首轮保留既有 .part，
    # 以便续传上次崩溃残留的半成品（curl -C - 据此断点续传，416 当成功）。
    if [ "$tried" -eq 1 ]; then
      rm -f "$part"
    fi
    tried=1
    if command -v curl >/dev/null 2>&1; then
      _dl_one_curl "$out" "$url" "$part" && { ok=1; break; }
    elif command -v wget >/dev/null 2>&1; then
      _dl_one_wget "$out" "$url" "$part" && { ok=1; break; }
    else
      echo "既无 curl 也无 wget，无法下载" >&2
      rm -f "$part"
      return 2
    fi
  done

  if [ "$ok" -eq 1 ]; then
    return 0
  fi
  rm -f "$part"
  echo "[下载失败] 所有候选源均失败：$*" >&2
  return 2
}

# 生成 GitHub release 的候选下载 URL 列表（官方直连在前，代理前缀在后）。
# $1 = 原始 GitHub 下载 URL。echo 出空格分隔的列表（URL 不含空格，调用方不加引号展开）。
# 代理只用于公开 release，且最终仍须经上游 SHA-256 强校验。
github_proxy_urls() {
  local raw="$1"
  local list="$raw"
  local override="${REA_GITHUB_PROXIES-}"
  # 未设置时内置默认代理；设为 none/空则只走官方
  if [ -z "$override" ]; then
    override="https://gh-proxy.com/"
  fi
  if [ "$override" != "none" ]; then
    local norm p
    # 把分号/空格统一成逗号再逐个拆分（bash 3.2 兼容）
    norm="$(printf '%s' "$override" | tr '; ' ',')"
    local IFS=','
    for p in $norm; do
      p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -n "$p" ] && list="$list $p$raw"
    done
  fi
  printf '%s' "$list"
}

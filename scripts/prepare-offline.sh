#!/usr/bin/env bash
# =============================================================================
# scripts/prepare-offline.sh — 在【有网】机器上准备离线安装包（Linux / macOS）
#
# 产物目录（默认 ./offline，可用 OUT_DIR 覆盖）：
#   jdk21-<os>-<arch>.tar.gz      Temurin JDK 21（按当前机器架构）
#   node-v<ver>-<os>-<arch>.tar.gz  便携 Node 22
#   ghidra_<ver>_PUBLIC_<date>.zip   Ghidra 跨平台 zip
#   rea-agents-<ver>.tgz            （可选）npm 打包的 rea-agents，供离线全局安装
#   SHA256SUMS.txt                  上述全部文件的 SHA-256 清单（目标机离线强校验）
#   MANIFEST.txt                    版本、OS、架构、生成时间
#
# 在【离线】目标机上：
#   OFFLINE_DIR=/path/to/offline bash install.sh        # Linux
#   OFFLINE_DIR=/path/to/offline bash install-macos.sh  # macOS
#
# 说明：
#   - 本脚本在联网环境运行，会逐一比对【上游官方校验和】，任一不匹配即中止，
#     因此生成的离线包是可信的；目标机再用 SHA256SUMS.txt 离线校验。
#   - Ghidra 校验和来自 GitHub release API（匿名可能限流），如失败请设置
#     GH_TOKEN（GITHUB_TOKEN）。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=lib/checksums.sh
source "$SCRIPT_DIR/../lib/checksums.sh"
load_versions

OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/../offline}"
UNAME_S="$(uname -s)"; ARCH="$(normalize_arch)"
case "$UNAME_S" in
  Linux)  JDK_OS=linux; NODE_OS=linux; JDK_PKG="jdk21-linux-${ARCH}.tar.gz" ;;
  Darwin) JDK_OS=mac;   NODE_OS=darwin; JDK_PKG="jdk21-mac-${ARCH}.tar.gz" ;;
  *) echo "prepare-offline 仅支持 Linux/macOS（Windows 用 prepare-offline.ps1）" >&2; exit 1 ;;
esac
NODE_PKG="$(node_tarball_dir "$NODE_OS" "$ARCH").tar.gz"
GHIDRA_PKG="$(ghidra_zip_name)"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
echo "=========================================================="
echo " 准备离线安装包（$JDK_OS / ${ARCH}）"
echo " 输出目录：$OUT_DIR"
echo " 版本：Ghidra $GHIDRA_VERSION / JDK $JDK_FEATURE / Node $REA_NODE_VERSION / REA $REA_VERSION"
echo "=========================================================="

# 下载并比对上游期望哈希；参数：name url expected
dl_and_verify() {
  local name="$1" url="$2" expected="$3"
  if [ -z "$expected" ]; then
    echo "无法获取 $name 的上游校验和（限流/离线？）。Ghidra 可设置 GH_TOKEN 后重试。" >&2
    return 1
  fi
  if [ -f "$name" ] && cs_verify "$name" "$expected"; then
    echo "[已存在且校验通过] $name"
    return 0
  fi
  echo "[下载] $name"
  curl -fSL --retry 3 "$url" -o "$name"
  if cs_verify "$name" "$expected"; then
    echo "[校验一致] $name"
  else
    echo "[校验失败] $name" >&2
    echo "  期望：$expected" >&2
    echo "  实际：$(cs_sha256 "$name")" >&2
    rm -f "$name"; return 1
  fi
}

# ---- JDK -------------------------------------------------------------------
JDK_EXPECTED="$(cs_expected_jdk "$JDK_FEATURE" "$JDK_OS" "$ARCH")"
dl_and_verify "$JDK_PKG" "$(adoptium_jdk_url "$JDK_OS" "$ARCH")" "$JDK_EXPECTED"

# ---- Node ------------------------------------------------------------------
NODE_EXPECTED="$(cs_expected_node "$REA_NODE_VERSION" "$NODE_PKG")"
dl_and_verify "$NODE_PKG" "$(node_tarball_url "$NODE_OS" "$ARCH")" "$NODE_EXPECTED"

# ---- Ghidra ----------------------------------------------------------------
GHIDRA_EXPECTED="$(cs_expected_ghidra "$GHIDRA_BUILD" "$GHIDRA_PKG")"
dl_and_verify "$GHIDRA_PKG" "$(ghidra_release_url)" "$GHIDRA_EXPECTED"

# ---- rea-agents（npm 打包，供离线全局安装）---------------------------------
if command -v npm >/dev/null 2>&1; then
  echo "[npm pack] rea-agents@${REA_VERSION}"
  npm pack "rea-agents@${REA_VERSION}" --silent >/dev/null 2>&1 || \
    echo "[警告] npm pack rea-agents 失败（不影响 JDK/Ghidra 离线安装）" >&2
else
  echo "[跳过] 未检测到 npm，未打包 rea-agents"
fi

# ---- 生成清单（离线机据此强校验）-------------------------------------------
echo "[清单] 生成 SHA256SUMS.txt"
: > SHA256SUMS.txt
for f in *.tar.gz *.tgz *.zip; do
  [ -e "$f" ] || continue
  cs_sha256 "$f" | awk -v n="$f" '{print $1"  "n}' >> SHA256SUMS.txt
done

cat > MANIFEST.txt <<EOF
REA + Ghidra 离线安装包
generated_at : $(date -u +%Y-%m-%dT%H:%M:%SZ)
os           : $JDK_OS
arch         : $ARCH
ghidra       : $GHIDRA_VERSION
jdk_feature  : $JDK_FEATURE
node         : $REA_NODE_VERSION
rea          : $REA_VERSION
files:
$(awk '{print "  "$2}' SHA256SUMS.txt)

离线目标机安装：
  OFFLINE_DIR=$(pwd) bash install.sh          # Linux
  OFFLINE_DIR=$(pwd) bash install-macos.sh    # macOS
全局离线安装 REA（如已打包 rea-agents tgz）：
  npm install --global rea-agents-*.tgz
EOF

echo
echo "完成。离线包目录：$OUT_DIR"
echo "传输到目标机后：OFFLINE_DIR=<目录> bash install.sh"

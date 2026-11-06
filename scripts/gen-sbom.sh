#!/usr/bin/env bash
# =============================================================================
# scripts/gen-sbom.sh — 可复现地生成 SPDX 2.3 JSON SBOM（离线）
#
# 清点本仓库离线随附的四个工件：
#   JDK21(Temurin) / Ghidra / 便携 Node / rea-agents(npm tgz)
# 事实来源：
#   版本  : config/versions.env（只读，不修改）+ VERSION
#   哈希  : $OFFLINE_DIR/SHA256SUMS.txt（prepare-offline.sh 产出；不存在则组件
#           不挂 checksum，如实标注）
#
# 可复现性：
#   - 组件顺序、字段顺序由 python json sort_keys 固定；
#   - created 时间取自 SOURCE_DATE_EPOCH（未设则 git HEAD committer 时间，
#     再不行 epoch），同一份工作树两次运行字节级一致。
#
# 用法：
#   OFFLINE_DIR=/path/to/offline bash scripts/gen-sbom.sh [output.spdx.json]
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- 读版本（只读）----------------------------------------------------------
# shellcheck source=../config/versions.env
. "$REPO_ROOT/config/versions.env"
WRAPPER_VERSION="$(cat "$REPO_ROOT/VERSION")"

OFFLINE_DIR="${OFFLINE_DIR:-$REPO_ROOT/offline}"
MANIFEST="$OFFLINE_DIR/SHA256SUMS.txt"
OUT="${1:-$REPO_ROOT/packaging/rea-ghidra-setup.spdx.json}"

# 确定性 created 时间（worktree 里 .git 是文件，不能用 -d 探测；直接问 git）
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  CREATED_EPOCH="$SOURCE_DATE_EPOCH"
else
  CREATED_EPOCH="$(git -C "$REPO_ROOT" log -1 --format=%ct 2>/dev/null || printf '0')"
fi
CREATED="$(date -u -d "@${CREATED_EPOCH}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "${CREATED_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)"

GHIDRA_ZIP="ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip"
NODE_TGZ="node-v${REA_NODE_VERSION}-linux-x64.tar.gz"
JDK_TGZ="jdk21-linux-x64.tar.gz"
REA_TGZ="rea-agents-${REA_VERSION}.tgz"

mkdir -p "$(dirname "$OUT")"

WRAPPER_VERSION="$WRAPPER_VERSION" \
GHIDRA_VERSION="$GHIDRA_VERSION" GHIDRA_BUILD="$GHIDRA_BUILD" GHIDRA_DATE="$GHIDRA_DATE" \
GHIDRA_ZIP="$GHIDRA_ZIP" JDK_FEATURE="$JDK_FEATURE" \
REA_NODE_VERSION="$REA_NODE_VERSION" REA_VERSION="$REA_VERSION" \
NODE_TGZ="$NODE_TGZ" JDK_TGZ="$JDK_TGZ" REA_TGZ="$REA_TGZ" \
MANIFEST="$MANIFEST" CREATED="$CREATED" \
python3 - "$OUT" <<'PY'
import json, os, sys

out = sys.argv[1]

# 解析离线清单：hash -> name（不存在则空映射，组件不挂 checksum）
checksums = {}
manifest = os.environ["MANIFEST"]
if os.path.isfile(manifest):
    with open(manifest, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) >= 2:
                checksums[parts[1]] = parts[0].lower()

def pkg(spdxid, name, version, supplier, download, license_expr, basename, summary):
    p = {
        "SPDXID": spdxid,
        "name": name,
        "versionInfo": version,
        "supplier": supplier,
        "downloadLocation": download,
        "filesAnalyzed": False,
        "licenseConcluded": license_expr,
        "copyrightText": "NOASSERTION",
        "comment": summary,
    }
    cs = checksums.get(basename)
    if cs:
        p["checksums"] = [{"algorithm": "SHA256", "checksumValue": cs}]
    else:
        p["comment"] = (summary + " | 离线清单未提供该工件哈希，checksum 字段省略").strip(" |")
    return p

packages = [
    pkg(
        "SPDXRef-Package-wrapper", "rea-ghidra-setup", os.environ["WRAPPER_VERSION"],
        "Organization: rea-ghidra-setup",
        "NONE",
        "PolyForm-Noncommercial-1.0.0",
        "",
        "本仓库：JDK21+Ghidra+Node+rea-agents 的离线安装/封装器（PolyForm Noncommercial）。",
    ),
    pkg(
        "SPDXRef-Package-jdk", "Eclipse Temurin OpenJDK", os.environ["JDK_FEATURE"],
        "Organization: Eclipse Adoptium",
        "https://api.adoptium.net/v3/binary/latest/%s/ga/linux/x64/jdk/hotspot/normal/eclipse" % os.environ["JDK_FEATURE"],
        "GPL-2.0-only WITH Classpath-exception-2.0",
        os.environ["JDK_TGZ"],
        "JDK 主版本锁 21（Ghidra 12.x 要求）；确切 patch 安装时由 Adoptium GA 决定。",
    ),
    pkg(
        "SPDXRef-Package-ghidra", "NSA Ghidra", os.environ["GHIDRA_VERSION"],
        "Organization: National Security Agency",
        "https://github.com/NationalSecurityAgency/ghidra/releases/download/%s/%s"
        % (os.environ["GHIDRA_BUILD"], os.environ["GHIDRA_ZIP"]),
        "Apache-2.0",
        os.environ["GHIDRA_ZIP"],
        "逆向分析平台；build=%s date=%s。" % (os.environ["GHIDRA_BUILD"], os.environ["GHIDRA_DATE"]),
    ),
    pkg(
        "SPDXRef-Package-node", "Node.js", os.environ["REA_NODE_VERSION"],
        "Organization: Node.js Foundation",
        "https://nodejs.org/dist/v%s/%s" % (os.environ["REA_NODE_VERSION"], os.environ["NODE_TGZ"]),
        "MIT",
        os.environ["NODE_TGZ"],
        "便携 Node；满足 rea-agents 6.8 engines（^22.23.4 || ^24.22.1 || >=26.12.1）。",
    ),
    pkg(
        "SPDXRef-Package-rea", "rea-agents", os.environ["REA_VERSION"],
        "Organization: npmjs/rea-agents maintainers",
        "https://registry.npmjs.org/rea-agents/-/rea-agents-%s.tgz" % os.environ["REA_VERSION"],
        "NOASSERTION",
        os.environ["REA_TGZ"],
        "npm 包；离线随附 tgz，license 未在本 SBOM 中断言（未读取包内 LICENSE）。",
    ),
]

doc = {
    "spdxVersion": "SPDX-2.3",
    "dataLicense": "CC0-1.0",
    "SPDXID": "SPDXRef-DOCUMENT",
    "name": "rea-ghidra-setup %s offline bundle (linux/x64)" % os.environ["WRAPPER_VERSION"],
    "documentNamespace": "https://rea-ghidra-setup.local/spdx/reproducible/v%s/offline-linux-x64"
                         % os.environ["WRAPPER_VERSION"],
    "creationInfo": {
        "created": os.environ["CREATED"],
        "creators": ["Tool: rea-ghidra-setup/scripts/gen-sbom.sh"],
        "licenseListVersion": "3.25",
    },
    "documentDescribes": ["SPDXRef-Package-wrapper"],
    "packages": packages,
    "relationships": [
        {"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES",
         "relatedSpdxElement": "SPDXRef-Package-wrapper"},
        {"spdxElementId": "SPDXRef-Package-wrapper", "relationshipType": "DEPENDS_ON",
         "relatedSpdxElement": "SPDXRef-Package-jdk"},
        {"spdxElementId": "SPDXRef-Package-wrapper", "relationshipType": "DEPENDS_ON",
         "relatedSpdxElement": "SPDXRef-Package-ghidra"},
        {"spdxElementId": "SPDXRef-Package-wrapper", "relationshipType": "DEPENDS_ON",
         "relatedSpdxElement": "SPDXRef-Package-node"},
        {"spdxElementId": "SPDXRef-Package-wrapper", "relationshipType": "DEPENDS_ON",
         "relatedSpdxElement": "SPDXRef-Package-rea"},
    ],
}

with open(out, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False, indent=2, sort_keys=True)
    fh.write("\n")
print("SBOM written:", out)
PY

echo "离线清单: $MANIFEST $([ -f "$MANIFEST" ] && echo '(存在)' || echo '(缺失：组件 checksum 已省略)')"

# =============================================================================
# REA + Ghidra 容器镜像（默认 linux/amd64；arm64 见 docs/platform-docker.md）
#
# 含：Temurin JDK 21、Node 22、Ghidra、全局安装的 rea、技能与脚本。
# 所有版本号集中在 config/versions.env（单一事实源），本文件不再硬编码版本。
# 无需在本机安装任何依赖，docker 构建即可。
#
# 构建：docker build -t rea-ghidra .
# 使用：docker run --rm -v "$PWD:/workspace" rea-ghidra \
#         analyze ./demo --provider ghidra --format json
#
# 注：官方 Ghidra 多平台包在 amd64 自带 native decompiler；arm64
# （os/linux_arm_64）官方不预编译，需自行 make ghidra_opt 构建，
# 见 docs/platform-docker.md 与 README 故障排查。
# =============================================================================
FROM ubuntu:24.04

# 版本号单一事实源（GHIDRA_* / JDK_FEATURE / NODE_VERSION / REA_VERSION）
COPY config/versions.env /opt/versions.env

ENV DEBIAN_FRONTEND=noninteractive

# 基础工具：下载 / 解压 / 编译
# libc6-dev / python3 显式安装（--no-install-recommends 不会自动带入）：
# libc6-dev 提供 stdio.h，python3 供 verify.sh 解析 JSON
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip xz-utils gcc make libc6-dev python3 \
    && rm -rf /var/lib/apt/lists/*

# Temurin JDK 21（amd64；版本号取自 versions.env）
RUN set -eux; . /opt/versions.env; \
    curl -fSL "https://api.adoptium.net/v3/binary/latest/${JDK_FEATURE}/ga/linux/x64/jdk/hotspot/normal/eclipse" \
      -o /tmp/jdk.tar.gz; \
    mkdir -p /opt/tools; \
    tar -xzf /tmp/jdk.tar.gz -C /opt/tools; \
    ln -sfn /opt/tools/jdk-21* /opt/tools/jdk21; \
    rm -f /tmp/jdk.tar.gz

# Node 22（REA 要求 >=22.19）
RUN set -eux; . /opt/versions.env; \
    curl -fSL "https://nodejs.org/dist/v${REA_NODE_VERSION}/node-v${REA_NODE_VERSION}-linux-x64.tar.gz" \
      -o /tmp/node.tar.gz; \
    tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.gz; \
    node --version; npm --version

# Ghidra（跨平台 zip；版本号取自 versions.env），并建立版本无关软链
RUN set -eux; . /opt/versions.env; \
    curl -fSL "https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_BUILD}/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" \
      -o /tmp/ghidra.zip; \
    unzip -q /tmp/ghidra.zip -d /opt/tools; \
    ln -sfn "/opt/tools/ghidra_${GHIDRA_VERSION}_PUBLIC" /opt/tools/ghidra; \
    rm -f /tmp/ghidra.zip

# 全局安装 REA（容器内直接可用，不必每次 npx 下载）
RUN set -eux; . /opt/versions.env; \
    npm install --global "rea-agents@${REA_VERSION}"

# 项目技能 / 脚本 / 示例
COPY . /opt/rea-ghidra-setup

ENV JAVA_HOME=/opt/tools/jdk21
# 通过版本无关软链定位 Ghidra，升级版本时无需改 ENV
ENV GHIDRA_INSTALL_DIR=/opt/tools/ghidra
ENV PATH=/opt/tools/jdk21/bin:${PATH}

WORKDIR /workspace

# 验证安装（构建期即确认 provider 就绪）
RUN java -version 2>&1 | head -1; \
    test -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" && echo "Ghidra headless OK"; \
    rea --version 2>/dev/null || rea --help | head -1

ENTRYPOINT ["rea"]
CMD ["--help"]

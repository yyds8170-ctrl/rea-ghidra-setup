# =============================================================================
# REA + Ghidra 容器镜像（linux/amd64）
#
# 含：Temurin JDK 21、Node 22、Ghidra 12.1.4、全局安装的 rea、技能与脚本。
# 无需在本机安装任何依赖，docker 构建即可。
#
# 构建：docker build -t rea-ghidra .
# 使用：docker run --rm -v "$PWD:/workspace" rea-ghidra \
#         analyze ./demo --provider ghidra --format json
#
# 注：官方 Ghidra 多平台包在 amd64 自带 native decompiler；arm64 需自行
# 构建 native 组件（见 README 故障排查），本镜像默认面向 amd64。
# =============================================================================
FROM ubuntu:24.04

ARG GHIDRA_VERSION=12.1.4
ARG GHIDRA_BUILD=Ghidra_12.1.4_build
ARG GHIDRA_DATE=20260921
ARG NODE_VERSION=22.19.0
ARG REA_VERSION=6.4.0

ENV DEBIAN_FRONTEND=noninteractive

# 基础工具：下载 / 解压 / 编译
# libc6-dev / python3 显式安装（--no-install-recommends 不会自动带入）：
# libc6-dev 提供 stdio.h，python3 供 verify.sh 解析 JSON
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip xz-utils gcc make libc6-dev python3 \
    && rm -rf /var/lib/apt/lists/*

# Temurin JDK 21（amd64）
RUN set -eux; \
    curl -fSL "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse" \
      -o /tmp/jdk.tar.gz; \
    mkdir -p /opt/tools; \
    tar -xzf /tmp/jdk.tar.gz -C /opt/tools; \
    ln -s /opt/tools/jdk-21* /opt/tools/jdk21; \
    rm -f /tmp/jdk.tar.gz

# Node 22（REA 要求 >=22.19）
RUN set -eux; \
    curl -fSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" \
      -o /tmp/node.tar.gz; \
    tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.gz; \
    node --version; npm --version

# Ghidra 12.1.4
RUN set -eux; \
    curl -fSL "https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_BUILD}/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" \
      -o /tmp/ghidra.zip; \
    unzip -q /tmp/ghidra.zip -d /opt/tools; \
    rm -f /tmp/ghidra.zip

# 全局安装 REA（容器内直接可用，不必每次 npx 下载）
RUN npm install --global "rea-agents@${REA_VERSION}"

# 项目技能 / 脚本 / 示例
COPY . /opt/rea-ghidra-setup

ENV JAVA_HOME=/opt/tools/jdk21
ENV GHIDRA_INSTALL_DIR=/opt/tools/ghidra_${GHIDRA_VERSION}_PUBLIC
ENV PATH=/opt/tools/jdk21/bin:${PATH}

WORKDIR /workspace

# 验证安装（构建期即确认 provider 就绪）
RUN java -version 2>&1 | head -1; \
    test -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" && echo "Ghidra headless OK"; \
    rea --version 2>/dev/null || rea --help | head -1

ENTRYPOINT ["rea"]
CMD ["--help"]

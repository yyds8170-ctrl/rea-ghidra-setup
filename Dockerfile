# syntax=docker/dockerfile:1
# =============================================================================
# REA + Ghidra 容器镜像（多架构：linux/amd64 与 linux/arm64）
#
# 含：Temurin JDK 21、Node 24.22.0（versions.env 锁定）、Ghidra、全局安装的 rea、技能与脚本。
# 所有版本号集中在 config/versions.env（单一事实源）。
#
# 单架构构建：
#   docker build -t rea-ghidra .
# 多架构构建（buildx）：
#   docker buildx build --platform linux/amd64,linux/arm64 -t <repo>:tag .
#
# 关键点：Ghidra 官方 zip 只对 x86_64 预编译 native decompiler；
# linux/arm64（os/linux_arm_64）必须在镜像内用源码 make ghidra_opt 构建。
# QEMU 模拟下 arm64 编译很慢，CI 推荐用原生 arm64 runner（见 .github/workflows/ci.yml）。
# =============================================================================
FROM ubuntu:24.04

# buildx 自动注入 TARGETARCH（amd64 / arm64）
ARG TARGETARCH

# 版本号单一事实源（GHIDRA_* / JDK_FEATURE / REA_NODE_VERSION / REA_VERSION）
COPY config/versions.env /opt/versions.env

ENV DEBIAN_FRONTEND=noninteractive

# 基础工具：下载/解压；gcc/make/libc6-dev 供 verify.sh 编译 examples/demo
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip xz-utils gcc make libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Temurin JDK 21（按 TARGETARCH 选择 x64 / aarch64）
RUN set -eux; . /opt/versions.env; \
    case "$TARGETARCH" in arm64) JARCH=aarch64 ;; *) JARCH=x64 ;; esac; \
    curl -fSL "https://api.adoptium.net/v3/binary/latest/${JDK_FEATURE}/ga/linux/${JARCH}/jdk/hotspot/normal/eclipse" \
      -o /tmp/jdk.tar.gz; \
    mkdir -p /opt/tools; \
    tar -xzf /tmp/jdk.tar.gz -C /opt/tools; \
    ln -sfn /opt/tools/jdk-21* /opt/tools/jdk21; \
    rm -f /tmp/jdk.tar.gz

# Node（REA 要求 >=22.19；版本取自 versions.env REA_NODE_VERSION=24.22.0；按 TARGETARCH 选择 x64 / arm64）
RUN set -eux; . /opt/versions.env; \
    case "$TARGETARCH" in arm64) NARCH=arm64 ;; *) NARCH=x64 ;; esac; \
    curl -fSL "https://nodejs.org/dist/v${REA_NODE_VERSION}/node-v${REA_NODE_VERSION}-linux-${NARCH}.tar.gz" \
      -o /tmp/node.tar.gz; \
    tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.gz; \
    node --version; npm --version

# Ghidra（跨平台 zip，单一发布包），并建立版本无关软链
RUN set -eux; . /opt/versions.env; \
    curl -fSL "https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_BUILD}/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" \
      -o /tmp/ghidra.zip; \
    unzip -q /tmp/ghidra.zip -d /opt/tools; \
    ln -sfn "/opt/tools/ghidra_${GHIDRA_VERSION}_PUBLIC" /opt/tools/ghidra; \
    rm -f /tmp/ghidra.zip

# arm64：官方不含 linux_arm_64 native decompiler，镜像内从源码构建（与 scripts/build-ghidra-native.sh 同配方）
RUN set -eux; \
    if [ "$TARGETARCH" = "arm64" ]; then \
      apt-get update && apt-get install -y --no-install-recommends g++ bison make && rm -rf /var/lib/apt/lists/*; \
      GHIDRA_DIR="$(readlink -f /opt/tools/ghidra)"; \
      CPP="$GHIDRA_DIR/Ghidra/Features/Decompiler/src/decompile/cpp"; \
      DEST="$GHIDRA_DIR/Ghidra/Features/Decompiler/os/linux_arm_64"; \
      mkdir -p "$DEST"; \
      make -C "$CPP" ghidra_opt ARCH_TYPE="" OSDIR="linux_arm_64"; \
      install -m 755 "$CPP/ghidra_opt" "$DEST/decompile"; \
    fi

# 全局安装 REA（容器内直接可用，不必每次 npx 下载）
# --omit=optional：跳过 frida 等可选依赖（静态反编译用不到；受限网络下其
# prebuild 下载失败会触发极慢的源码编译）。需要运行时插桩/动态分析的
# 用户可自行 `npm i -g rea-agents` 全量安装。
RUN set -eux; . /opt/versions.env; \
    npm install --global --omit=optional "rea-agents@${REA_VERSION}"

# 项目技能 / 脚本 / 示例
COPY . /opt/rea-ghidra-setup

ENV JAVA_HOME=/opt/tools/jdk21
# 通过版本无关软链定位 Ghidra，升级版本时无需改 ENV
ENV GHIDRA_INSTALL_DIR=/opt/tools/ghidra
ENV PATH=/opt/tools/jdk21/bin:${PATH}

# ---- 非 root 用户（容器安全加固）----
# 固定 UID/GID=1001；创建可写 HOME（rea/node 缓存）、工作目录。
RUN set -eux; \
    groupadd --system --gid 1001 rea; \
    useradd  --system --uid 1001 --gid rea --create-home --home-dir /home/rea --shell /bin/bash rea; \
    mkdir -p /workspace; \
    # verify.sh 在仓库副本内编译 examples/demo，需让非 root 可写该副本；
    chown -R rea:rea /opt/rea-ghidra-setup /workspace /home/rea; \
    # /tmp 已 1777；显式给出用户可写的 tmp 兜底（只读 rootfs 时挂载）。
    mkdir -p /home/rea/tmp && chown -R rea:rea /home/rea/tmp
ENV HOME=/home/rea
ENV _JAVA_OPTIONS=-Djava.io.tmpdir=/tmp

# 构建期自检：analyzeHeadless 与对应架构的 native decompiler 必须就位（以 root 执行）
RUN set -eux; \
    java -version 2>&1 | head -1; \
    test -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless"; \
    test -x /usr/local/bin/rea; \
    case "$TARGETARCH" in \
      arm64) test -x "$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os/linux_arm_64/decompile" ;; \
      *)     test -x "$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os/linux_x86_64/decompile" ;; \
    esac; \
    echo "Ghidra headless + native decompiler + rea OK ($TARGETARCH)"

# 以非 root 用户运行
USER rea
WORKDIR /workspace

# 健康探针：本镜像为命令行工具、无常驻 daemon/端口，故只做关键文件存在性探针。
HEALTHCHECK --interval=60s --timeout=10s --start-period=10s --retries=3 \
  CMD test -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" && test -x /usr/local/bin/rea || exit 1

# OCI 标准标签
LABEL org.opencontainers.image.title="rea-ghidra-setup" \
      org.opencontainers.image.description="Noncommercial image bundling Ghidra + rea-agents (REA) for headless reverse-engineering" \
      org.opencontainers.image.url="https://github.com/yyds8170-ctrl/rea-ghidra-setup" \
      org.opencontainers.image.documentation="https://github.com/yyds8170-ctrl/rea-ghidra-setup#readme" \
      org.opencontainers.image.source="https://github.com/yyds8170-ctrl/rea-ghidra-setup" \
      org.opencontainers.image.licenses="PolyForm-Noncommercial-1.0.0" \
      org.opencontainers.image.vendor="yyds8170-ctrl"

ENTRYPOINT ["rea"]
CMD ["--help"]

# Docker 平台部署指南（linux/amd64 + linux/arm64）

> 容器镜像内置 **Temurin JDK 21 + Node 24.22.0 + Ghidra 12.1.4 + 全局 rea**，宿主无需安装任何依赖，
> 是 WSL2 / 云电脑 VDI / CI / 隔离环境中最省事的方式。镜像默认入口为 `rea`，工作目录 `/workspace`。

## 一、支持矩阵（Docker）

| 项 | linux/amd64 | linux/arm64 |
| --- | --- | --- |
| 镜像内 JDK 21 / Node 24.22.0 / Ghidra | ✅ | ✅（自动选 aarch64 包） |
| native decompiler | ✅ 官方预编译 `linux_x86_64` | 🟠 镜像内**源码构建** `linux_arm_64`（Dockerfile 自动完成） |
| 单架构 `docker build` | ✅ | ✅（在 arm64 机器上原生构建） |
| `buildx --platform` 多架构一次构建 | ✅ | 🟠 可在 amd64 上用 QEMU 模拟，但**编译 native 极慢**，建议原生 arm64 runner |
| 容器内 `verify.sh` | ✅ | ✅（构建后建议在 arm64 机器上跑一次） |

## 二、快速开始（amd64，最常见）

```bash
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup

# 构建镜像（当前主机架构）
docker build -t rea-ghidra .

# 分析当前目录下的二进制（把 $PWD 挂载到容器 /workspace）
docker run --rm -v "$PWD:/workspace" rea-ghidra analyze ./demo --provider ghidra --format json

# 反编译指定函数
docker run --rm -v "$PWD:/workspace" rea-ghidra decompile ./demo secret_check --provider ghidra

# 容器内跑端到端自检（编译 + 真实分析 + 9 项断言）
docker run --rm --entrypoint bash rea-ghidra /opt/rea-ghidra-setup/verify.sh
```

## 三、用 Docker Compose（推荐给非命令行重度用户）

仓库自带 [`docker-compose.yml`](../docker-compose.yml)：

```bash
docker compose build
docker compose run --rm rea analyze ./demo --provider ghidra --format json
docker compose run --rm rea decompile ./demo secret_check --provider ghidra
# 自检
docker compose run --rm --entrypoint bash rea /opt/rea-ghidra-setup/verify.sh
```

默认把**当前目录**挂载为容器 `/workspace`，把待分析目标放在当前目录即可；`GHIDRA_HEADLESS_MAXMEM`
等参数可通过环境变量或 `.env` 覆盖。

## 四、多架构镜像（amd64 + arm64）

Dockerfile 用 buildx 自动注入的 `TARGETARCH` 选择 JDK / Node 架构，并在 **arm64 镜像内
`make ghidra_opt` 构建 `os/linux_arm_64/decompile`**（官方 zip 不含该二进制）。

### 1. 在对应架构的机器上各自构建（最简单、最快）

```bash
# x86_64 主机
docker build -t rea-ghidra:amd64 .
# arm64 主机（Apple Silicon 用 Docker Desktop 的 Linux arm64；或 arm64 服务器）
docker build -t rea-ghidra:arm64 .
```

### 2. 在一台机器上用 buildx 交叉构建多架构

```bash
docker buildx create --use --name rea-builder
# 只构建不推送（加载到本地仅支持单平台；多平台需 --push 或 --output）
docker buildx build --platform linux/amd64,linux/arm64 -t <你的仓库>/rea-ghidra:latest --push .
```

> ⚠️ **QEMU 很慢**：在 x86 主机上交叉构建 `linux/arm64` 时，镜像内编译 Ghidra native C++
> 是在 QEMU 模拟下进行的，可能耗时 20 分钟以上且容易超时。推荐：
> - 用 **原生 arm64 runner/机器** 构建 arm64 镜像（本仓库 CI 的 `docker-arm64` 作业用
>   `ubuntu-24.04-arm`，无需 QEMU）；
> - 或为多架构构建配置 `cache-from/to` 复用缓存。
>
> 推送到自己的 registry 时，请把 `<你的仓库>` 换成真实地址（本项目不发布官方镜像）。

### 3. 强制拉取/运行某架构

```bash
# 在 Apple Silicon 上运行 amd64（Rosetta/QEMU，性能差，仅应急）
docker run --rm --platform linux/amd64 -v "$PWD:/workspace" rea-ghidra:latest doctor
# 或在 amd64 上模拟 arm64
DOCKER_DEFAULT_PLATFORM=linux/arm64 docker compose build
```

## 五、各运行环境（Docker 视角）

| 运行环境 | 用法与注意 |
| --- | --- |
| 物理本机（Linux） | 直接 `docker build` / `docker run`；最推荐 |
| 虚拟机 | 同物理机；注意虚拟机磁盘与内存（镜像约 2GB、Ghidra 堆默认 2G），嵌套虚拟化不影响普通容器 |
| WSL2 | 装 Docker Desktop（WSL2 后端）或在 WSL 发行版内 `curl get.docker.com`；`$PWD` 挂 `/workspace`，Windows 路径建议放在 `\\wsl$` 文件系统内（NTFS 挂载 IO 慢且有重解析点问题） |
| Docker 容器 | 即本文件；Crostini 里也可 `sudo apt install docker.io`（无 KVM，构建慢） |
| 云电脑（VDI） | 若平台不允许嵌套/本地 daemon，可使用其托管容器服务（AKS/ECS/自建）；只要能拉取并运行 OCI 镜像即可，分析在云端进行 |

## 六、调参与排障

- **内存（大二进制/受限主机）**：
  ```bash
  docker run --rm -e GHIDRA_HEADLESS_MAXMEM=512M -v "$PWD:/workspace" rea-ghidra analyze ./big --provider ghidra
  ```
- **启动超时**：`-e REA_GHIDRA_STARTUP_TIMEOUT_MS=600000`。
- **AppArmor 报错**（仅本地测试）：`docker run --security-opt apparmor=unconfined ...`。
- **挂载目录打不开/权限**：确认目标在挂载路径内；SELinux 发行版可加 `:z` 卷标记：`-v "$PWD:/workspace:z"`。
- **rootless Docker**：注意 `/dev` 与用户命名空间；本镜像只做 headless 分析，通常无需特权。
- **arm64 native 构建失败**：确认基础镜像里能装 `g++`/`bison`/`make`；或直接复用本仓库
  [`scripts/build-ghidra-native.sh`](../scripts/build-ghidra-native.sh) 在容器内手动执行。
- **不在容器里编译/运行 REA，只想批量反编译**：用 [`scripts/ghidra-decompile.sh`](../scripts/ghidra-decompile.sh)
  （`analyzeHeadless -postScript DecompileAll.java`，无需 Node）。

## 七、镜像里没有什么

- 不内置 Ghidra / JDK / Node 的二进制版权物以外的私有数据；Ghidra 为 Apache-2.0、JDK 为 Temurin（GPLv2+CE）、
  REA 为 MIT。
- 本项目许可证为 **PolyForm Noncommercial 1.0.0**；对外分发或商用镜像前请自行合规评估。

# 离线 / 内网（air-gapped）安装指南

> 适用场景：目标机不能访问外网（内网云电脑、保密环境、网络受限的虚拟机）。
> 思路：**在一台有网的机器上准备“已校验的离线包” → 拷贝到目标机 → 离线安装**。
> 所有下载物都先与上游官方校验和比对，再生成 `SHA256SUMS.txt`，目标机离线强校验。

## 一、离线包内容

| 文件 | 来源 | 校验和来源 |
| --- | --- | --- |
| `jdk21-<os>-<arch>.tar.gz` / `.zip` | Adoptium Temurin JDK 21 | Adoptium v3 assets JSON `package.checksum` |
| `node-v<ver>-<os>-<arch>.tar.gz` / `.zip` | Node 官方 | 官方 `SHASUMS256.txt` |
| `ghidra_<ver>_PUBLIC_<date>.zip` | Ghidra GitHub release | GitHub release asset `digest`（SHA-256） |
| `rea-agents-<ver>.tgz`（可选） | `npm pack rea-agents` | 纳入 `SHA256SUMS.txt` |
| `SHA256SUMS.txt` / `MANIFEST.txt` | 本工具生成 | 目标机据此离线校验 |

## 二、在有网机器上准备离线包

### Linux / macOS

```bash
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
# Ghidra 校验和走 GitHub API，匿名可能限流；如失败设置 token（可选）
export GH_TOKEN=ghp_xxx
bash scripts/prepare-offline.sh                 # 默认输出到 ./offline
```

按当前机器的 OS/架构准备（Linux x64 与 Apple Silicon 不同；请在与目标机同 OS/架构的机器上准备，
或手工改 `OUT_DIR` 并切换到对应架构的机器）。

### Windows x64

```powershell
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
$env:GH_TOKEN='ghp_xxx'      # 可选，避免 GitHub 限流
pwsh -ExecutionPolicy Bypass -File .\scripts\prepare-offline.ps1
```

### Docker（推荐给离线/内网）

离线环境最省事的是直接传镜像：

```bash
# 有网机器：构建并导出镜像（amd64 与 arm64 分别构建）
docker build -t rea-ghidra:2.2.0 .
docker save rea-ghidra:2.2.0 -o rea-ghidra-2.2.0.tar
# 拷到内网机器后：
docker load -i rea-ghidra-2.2.0.tar
```

多架构镜像仓库同样可以 `docker save/load`（按目标机架构构建对应 tag）。

## 三、在目标机离线安装

把整个 `offline/` 目录（连同仓库脚本，或把 `offline/` 放到仓库根目录）拷到目标机：

```bash
# Linux / macOS / WSL2 / Crostini
OFFLINE_DIR=/path/to/offline bash install.sh
OFFLINE_DIR=/path/to/offline bash install-macos.sh
```

```powershell
# Windows x64
$env:OFFLINE_DIR='C:\path\to\offline'; .\install.ps1
```

安装器会：优先使用离线目录中的同名文件 → 用 `SHA256SUMS.txt` 校验（不联网）→ 解压安装。
离线包里没有 `SHA256SUMS.txt` 时会给出警告；校验不匹配则**中止并删除文件**（防止损坏/篡改）。

### 离线安装 REA（rea-agents）

离线包含 `rea-agents-<ver>.tgz` 时：

```bash
npm install --global /path/to/offline/rea-agents-*.tgz
```

或在已能联网的机器上用 npm 缓存/私有 registry 镜像（如 Nexus/Verdaccio）分发。

## 四、校验和来源与可复现性

- **Node**：`https://nodejs.org/dist/v<ver>/SHASUMS256.txt`（含 GPG 签名 `.asc`）。
- **JDK**：`https://api.adoptium.net/v3/assets/latest/21/hotspot?os=...&architecture=...&image_type=jdk&vendor=eclipse`
  的 `binary.package.checksum`（Temurin 另有 GPG 签名）。
- **Ghidra**：GitHub release 资产的 `digest` 字段（`sha256:` 前缀），
  `GET /repos/NationalSecurityAgency/ghidra/releases/tags/<build>`；匿名访问受速率限制，
  失败时请带 `GH_TOKEN`/`GITHUB_TOKEN`。
- 安装器在线安装时也会做同样的校验（见 `lib/checksums.sh` / `lib/checksums.ps1`）：
  **能拿到校验和就强校验，不匹配即失败；离线且无清单时才警告放行**。

## 五、内网验证

离线安装后，目标机上跑：

```bash
bash scripts/doctor.sh      # 预检（不联网）
bash verify.sh              # 端到端：编译 demo + 真实分析 + 9 项断言（首次分析需 Ghidra 本地数据，不联网）
```

Windows 用 `doctor.ps1` / `verify.ps1`；Docker 用容器内 `verify.sh`。
verify 首次调用 `rea` 若使用 `npx` 会尝试联网，离线环境请先全局安装离线包内的 `rea-agents-*.tgz`，
或使用已装好 `rea` 的镜像。

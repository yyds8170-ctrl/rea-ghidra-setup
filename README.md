# REA + Ghidra 云电脑一键部署

[![CI](https://github.com/yyds8170-ctrl/rea-ghidra-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/yyds8170-ctrl/rea-ghidra-setup/actions/workflows/ci.yml)

在云电脑 / Linux 服务器上一键部署 **REA（Reverse Engineer Anything）+ Ghidra**，让 AI 智能体在没有源码的情况下分析二进制、App、抓包，产出带证据的结论。

- **REA**：`github.com/morluto/rea`，开源逆向编排框架（MCP server + CLI），MIT 协议
- **Ghidra**：`github.com/NationalSecurityAgency/ghidra`，NSA 开源反编译引擎，Apache-2.0
- 本仓库仅包含**安装/卸载/验证脚本、技能文件与使用文档**（不内置上述第三方二进制）

## 我该用哪个？（快速选择）

不确定时先运行 `bash scripts/detect-env.sh`（识别系统 / 架构 / 运行环境）。然后按系统选择：

| 系统 / 环境 | 安装 | 验证 | 说明 |
| --- | --- | --- | --- |
| Linux（物理机 / 虚拟机 / WSL2 / 云电脑） | `bash install.sh` | `bash verify.sh` | x86_64 完整；arm64 自动构建 native |
| Windows 10/11 x64（物理机 / 虚拟机 / VDI） | `.\install.ps1` | `.\verify.ps1` | 用户态免管理员；自带 PE fixture |
| macOS（Intel / Apple Silicon） | `bash install-macos.sh` | `bash verify-macos.sh` | Apple Silicon 自动构建 native、去隔离 |
| ChromeOS | 先开 Crostini，再 `bash install.sh` | `bash verify.sh` | 仅 x86_64 完整；arm64 需建 native |
| Docker（任意宿主） | `docker build -t rea-ghidra .` | 容器内 `verify.sh` | 支持 amd64/arm64；或 `docker compose` |

完整的「4 系统 × 5 运行环境」逐项状态见 [平台×环境支持矩阵](docs/platform-support-matrix.md)。

## 实测结果（2026-10，Ubuntu 22.04 x86_64 云电脑）

- JDK 21 + Ghidra 12.1.4 安装并通过 `rea doctor --provider ghidra` 全部检查（含 native decompiler）
- 对含校验/折扣逻辑的 ELF 程序反编译成功，`confidence: observed`，核心逻辑被完整还原。以下为真实输出：

```c
// rea decompile ./demo secret_check 的输出（Ghidra 12.1.4）
int secret_check(int code)
{
  int iVar1;
  int code_local;
  if (code == 0x539) {            // 0x539 = 1337（正确密码）
    iVar1 = 1;
  } else if (code < 0x2329) {     // 0x2329 = 9001
    iVar1 = 0;
  } else {
    iVar1 = 2;
  }
  return iVar1;
}
```

## 一键安装（Linux：物理机 / 虚拟机 / WSL2 / Crostini / 云电脑）

```bash
bash install.sh
source ~/.bashrc    # zsh 用户：source ~/.zshrc
```

> **国内网络用户**：下载慢/超时就用镜像加速（Node/JDK 走 npmmirror、华为云、TUNA，npm 走 npmmirror，仍过官方校验和）：
> ```bash
> REA_MIRROR=cn bash install.sh     # Windows: $env:REA_MIRROR='cn'; .\install.ps1
> ```
> 详见 [docs/mirrors.md](docs/mirrors.md)。默认 `auto` 会自动探测，海外/CI 不受影响。

- 无需 root，JDK 与 Ghidra 装在 `~/tools`，脚本幂等可重复运行；自动识别运行环境与 CPU 架构
- 安装前自动检查磁盘空间（`~/tools` 约 2.6GB、临时目录约 0.8GB）
- 环境要求：Linux **x86_64**（完整支持）或 **arm64**（自动构建 native decompiler）、`curl`、`unzip`、`tar`；REA 需 Node 22.19+ / 24.11+ / 26+（缺失时安装器自动装便携 Node 22）
- 物理机 / 虚拟机 / WSL2 / Docker / 云电脑各环境的差异与注意事项见 [docs/platform-linux.md](docs/platform-linux.md)
- **版本集中管理**：Ghidra / JDK / Node / REA 的锁定版本统一在 [`config/versions.env`](config/versions.env)，升级只改这一个文件；`bash scripts/check-versions.sh` 可检查一致性并探测上游最新版
- 临时覆盖版本仍可用环境变量：`GHIDRA_VERSION=12.1.4 GHIDRA_BUILD=Ghidra_12.1.4_build GHIDRA_DATE=20260921 bash install.sh`

> **其它操作系统 / 运行环境**：Windows、macOS、ChromeOS 以及虚拟机 / WSL /
> Docker / 云电脑（VDI）的安装与验证，请见 [docs/README.md](docs/README.md) 文档导航与
> [平台×环境支持矩阵](docs/platform-support-matrix.md)。

## 一键安装（Windows 10/11 x64，免管理员）

```powershell
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
powershell -ExecutionPolicy Bypass -File .\install.ps1   # 推荐 pwsh 7
# 重新打开终端后：
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

- JDK21 / Ghidra / 便携 Node 全部以**用户态 zip** 解压到 `%USERPROFILE%\tools`，只写用户级环境变量，**不需要管理员**
- Windows x64 的 `win_x86_64` native decompiler 为**官方预编译**；验证用仓库自带预编译 PE fixture，**不需要 C 编译器**
- 物理机 / 虚拟机 / 云电脑 VDI / ARM64（受限）等差异见 [docs/platform-windows.md](docs/platform-windows.md)

## 一键安装（macOS：Intel / Apple Silicon）

```bash
bash install-macos.sh
source ~/.zshrc        # bash 用户：source ~/.bash_profile
bash verify-macos.sh
```

- Apple Silicon 上自动构建 `mac_arm_64` native decompiler（需 Xcode 命令行工具），并解除 Gatekeeper 隔离
- 详见 [docs/platform-macos.md](docs/platform-macos.md)

## 一键安装（ChromeOS：Linux 开发环境 / Crostini）

ChromeOS 本体不能直接运行 JDK/Ghidra；先在 **设置 → 高级 → 开发者 → Linux 开发环境** 打开 Crostini（Debian 容器），然后在「终端」里走与 Linux 完全相同的流程：

```bash
sudo apt update && sudo apt install -y curl unzip tar make gcc build-essential
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
bash scripts/detect-env.sh    # 确认 Crostini / 架构 / native 是否需自建
bash install.sh && bash verify.sh
```

- x86_64 Chromebook 完整支持（官方预编译 native）；ARM64 Chromebook 需在容器内构建 `linux_arm_64`（安装器自动处理）
- 详见 [docs/platform-chromeos.md](docs/platform-chromeos.md)

## 不确定该用哪个脚本？先识别环境

```bash
bash scripts/detect-env.sh            # 人类可读：系统 / 发行版 / 架构 / 运行环境 / native 目录 / 推荐安装器
bash scripts/detect-env.sh --shell    # KEY=VALUE，便于脚本 eval
bash scripts/detect-env.sh --json     # JSON
```

可识别 `physical`（物理本机）/ `wsl` / `crostini`（ChromeOS）/ `docker` / `vm`（虚拟机与云电脑 VDI），并给出对应 Ghidra native 目录（`linux_x86_64`、`linux_arm_64`、`mac_arm_64`、`win_x86_64`…）与推荐安装命令。

## 端到端验证

```bash
bash verify.sh
```

脚本会真实编译 `examples/demo` 并调用 Ghidra provider，自动校验：

1. 前置依赖（node / gcc / analyzeHeadless）
2. demo 与 demo_stripped 编译无警告
3. `analyze` 识别 ELF / 架构 / 函数数 / 字符串
4. `decompile secret_check` 置信度 `observed`，且常量 `0x539`（1337）可见
5. `decompile calc_discount` 置信度 `observed`，且常量 `0x32`（50）可见
6. 剥离符号的 `demo_stripped` 仍可被导入分析

全部通过退出码 0，可直接作为 CI 步骤。可覆盖：`REA_VERSION=6.4.0 ./verify.sh`。

## Docker 容器（无需本机安装）

```bash
# 构建镜像（含 JDK21 + Node22 + Ghidra 12.1.4 + 全局 rea）
docker build -t rea-ghidra .

# 分析当前目录下的二进制
docker run --rm -v "$PWD:/workspace" rea-ghidra analyze ./demo --provider ghidra --format json

# 反编译
docker run --rm -v "$PWD:/workspace" rea-ghidra decompile ./demo secret_check --provider ghidra

# 容器内跑自检
docker run --rm --entrypoint bash rea-ghidra /opt/rea-ghidra-setup/verify.sh
```

镜像默认入口为 `rea`，工作目录 `/workspace`，**多架构支持 `linux/amd64` 与 `linux/arm64`**（arm64 镜像内自动源码构建 `linux_arm_64` native decompiler）。也可用 Compose：

```bash
docker compose build
docker compose run --rm rea analyze ./demo --provider ghidra --format json
```

完整说明（多架构 buildx、WSL2/VDI/Crostini、rootless、内存与超时）见 [docs/platform-docker.md](docs/platform-docker.md)。

## 不依赖 REA：原生 Ghidra 批量反编译

如果只想把整个二进制反编译出来（不需要 Node / npm / REA），用 Ghidra 原生脚本：

```bash
# 每个函数一个 .c（默认）
./scripts/ghidra-decompile.sh ./demo ./out

# 合并为一个 decompiled.c
./scripts/ghidra-decompile.sh ./demo ./out combined
```

底层为 `analyzeHeadless -postScript DecompileAll.java`（见 `scripts/`），在本机已实测可批量导出全部函数。

## 使用方法

```bash
# 整体分析（ELF 段结构、函数、字符串等）
npx -y rea-agents@latest analyze ./demo --provider ghidra --format json

# 反编译指定函数
npx -y rea-agents@latest decompile ./demo secret_check --provider ghidra --format json

# 用 snapshot 缓存分析结果，多个命令复用、显著加速
npx -y rea-agents@latest analyze ./demo --provider ghidra --snapshot ./demo.snap --format json

# 静态分析 Electron / JavaScript 应用（无需 Ghidra）
npx -y rea-agents@latest analyze-javascript-application /path/to/app --json

# 就绪检查
npx -y rea-agents@latest doctor --provider ghidra
```

全局安装：`npm install --global rea-agents`，之后用 `rea` 命令。`verify.sh` 会优先使用全局 `rea`。

### 环境变量调优

| 变量 | 作用 | 默认 |
| --- | --- | --- |
| `GHIDRA_INSTALL_DIR` | Ghidra 安装目录（REA 据此定位） | 由安装脚本写入 |
| `JAVA_HOME` | JDK 21 目录 | 由安装脚本写入 |
| `GHIDRA_HEADLESS_MAXMEM` / `GHIDRA_MAXMEM` | Ghidra JVM 堆上限（如 `512M`、`2G`） | `2G` |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | 导入/分析/桥接启动超时（毫秒），大二进制可调大 | `330000` |
| `REA_ANALYSIS_PROVIDER` | 多个引擎时强制指定（如 `ghidra`） | 自动选择 |
| `REA_GHIDRA_LANGUAGE_ID` / `REA_GHIDRA_COMPILER_SPEC_ID` | 强制处理器语言/编译器规格（如 Borland PE） | 自动识别 |
| `REA_GHIDRA_DISABLED_ANALYZERS` | 关闭指定自动分析器（逗号分隔） | 默认全开 |
| `REA_DL_RETRIES` / `REA_DL_CONNECT_TIMEOUT` / `REA_DL_MAX_TIME` | 下载内核单源重试次数 / 连接超时秒 / 单源总超时秒 | `5` / `15` / `1800` |
| `REA_MIRROR` | 镜像模式：`auto`（探测）/ `cn`（国内镜像优先）/ `global`（仅官方） | `auto` |
| `REA_GITHUB_PROXIES` | Ghidra 等 GitHub release 的代理前缀列表（逗号/分号/空格分隔）；`none` 只走官方 | 内置 `https://gh-proxy.com/` |

## 卸载

```bash
bash uninstall.sh        # 交互确认，仅删除本项目安装的 JDK/Ghidra 与 .bashrc 环境块
bash uninstall.sh --yes  # 跳过确认
```

全局安装的 REA 用 `npm uninstall --global rea-agents`；清理 REA 缓存（可选）：`rm -rf ~/.rea`。

## 故障排查

- **`doctor` 报 unsupported host（如 Ubuntu 22.04）**：REA 的 Hopper 原生基线是 Ubuntu 24.04+，但 **Ghidra provider 有独立要求**，在 22.04 实测可正常分析。以 `verify.sh` 的实际结果为准。
- **启动超时 / 大二进制卡住**：调大 `REA_GHIDRA_STARTUP_TIMEOUT_MS`（如 `600000`），并确认 MCP 客户端自身的超时也足够长。
- **内存不足 / Java 启动失败**：用 `GHIDRA_HEADLESS_MAXMEM` 调整堆；小目标可设 `512M`，大目标需要更大。
- **native decompiler 缺失**：`doctor` 会点名。x86_64 官方包自带；macOS 与 Linux ARM64 官方归档有时需按官方文档用源码构建（`make ghidra_opt`）。
- **容器内 AppArmor 报错**：Docker 场景用 `--security-opt apparmor:unconfined`（仅本地测试）。
- **按名反编译失败**：剥离符号（strip）后的二进制函数名变为 `FUN_xxxx`，请改用地址，或先 `analyze` 定位。

## 能力覆盖

| 目标 | 依赖 |
| --- | --- |
| 原生二进制（exe/so/dll）：伪代码、汇编、字符串、调用图 | Ghidra / Hopper / IDA |
| Android APK（方法级反编译） | JADX + JDK；真机操作需 adb |
| JavaScript / Electron 应用、.NET 程序集 | 开箱即用（静态分析） |
| 网站实测、HAR/SAZ 抓包、固件、WASM、EVM、SQLite、pcap | 各专项工具，按需配置 |

## 能力边界（请理性看待）

- **服务端逻辑拿不到**：能拆本机客户端，拆不到对方机房；推荐/风控/计价等核心通常在服务端
- **强加固 / 混淆 / 加壳**：VMP 等高强度虚拟化保护当前难以还原，且可能产生误判
- **护城河无法复制**：网络效应、牌照、生态、品牌不是反编译能得到的

## 合规红线（务必阅读）

本工具仅限**合法的安全研究、学习、互操作、软件保藏，以及对你拥有或获授权的软件进行分析**。

- 中国《著作权法》第五十条第（五）项：为"计算机软件反向工程研究"可避开技术措施，但**不得向他人提供**避开技术措施的技术/装置
- 《计算机软件保护条例》第十七条：为学习研究设计思想与原理可使用软件；第六条：保护不延及思想、处理过程、操作方法
- **"研究/分析"通常有豁免，"重建/复刻/商用"无明确豁免**；多数商业软件用户协议含禁止反编译条款
- 商用复刻请采用**净室隔离**：逆向组只产出功能说明书，实现组另起会话、不看反编译代码
- 分析结论会进入 Agent 上下文并发送给模型服务商，涉密/客户交付件请先评估

禁止：绕过 DRM / 授权 / 反作弊、开发外挂、未授权入侵或抓取线上系统、复制发布他人受版权保护的代码与素材。

## 目录

```
.
├── install.sh                # Linux 一键安装 JDK21 + Ghidra + 环境变量
├── install-macos.sh          # macOS 一键安装（Intel + Apple Silicon）
├── install.ps1               # Windows 一键安装（PowerShell，用户态免管理员）
├── uninstall.sh              # Linux 卸载脚本（仅删本项目安装内容）
├── uninstall-macos.sh        # macOS 卸载脚本
├── uninstall.ps1             # Windows 卸载脚本
├── verify.sh                 # Linux 端到端自检（编译 + 真实分析 + 断言）
├── verify-macos.sh           # macOS 端到端自检（Mach-O）
├── verify.ps1                # Windows 端到端自检（预编译 PE fixture）
├── config/
│   └── versions.env          # 版本号单一事实源（Ghidra/JDK/Node/REA）
├── lib/
│   ├── common.sh / common.ps1        # 共用：版本加载/URL/架构/环境识别
│   ├── download.sh                    # 健壮下载内核：重试/超时/续传/原子落地/多源 failover（bash）
│   ├── mirrors.sh                     # 国内镜像策略：REA_MIRROR / Node·JDK 候选 / npmmirror registry
│   ├── checksums.sh / checksums.ps1    # 下载物 SHA-256 校验（上游 + 离线清单）
│   └── （common.ps1 内含 Save-RemoteFile 等 PS 等价下载/镜像内核）
├── docs/                     # 按「操作系统 × 运行环境」组织的文档（见 docs/README.md）
│   ├── README.md             # 文档导航（按平台快速选择）
│   ├── platform-linux.md     # Linux：物理机/虚拟机/WSL/Docker/VDI
│   ├── platform-windows.md   # Windows：物理机/虚拟机/VDI/ARM64
│   ├── platform-macos.md     # macOS：Intel/Apple Silicon
│   ├── platform-chromeos.md  # ChromeOS：Crostini（x86_64 完整 / ARM64 受限）
│   ├── platform-docker.md    # Docker：linux/amd64 + linux/arm64（多架构 buildx）
│   ├── configuration.md      # 环境变量调优 + MCP 接入（mcp add/setup）+ 代理镜像
│   ├── mirrors.md            # 国内镜像加速（REA_MIRROR=cn）+ 校验防篡改说明
│   ├── offline.md            # 离线/内网安装（prepare-offline + OFFLINE_DIR + 镜像 save/load）
│   ├── troubleshooting.md    # 跨平台故障排查
│   └── platform-support-matrix.md  # 平台×环境支持矩阵
├── Dockerfile                # 多架构容器镜像（JDK21 + Node22 + Ghidra + rea，arm64 自动建 native）
├── docker-compose.yml        # Compose 模板（挂载工作目录、透传 rea 命令与内存/超时）
├── skill/SKILL.md            # 逆向工程智能体技能（可装入 Agent）
├── scripts/
│   ├── DecompileAll.java     # Ghidra 原生批量反编译脚本
│   ├── ghidra-decompile.sh   # 不依赖 REA 的批量反编译包装
│   ├── detect-env.sh         # 识别 OS/架构/运行环境（physical/wsl/crostini/docker/vm）
│   ├── doctor.sh             # 只读自检：Node/JDK21/Ghidra/native/内存/磁盘（Linux/macOS）
│   ├── doctor.ps1            # 只读自检（Windows）
│   ├── build-ghidra-native.sh # 从源码构建 arm64/macOS native decompiler
│   ├── prepare-offline.sh    # 有网机器上准备已校验离线包（Linux/macOS）
│   ├── prepare-offline.ps1   # 同上（Windows x64）
│   ├── verify-check.js       # 跨平台统一的 analyze/decompile 断言（Node，三个 verify 共用）
│   ├── selfcheck-checksums.sh # 校验和链路自检（三源 + 真实下载 Node）
│   ├── selftest-download.sh   # 下载内核单测（failover/无半截文件/续传 416，离线可跑）
│   ├── check-mirrors.sh        # 镜像/源连通性与 Range 探测（REA_MIRROR=cn 实测各源）
│   └── check-versions.sh     # 版本一致性 + 上游最新版检查
├── examples/
│   ├── demo.c                # 反编译测试程序（secret_check / calc_discount / main）
│   ├── Makefile              # 编译 demo（含符号）与 demo_stripped（剥离）
│   └── bin/windows-x64/      # 仓库自带的预编译 Windows PE fixture（demo.exe / demo-stripped.exe）
├── VERSION                   # 当前版本号
├── CHANGELOG.md              # 版本变更记录（Keep a Changelog）
├── .github/
│   ├── workflows/ci.yml      # CI：lint（每次）/ e2e 三平台 matrix + docker amd64/arm64 + 校验和（每周·手动）
│   ├── workflows/release.yml # 推 v* 标签时创建 GitHub Release（含源码快照）
│   └── dependabot.yml        # Actions 与 Docker 基础镜像更新提醒
├── CONTRIBUTING.md / SECURITY.md
├── LICENSE                   # PolyForm Noncommercial 1.0.0
└── .gitignore / .dockerignore
```

## 版本历史

- **v2.4（2026-10-15）**
  - **国内镜像加速**：新增 `REA_MIRROR=auto|cn|global`（bash `lib/mirrors.sh` + PS `common.ps1` 等价）。`cn` 镜像优先、官方兜底；`global` 仅官方；`auto`（默认）对官方 nodejs.org 做约 5s 短探测，可达→官方优先，超时→镜像，保证 GitHub Actions 海外不劣化。
  - **Node 镜像**（cn 模式）：npmmirror（`registry.npmmirror.com/-/binary/node/...`，同目录带 SHASUMS256.txt）+ 华为云（`repo.huaweicloud.com/nodejs/...`）；实测 npmmirror 与华为云 Content-Length 与官方一致（TUNA nodejs-release 当时未镜像 v22.19.0（404），未写入）。
  - **JDK（Temurin）镜像**：先从 Adoptium assets JSON 取 `package.link/name/checksum/size`，TUNA `mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/<arch>/<os>/<文件名>` 在前、GitHub release 官方兜底；实测 TUNA Content-Length 与 Adoptium `package.size` 完全一致。
  - **npm 镜像**：cn 模式下 npx/全局安装经 `npm_config_registry=https://registry.npmmirror.com` 拉取 rea-agents，**仅本次进程生效，不改用户全局 .npmrc**；install/verify 共用统一逻辑。
  - **安全不变**：镜像只是候选，官方源始终最终兜底；任何镜像下载的 Node/JDK/Ghidra 仍必须过官方/Adoptium/GitHub digest 强校验，不匹配即删即止；权威 checksum 不可达时维持“警告放行”。
  - 新增 `scripts/check-mirrors.sh`（各源 Range 探测 OK/FAIL）；`doctor.sh` 增加镜像模式提示（cn 为 WARN，不阻断）；新增 [docs/mirrors.md](docs/mirrors.md)。
  - 本机实测：cn 模式经 npmmirror 真实下载 Node 22.19.0 并对官方 SHASUMS256 校验一致；JDK TUNA Content-Length==package.size；`REA_MIRROR=cn verify.sh` 与 `REA_MIRROR=global verify.sh` 均 **9/9**。
- **v2.3（2026-10-15）**
  - **健壮下载内核**：新增 `lib/download.sh`（`download`/`github_proxy_urls`）与 PowerShell `lib/common.ps1`（`Save-RemoteFile`/`Get-GithubProxyUrls`）等价实现——指数退避重试（默认 5 次，`REA_DL_RETRIES` 可配）、连接/总超时（`REA_DL_CONNECT_TIMEOUT`=15s、`REA_DL_MAX_TIME`=1800s）、断点续传（bash `curl -C -`→`wget -c`；PS 显式 `curl.exe -C -`→`Start-BitsTransfer`→`Invoke-WebRequest`）、先下到 `.part` 再原子落地、多源 failover；bash 兼容 macOS 自带 bash 3.2，curl 新参数先探测后再加；自动把大写代理变量补成小写透传。所有交付物下载（`fetch_artifact`/`install_node_portable`/`prepare-offline` 及 PS 对应）由裸 `curl` 切到该内核，**校验和逻辑不变且在多源之后强校验**。
  - **Ghidra 大文件 GitHub 代理池多源回退**：候选顺序 = 官方直连 → 内置 `https://gh-proxy.com/` 前缀（`<代理><原始 github url>`）；可用 `REA_GITHUB_PROXIES` 追加/覆盖（设为 `none` 只走官方）。代理只用于公开 release，产物仍须过 GitHub API digest。Node/JDK 本版仍走官方源（国内镜像在后续版本）。
  - 新增 `scripts/selftest-download.sh`：本地 Range 感知 http 服务，离线验证「主源坏→第二源成功且哈希正确」「全坏源→非零退出且无半截文件」「预置等大 `.part`→416 当成功」三场景，全部通过。
  - 新建 [CHANGELOG.md](CHANGELOG.md)（Keep a Changelog 风格，追溯 1.0→2.3）。
  - 本机实测：`shellcheck -x` 零告警、`scripts/selfcheck-checksums.sh` 通过（真实下载 Node 并强校验）、Ghidra 官方 Range 探测 206（代理不可达时优雅回退）、`verify.sh` 仍 **9/9**。
- **v2.2（2026-10-14）**
  - **下载物 SHA-256 校验**：新增 `lib/checksums.sh` / `lib/checksums.ps1`，三个平台安装器（`install.sh`/`install-macos.sh`/`install.ps1`）对 JDK（Adoptium JSON `package.checksum`）、Node（官方 `SHASUMS256.txt`）、Ghidra（GitHub release `digest`）逐一强校验；**不匹配即删除中止**，离线/限流无清单时才警告放行。本机实测：JDK/Node/Ghidra 三源校验全部一致，篡改样本被拒（退出 1）
  - **离线安装**：新增 `scripts/prepare-offline.sh` 与 `scripts/prepare-offline.ps1`，在有网机器生成已校验离线包（JDK+Node+Ghidra+`rea-agents.tgz`+`SHA256SUMS.txt`/`MANIFEST.txt`），目标机用 `OFFLINE_DIR=<目录> bash install.sh` 离线安装；本机完整生成离线包并验证“离线取包→清单校验”与“篡改拒绝”链路。新增 [docs/offline.md](docs/offline.md)
  - 新增 [docs/troubleshooting.md](docs/troubleshooting.md)：汇总真实踩坑（JDK 版本、Node 门禁、macOS bash 3.2 多字节/Gatekeeper/Mach-O 下划线、Windows JDK17 注入/`%APPDATA%\npm`/路径与 NTFS、arm64 native、Docker QEMU/AppArmor）
  - 新增 [`.github/workflows/release.yml`](.github/workflows/release.yml)：推 `v*` 标签自动 shellcheck、`git archive` 源码快照并用 `softprops/action-gh-release` 创建 Release
- **v2.1（2026-10-14）**
  - 新增跨平台只读诊断 `scripts/doctor.sh`（Linux/macOS）与 `scripts/doctor.ps1`（Windows）：检查 Node 版本门禁、JDK 21、`analyzeHeadless(.bat)`、对应架构 native decompiler、macOS Gatekeeper 隔离、`!`/`^` 路径禁忌、磁盘与堆内存；PASS/WARN/FAIL 汇总，任一 FAIL 退出 1；健康/干净环境本机均验证
  - 新增 [docs/configuration.md](docs/configuration.md)：环境变量（`GHIDRA_HEADLESS_MAXMEM` / `GHIDRA_MAXMEM` / `REA_GHIDRA_STARTUP_TIMEOUT_MS` 等，均按 REA 官方文档核实）、MCP 接入（`rea mcp add` / `rea mcp doctor` / `rea setup` / 手动 `claude_desktop_config.json`）、代理与 npm 镜像
  - [skill/SKILL.md](skill/SKILL.md) 增加跨平台「一键部署 + 自检」小节，按系统指向 install/verify 与 doctor
  - CI matrix 在安装与端到端之间新增 doctor 步骤（三平台均须 0 FAIL）
- **v2.0（2026-10-14）**
  - [平台×环境支持矩阵](docs/platform-support-matrix.md) 定稿：从「规划」措辞更新为**实测状态**，含 4 系统×5 环境总表、逐格说明、CPU 架构与 native decompiler 对照表、CI 实测覆盖表、脚本文件速查表
  - **arm64 实测升级**：`docker-arm64` 作业在原生 `ubuntu-24.04-arm` runner 上构建 `linux_arm_64` native 并在 arm64 容器内 `verify.sh` **9/9**（ELF arch=arm64, procs=34），Docker arm64 由「受限」升级为「支持」
  - README 新增「我该用哪个？（快速选择）」决策表，配合 `scripts/detect-env.sh` 一眼定位脚本；文档导航同步更新
- **v1.9（2026-10-14）**
  - **Docker 多架构**：`Dockerfile` 改用 buildx 注入的 `TARGETARCH` 自动选择 JDK（x64/aarch64）与 Node（x64/arm64）；**linux/arm64 镜像内自动 `make ghidra_opt` 构建 `os/linux_arm_64` native decompiler**，构建期按架构校验对应 `decompile` 就位；支持 `docker buildx build --platform linux/amd64,linux/arm64`
  - 新增 [`docker-compose.yml`](docker-compose.yml)：模板化构建与挂载（`./:/workspace`），透传 `GHIDRA_HEADLESS_MAXMEM` / 启动超时，`docker compose run --rm rea <命令>` 即用
  - 新增 [docs/platform-docker.md](docs/platform-docker.md)：amd64/arm64 构建、QEMU 与原生 arm64 runner 取舍、WSL2/VDI/Crostini/rootless/SELinux/内存超时排障
  - CI 新增 `docker-arm64` 作业（原生 `ubuntu-24.04-arm` runner，免 QEMU 构建 arm64 镜像并在容器内跑 `verify.sh`）；与既有 amd64 `docker` 作业并存，每周/手动触发
- **v1.8（2026-10-14）**
  - **跨平台 CI 合并为 matrix**：原来的 `e2e` / `e2e-macos` / `e2e-windows` 三个作业合并为一个 `e2e (linux/macos/windows)` 矩阵作业，通过 `include` 为每个平台指定 runner、shell、安装/验证命令、独立缓存路径与 key，`fail-fast: false`；每周/手动触发，缓存命中后约 4-6 分钟
  - **统一三端 verify 断言**：抽出 [`scripts/verify-check.js`](scripts/verify-check.js)（Node，零依赖），`verify.sh` / `verify-macos.sh` / `verify.ps1` 全部调用它做 `analyze` / `decompile` / `count` 断言与函数名解析（`funcname`），断言逻辑与常量（`0x539`/`0x32`）只在一处维护；Linux 不再依赖 python3
  - 三端反编译前统一用 `rea search --kind procedures` 解析 Ghidra 内真实函数名（Mach-O 为 `_secret_check` 等），避免平台符号差异
  - 失败时统一打印 REA 的 JSON 错误信封（`error`/`message`/`rejections`）
  - CI 实测：Linux（ELF）、macOS arm64（Mach-O + 自建 `mac_arm_64`）、Windows x64（PE，用户态）三端 `verify` 均 9/9，docker 作业通过
- **v1.7（2026-10-14）**
  - 新增 **ChromeOS 支持（文档化）**：[docs/platform-chromeos.md](docs/platform-chromeos.md)，明确 ChromeOS 本体不支持、唯一途径为 **Crostini（Linux 开发环境 / Debian 容器）**，容器内复用 Linux 流程；x86_64 完整支持、ARM64 需构建 `linux_arm_64`、Crostini 内可装 Docker、不支持通用嵌套虚拟化；给出磁盘/内存建议、`/mnt/chromeos` 文件共享、登出即停等注意事项
  - 新增 [`scripts/detect-env.sh`](scripts/detect-env.sh)：一键识别 OS / 发行版 / CPU 架构 / 运行环境（`physical`/`wsl`/`crostini`/`docker`/`vm`），输出对应 Ghidra native 目录、native 是否需自建与推荐安装器；支持 `--json` / `--shell` 机器可读输出
  - `lib/common.sh` 新增 `is_docker()`、`env_token()`、`env_label()`，集中运行环境识别（`install.sh` 改为复用，顺带识别 Docker 容器）
  - CI 侧修复 macOS（Mach-O 符号带 `_` 前缀，用 `search --kind procedures` 解析真实函数名后再 decompile）与 Windows（fixture 复制到本地 C: 临时卷，满足 REA Windows P0「本地 NTFS、拒绝重解析点」；失败时打印 stderr 与非 JSON stdout）
- **v1.6（2026-10-14）**
  - 新增 **Windows 支持（PowerShell）**：`install.ps1` / `verify.ps1` / `uninstall.ps1` + `lib/common.ps1`，覆盖 Windows 10/11 x64
  - 全程**用户态、免管理员**：Temurin JDK21 / Ghidra / 便携 Node 以 zip 解压到 `%USERPROFILE%\tools`，用 `[Environment]::SetEnvironmentVariable(...,'User')` 写用户级变量，PATH 分号分隔且幂等；自动把 `%APPDATA%\npm` 加入 PATH；校验路径不含 `!`/`^`
  - 校验官方自带 `win_x86_64\decompile.exe`；Node 版本门禁与 bash 版一致（`^22.19||^24.11||>=26`，经单测）
  - 仓库自带**预编译 PE fixture** `examples/bin/windows-x64/demo.exe`（含导出函数）与 `demo-stripped.exe`，Windows 验证无需 C 编译器；`demo.c` 增加可移植 `REA_EXPORT` 宏（ELF 上为空、行为不变）
  - 已在 Linux 主机用 Ghidra 实测该 PE fixture：`format=pe`、`secret_check`/`calc_discount` 均 `observed` 且含 `0x539`/`0x32`、stripped 可分析
  - 新增 [docs/platform-windows.md](docs/platform-windows.md)：物理机 / 虚拟机 / WSL（改用 Linux 流程）/ 云电脑 VDI / Windows on ARM64（受限）与 fixture 重新生成说明
  - CI 新增 `lint-ps`（每次：PSScriptAnalyzer + 语法解析，Error/Warning 均失败）与 `e2e-windows`（windows-latest x64，真实安装+验证，每周/手动）
  - 修复：所有「`$变量` 后紧跟中文」的展开加花括号，兼容 macOS 自带 bash 3.2 的非 UTF-8 解析
- **v1.5（2026-10-14）**
  - 新增 **macOS 支持**：`install-macos.sh` / `verify-macos.sh` / `uninstall-macos.sh`，覆盖 Intel（x64）与 Apple Silicon（arm64）
  - 适配 macOS 特有 JDK 布局（Temurin tar.gz 的 `<bundle>/Contents/Home`）；安装后自动 `xattr -dr com.apple.quarantine` 解除 Gatekeeper 隔离（REA 不代做）
  - 自动检测并从源码构建缺失的 native decompiler：`mac_arm_64`（Apple Silicon）/ `mac_x86_64`（Intel），`build-ghidra-native.sh` 已支持 `ARCH_TYPE`/`OSDIR` 覆盖
  - 环境变量幂等写入 `~/.zshrc`（默认）与 `~/.bash_profile`（兼容 bash）
  - `verify-macos.sh` 用 clang 编译 Mach-O demo，复用同一组断言（analyze/decompile/stripped，9 项），用 Node 解析 JSON（macOS 不依赖 python3）
  - 新增 [docs/platform-macos.md](docs/platform-macos.md)：物理机 / 虚拟机（Apple Silicon 仅 arm64 guest）/ 云 Mac / Docker Desktop 差异与 Gatekeeper、Xcode CLT 排障
  - CI 新增 `e2e-macos`（macos-latest = arm64，真实安装+构建 native+验证，每周/手动）；ShellCheck 覆盖根目录所有 `.sh`
- **v1.4（2026-10-14）**
  - Linux 安装加固：启动时自动识别**操作系统 / 运行环境（物理机 / 虚拟机·容器 / WSL2 / Crostini）/ 架构（x64·aarch64）**并打印
  - 支持 **arm64（aarch64）**：JDK 自动选 Temurin aarch64；新增 [`scripts/build-ghidra-native.sh`](scripts/build-ghidra-native.sh)，在官方未预编译时从源码构建 `os/linux_arm_64`（及后续 macOS）native decompiler，安装器自动调用
  - 新增**便携 Node 22**：系统 Node 缺失或版本不满足 REA 要求（`^22.19 || ^24.11 || >=26`）时自动下载到 `~/tools/node`，无需 root（`SKIP_NODE=1` 可跳过）；版本门槛经单元测试，正确拒绝 23/25 等不支持版本
  - 环境变量同时幂等写入 `~/.bashrc` 与 `~/.zshrc`（存在时）；PATH 增加 `Ghidra/support` 与便携 Node bin
  - 新增 [docs/platform-linux.md](docs/platform-linux.md)：逐一覆盖物理本机 / 虚拟机 / WSL2 / Docker / 云电脑 VDI 的步骤、资源建议、`/mnt/c` 与 `.wslconfig` 等坑，以及 arm64 构建、代理与故障排查
  - 本机实测：安装器在 x86_64 上 5 步全过、`rea doctor` 全 healthy、便携 Node 下载可用、`verify.sh` 9/9 不劣化
- **v1.3（2026-10-14）**
  - 新增版本号「单一事实源」[`config/versions.env`](config/versions.env)：Ghidra / JDK / Node / REA 版本集中管理；`install.sh`、`verify.sh`、`Dockerfile` 全部改为读取它，不再各自硬编码（刻意用 `REA_NODE_VERSION` 避免与 fnm/nvm 注入的 `NODE_VERSION` 冲突）
  - 新增 [`lib/common.sh`](lib/common.sh)：跨平台 bash 共用的版本加载、下载 URL 构造、日志与架构/WSL/Crostini 检测函数
  - 新增 [`scripts/check-versions.sh`](scripts/check-versions.sh)：校验版本字段齐全、检测脚本/Dockerfile 是否重新硬编码版本，并探测 npm 与 GitHub 上游最新版（离线/限流自动跳过）
  - `Dockerfile` 改为从 `versions.env` 读取版本，并用版本无关软链 `/opt/tools/ghidra`、`/opt/tools/jdk21` 定位，升级版本无需改 ENV
  - 新增 `docs/` 文档目录：[文档导航](docs/README.md) 与 [平台×环境支持矩阵](docs/platform-support-matrix.md)（4 系统 × 5 运行环境，后续版本逐格补齐）；新增 `VERSION` 文件
  - CI lint 增加全量 ShellCheck（含 `lib/`、`scripts/`）与版本一致性检查
  - 本机实测：`install.sh` 幂等通过、`rea doctor` 报告 ghidra healthy（native decompiler 匹配 linux/x64）、`verify.sh` 9/9
  - 核对上游：Ghidra 12.1.4、rea-agents 6.4.0 仍为最新
- **v1.2（2026-10-14）**
  - 新增 Docker 支持（`Dockerfile` + `.dockerignore`）：镜像含 JDK21 + Node22 + Ghidra + 全局 `rea`；CI 构建镜像并在容器内跑 `verify.sh`
  - 新增原生 Ghidra 批量反编译：`scripts/DecompileAll.java` + `scripts/ghidra-decompile.sh`（`separate`/`combined`，不依赖 REA/Node）
  - `verify.sh` 增加 `calc_discount` 反编译校验（observed，含 `0x32`=50）
  - 新增 `CONTRIBUTING.md`、`SECURITY.md`
  - 新增 Dependabot（GitHub Actions、Docker 基础镜像）
  - 核对上游：Ghidra 12.1.4、REA 6.4.0 仍为最新
  - CI 实测：宿主机 e2e 与容器内（docker run verify.sh）均 9/9 通过；
    期间通过容器内验证逐步补全 libc6-dev、python3 等缺失依赖
- **v1.1（2026-10-14）**
  - 新增 `verify.sh` 端到端自检（编译 + analyze/decompile + 断言，8 项检查）
  - 新增 `uninstall.sh` 卸载脚本
  - 新增 `examples/Makefile`，并修复 `demo.c` 缺失的 `#include <stdlib.h>`
  - 新增 GitHub Actions CI：ShellCheck + 编译（每次），完整端到端（每周/手动）
  - `install.sh` 增加磁盘空间检查；环境变量块改为始终同步最新路径（支持升级版本）
  - CI 适配：`install.sh` 检测到 GitHub Actions 时写 `GITHUB_ENV`/`GITHUB_PATH`；
    `verify.sh` 校验 JDK 版本，预置 JDK 低于 21 时自动改用 `~/tools/jdk-21`
  - 核对上游：REA 6.4.0、Ghidra 12.1.4；补充故障排查、环境变量调优文档
  - 已在 CI 干净 runner 实测：lint-build 与完整 e2e 均 success，8/8 检查通过
- **v1.0（2026-10）**：首次发布，云电脑一键部署 JDK21 + Ghidra 12.1.4，含逆向技能与实测

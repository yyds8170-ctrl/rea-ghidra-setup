# Linux 平台部署指南

适用脚本：[`install.sh`](../install.sh)（安装）、[`verify.sh`](../verify.sh)（验证）、[`uninstall.sh`](../uninstall.sh)（卸载）。

这套脚本在 **物理本机、虚拟机、WSL2、ChromeOS Crostini、云电脑（VDI）** 中是同一套 Linux 流程，安装器会在启动时自动识别并打印当前环境。差异只在「如何进入这台 Linux 系统」与少量资源/网络注意事项，本文逐环境说明。

## 一、支持与架构

| 架构 | JDK 21 | Ghidra headless | native decompiler | 说明 |
| --- | --- | --- | --- | --- |
| **x86_64 / amd64** | ✅ | ✅ | ✅ 官方自带（`os/linux_x86_64`） | 主力支持，本机实测 |
| **arm64 / aarch64** | ✅（Temurin aarch64） | ✅ | 🟠 需自行构建（`os/linux_arm_64`） | 安装器自动调用 `scripts/build-ghidra-native.sh` 从源码构建 |

发行版：Debian/Ubuntu（22.04/24.04）、Fedora、Arch 等均可。REA 的 Hopper 原生基线偏向 Ubuntu 24.04+，但 **Ghidra provider 有独立要求**，在 Ubuntu 22.04 实测可正常分析（以 `verify.sh` 结果为准）。

## 二、通用前置要求

- 命令：`curl`、`unzip`、`tar`（缺失时安装器会提示）。
  - Debian/Ubuntu：`sudo apt update && sudo apt install -y curl unzip tar`
  - Fedora：`sudo dnf install -y curl unzip tar`
- 磁盘：`~/tools` 约 **2.6GB**、临时目录约 **0.8GB**（安装器会先检查）。
- 内存：建议 4GB 以上；反编译大二进制可调大 JVM 堆（见根 README「环境变量调优」）。
- 网络：需要能访问 `github.com`、`api.adoptium.net`、`nodejs.org`、`registry.npmjs.org`。

## 三、一键安装（所有 Linux 环境通用）

```bash
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
bash install.sh
source ~/.bashrc        # zsh 用户：source ~/.zshrc
bash verify.sh          # 端到端自检，9 项断言全过即就绪
```

安装器（v1.4+）完成 5 步：

1. 下载 Temurin JDK 21（按架构自动选 x64/aarch64）到 `~/tools`；
2. 检测系统 Node，缺失或版本不满足（REA 要求 `^22.19 || ^24.11 || >=26`）时，自动安装**便携版 Node 22** 到 `~/tools/node`（无需 root；`SKIP_NODE=1` 可跳过）；
3. 下载并解压 Ghidra（跨平台 zip）；
4. 校验 native decompiler：x86_64 官方自带直接通过；arm64 自动从源码构建；
5. 幂等写入 `~/.bashrc`（以及存在时的 `~/.zshrc`）环境变量块。

全部无需 root、可重复运行（幂等）；JDK/Ghidra 已存在时自动跳过。

## 四、各运行环境差异

### 1. 物理本机（最常见）

直接按第三节执行即可。常见发行版：Ubuntu、Fedora、Debian、Arch。

- x86_64 PC/笔记本：完整支持。
- ARM 开发板（树莓派 4/5、ARM 服务器）：走 arm64 流程，安装器会构建 `linux_arm_64` native decompiler；需 `sudo apt install build-essential bison`（树莓派内存小，建议加 swap，构建较慢）。

### 2. 虚拟机（VMware / VirtualBox / KVM / Hyper-V Linux guest）

- guest 是标准 Linux，**完全复用**本流程。
- 分配资源建议：至少 **4 核 / 4GB 内存 / 20GB 磁盘**；磁盘建议选「动态分配」但要预留足够空间（见前置要求）。
- 网络默认 NAT 即可访问外网；若处于企业内网/受限网络，见文末「代理」。
- 分析主机上的文件时，可挂载共享目录（VMware shared folders / VirtualBox 共享文件夹 / virtiofs）；分析前最好把目标二进制复制到 guest 本地盘（部分网络/共享文件系统对 headless 构建工程不友好）。

### 3. WSL2（Windows 上的 Linux 子系统）

WSL2 里运行的是真实 Linux，**在 WSL 内执行本文件的脚本即可**，与原生 Linux 几乎一致。

安装/前置：

```powershell
# 在 Windows PowerShell（管理员）中一次性安装 Ubuntu（已装可跳过）
wsl --install -d Ubuntu
```

```bash
# 进入 WSL（开始菜单打开 Ubuntu）后
sudo apt update && sudo apt install -y curl unzip tar build-essential
bash install.sh
```

WSL2 注意事项：

- **Ghidra 跑在 Linux 侧**：WSL2 是 Linux 客户机，使用 `linux_x86_64` 工具链，不要在 WSL 里再用 Windows 版 JDK/Ghidra。
- **跨盘访问**：Windows 盘挂在 `/mnt/c/...`。把要分析的文件放到 WSL 的 **Linux 家目录**（`~/` 或 `/tmp/`）下再分析，速度显著快于 `/mnt/c`；Ghidra 工程目录不要建在 `/mnt/c`（DrvFs 权限/锁语义不同，易报错）。
- **内存**：WSL2 默认可能占用较多内存，可在 Windows 的 `%UserProfile%\.wslconfig` 中限制：
  ```ini
  [wsl2]
  memory=6GB
  swap=4GB
  ```
- **systemd**：较新 WSL 支持 systemd（`/etc/wsl.conf` 设 `[boot]\nsystemd=true`）；本部署不依赖 systemd，不开也能用。
- **Docker**：Docker Desktop 开启 WSL2 后端时，可在 WSL 里直接用 `docker`（见 [platform-docker.md](platform-docker.md)）；也可在 WSL 内直接装 docker-ce。
- 若既要在 Windows 原生跑、又要在 WSL 跑，两者是**相互独立的两套安装**，互不影响。

### 4. Docker 容器

Linux 宿主上的 Docker 用法见 [platform-docker.md](platform-docker.md)。容器镜像内置 JDK21 + Node + Ghidra + 全局 `rea`，无需在本机安装。

### 5. 云电脑 / VDI（远程 Linux 桌面）

- 云电脑（阿里云/腾讯云/华为云无影、Azure Virtual Desktop 的 Linux 桌面、Parallels/VMware 远程桌面等）只要 guest 是标准 Linux，**完全复用**本流程。
- 典型检测：安装器会显示 `虚拟机/容器（...）`。
- 注意事项：
  - **磁盘/资源配额**：部分云主机系统盘较小，把 `TOOLS_DIR` 指到数据盘：`TOOLS_DIR=/data/tools bash install.sh`。
  - **网络策略**：企业 VDI 可能限制外网或需要代理（见下文）。
  - **会话与内存**：断开远程会话后，正在跑的 headless 分析可能随会话结束被回收；长时间任务建议在 `tmux`/`screen` 或 `nohup` 中运行。
  - 无 root 的受控云桌面：脚本本身无需 root，但构建 arm64 native 时 `apt install build-essential` 需要管理员；x86_64 不需要。

## 五、arm64 原生反编译器构建

官方发布包不含 `linux_arm_64` 的 native decompiler。安装器在 arm64 上会自动尝试构建；若因缺少工具失败：

```bash
# Debian/Ubuntu（arm64）
sudo apt install -y build-essential bison
# Fedora
sudo dnf install -y gcc-c++ make bison

# 手动构建（幂等，已存在则跳过；--force 重建）
bash scripts/build-ghidra-native.sh
```

构建只需 C++ 工具链，不需要 JDK；完成后用 `rea doctor --provider ghidra` 复核，应看到 `native decompiler ... linux/arm64` healthy。

## 六、验证与卸载

```bash
bash verify.sh          # 编译 examples/demo，真实 analyze/decompile，9 项断言
bash uninstall.sh       # 交互确认后删除本项目装的 JDK/Ghidra 与环境块
bash uninstall.sh --yes # 跳过确认
```

卸载只删本项目装到 `~/tools` 的内容与 rc 文件中的环境块；全局 REA 用 `npm uninstall --global rea-agents`，缓存可选 `rm -rf ~/.rea`。

## 七、代理与镜像

- 出站代理：在安装前导出 `HTTPS_PROXY=http://host:port`、`HTTP_PROXY=...`（`curl`/`npm` 均遵循）。
- npm 镜像：`npm config set registry https://registry.npmmirror.com`。
- 完全离线/内网安装见 [offline.md](offline.md)。

## 八、常见问题（Linux）

- **`doctor` 报 unsupported host（如 Ubuntu 22.04）**：REA 的 Hopper 原生基线是 Ubuntu 24.04+，但 **Ghidra provider 有独立要求**，22.04 实测可正常分析，以 `verify.sh` 为准。
- **`npx` 下载 rea-agents 很慢**：配置 npm 镜像；或先 `npm install --global rea-agents` 后直接用 `rea`。
- **arm64 构建报缺少 bison/编译器**：见第五节安装 `build-essential bison`。
- **`/mnt/c` 上分析报错或极慢（WSL）**：把文件与 Ghidra 工程目录移到 WSL 家目录。
- **内存不足 / Java 启动失败**：`GHIDRA_HEADLESS_MAXMEM=512M bash install.sh` 或运行时调小；大二进制则调大。
- 更多跨平台问题见 [troubleshooting.md](troubleshooting.md)。

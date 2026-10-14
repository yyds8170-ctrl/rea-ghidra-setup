# macOS 平台部署指南

适用脚本：[`install-macos.sh`](../install-macos.sh)（安装）、[`verify-macos.sh`](../verify-macos.sh)（验证）、[`uninstall-macos.sh`](../uninstall-macos.sh)（卸载）。

## 一、支持与架构

| 机型 | 架构 | JDK 21 | Ghidra headless | native decompiler |
| --- | --- | --- | --- | --- |
| Apple Silicon（M1/M2/M3/M4） | arm64 | ✅ Temurin aarch64 | ✅ | 🟠 官方包常缺 `mac_arm_64`，安装器自动从源码构建 |
| Intel Mac | x86_64 | ✅ Temurin x64 | ✅ | 🟠 官方包可能只带源码，缺失时同样自动构建 `mac_x86_64` |

> Ghidra 官方发布包对 **Linux x86_64 / Windows x86_64 预编译** native decompiler；
> macOS（含 Intel）在 12.1.4 实测中可能只带源码，需要本机用 Xcode 命令行工具构建。
> 安装器会检测目标二进制是否存在，缺失即自动调用 [`scripts/build-ghidra-native.sh`](../scripts/build-ghidra-native.sh)。

## 二、前置要求

- **Xcode 命令行工具**（构建 native decompiler 用，提供 clang/make/SDK）：
  ```bash
  xcode-select --install
  ```
  验证：`xcode-select -p` 应输出类似 `/Library/Developer/CommandLineTools`。
- 命令：`curl`、`unzip`（macOS 自带）。
- 磁盘：`~/tools` 约 **3GB**；Apple Silicon 首次构建 native 还需要约 1GB 临时空间。
- 内存：建议 8GB 以上（macOS 桌面 + JVM）。

> 不需要 Homebrew、不需要 root；脚本以 **tar.gz 解压到 `~/tools`** 的方式安装 JDK / Ghidra / Node。
> 若 `make` 报 bison 版本过旧，可用 `brew install bison`（可选）；多数情况下发布包已附带生成好的解析器，系统自带 bison 即可。

## 三、一键安装

```bash
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
bash install-macos.sh
source ~/.zshrc          # 默认 zsh；bash 用户：source ~/.bash_profile
bash verify-macos.sh     # 编译 Mach-O demo 并真实反编译，9 项断言
```

安装器（5 步）：

1. 下载 Temurin JDK 21（自动选 mac/aarch64 或 mac/x64），解包到 `~/tools`，识别 macOS 特有的 `<bundle>/Contents/Home` 布局并设置 `JAVA_HOME`；
2. 检测系统 Node，不满足 REA 要求（`^22.19 || ^24.11 || >=26`）时安装便携 Node 22（`SKIP_NODE=1` 可跳过）；
3. 下载并解压 Ghidra；
4. **解除 Gatekeeper 隔离**：对整个 Ghidra/JDK 目录递归 `xattr -dr com.apple.quarantine`（REA 不会替你做这步，必须由部署脚本处理）；随后构建缺失的 native decompiler；
5. 幂等写入 `~/.zshrc` 与 `~/.bash_profile`。

## 四、各运行环境

### 1. 物理 Mac（最常见）

直接按第三节执行即可。

- Apple Silicon：确认「关于本机」显示 M 系列芯片；安装器自动走 arm64 并构建 `mac_arm_64`。
- Intel：走 x64 流程。
- 首次运行若仍弹出「无法验证开发者」，对目标目录再执行一次：
  ```bash
  xattr -dr com.apple.quarantine ~/tools/ghidra_*_PUBLIC
  ```

### 2. 虚拟机

- **Apple Silicon 上的虚拟机（Parallels / VMware Fusion / UTM / Apple Virtualization）只能运行 arm64 客户机**，无法虚拟化 x86_64 整个操作系统（Rosetta 仅转译单个 x86_64 二进制，不转译整个系统）。
- guest 是 macOS arm64 时，在 guest 内复用本流程（仍需构建 `mac_arm_64`）。
- 资源建议：至少 4 核 / 6GB 内存 / 25GB 磁盘。
- 在 Apple Silicon 上跑 **Linux arm64 虚拟机**：那是 Linux 客户机，改用 [platform-linux.md](platform-linux.md) 的 arm64 流程。

### 3. WSL

- ➖ WSL 是 Windows 专属功能，macOS 上不适用。需要在 Windows 上跑 Linux 时见 [platform-linux.md](platform-linux.md#3-wsl2windows-上的-linux-子系统)。

### 4. Docker（Docker Desktop / Orbstack）

- macOS 上的 Docker 运行的是 **Linux 容器**，使用 [platform-docker.md](platform-docker.md) 的 `Dockerfile`（`linux/amd64`）。
- Apple Silicon 上跑 amd64 镜像走 Rosetta/QEMU 模拟；`linux/arm64` 镜像需在镜像内构建 `linux_arm_64` native（见 [platform-docker.md](platform-docker.md)）。
- 原生的 macOS 反编译不走 Docker——需要 macOS 原生 Mach-O 分析时使用本机 `install-macos.sh`。

### 5. 云 Mac（CI / MacStadium / 云手机厂商的 Mac farm）

- GitHub Actions 的 `macos-latest` 已经是 **Apple Silicon arm64**，本仓库 CI 即在此环境真实运行 `install-macos.sh` + `verify-macos.sh`（含 `mac_arm_64` 构建）。
- 自建云 Mac（MacStadium/AWS EC2 Mac）：与物理 Mac 完全相同，注意磁盘配额与会话回收（长任务用 `tmux`/`nohup`）。
- Intel 云 Mac（较少）：自动走 x64 分支。

## 五、验证与卸载

```bash
bash verify-macos.sh       # 编译 Mach-O demo + analyze/decompile，9 项断言
bash uninstall-macos.sh    # 交互确认后删除 JDK/Ghidra/便携 Node 与环境块
bash uninstall-macos.sh --yes
```

`verify-macos.sh` 用系统 `cc`（clang）编译 Mach-O demo，断言：Mach-O 识别、函数数、字符串、`secret_check`（observed，含 `0x539`）、`calc_discount`（observed，含 `0x32`）、剥离符号仍可分析。

## 六、常见问题（macOS）

- **构建 native 失败，提示找不到编译器 / SDK**：先 `xcode-select --install` 完成安装；若仍失败，执行 `sudo xcode-select --reset` 或在装了完整 Xcode 后 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
- **`make` 报 bison 或参数错误**：发布包默认已带生成好的解析器；若仍报错，`brew install bison` 让新版 bison 位于 PATH 前面；arm64 固定走 `ARCH_TYPE="-arch arm64" OSDIR=mac_arm_64`。
- **Gatekeeper 拦截（无法打开 / 无法验证）**：`xattr -dr com.apple.quarantine ~/tools/ghidra_*_PUBLIC`。
- **`doctor` 报 native decompiler 不匹配**：多为架构目录放错（必须是 `mac_arm_64` 而非 `mac_x86_64`）；重跑 `bash scripts/build-ghidra-native.sh --force`。
- **Rosetta 装的是 x64 版 JDK**：Apple Silicon 上请用 aarch64 的 Temurin（安装器自动选择）；在「访达」里看终端是否在 Rosetta 下运行（`sysctl -n machdep.cpu.brand_string` / `uname -m` 应为 `arm64`）。
- **内存不足**：`GHIDRA_HEADLESS_MAXMEM=512M` 调小，或在大目标上调大。
- 更多见 [troubleshooting.md](troubleshooting.md)。

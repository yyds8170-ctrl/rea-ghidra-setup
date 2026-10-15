# Windows 平台部署指南

适用脚本：[`install.ps1`](../install.ps1)（安装）、[`verify.ps1`](../verify.ps1)（验证）、[`uninstall.ps1`](../uninstall.ps1)；共用函数 [`lib/common.ps1`](../lib/common.ps1)。

> 推荐用 **PowerShell 7（pwsh）** 运行；Windows 10/11 自带的 Windows PowerShell 5.1 也能运行，但 7 默认 UTF-8、兼容性最好。所有脚本**全程用户态、免管理员**。

## 一、支持与要求

| 项 | 结论 |
| --- | --- |
| 操作系统 | **Windows 10（build 1809）及以上 / Windows 11**，64 位 |
| 架构 | **x64 官方支持并在 CI（windows-latest）实测**；ARM64（Windows on ARM）借助 x64 模拟，属「受限支持」，见文末 |
| JDK | Temurin 21（脚本自动下载用户态 zip，解压到 `%USERPROFILE%\tools`） |
| Ghidra | 跨平台 zip；Windows x64 的 `win_x86_64\decompile.exe` 为**官方预编译**，无需自行构建 |
| Node | 满足 `^22.19 || ^24.11 || >=26` 即用系统 Node；否则脚本自动解压便携 Node 24.22.0 |
| C 编译器 | **不需要**。验证使用仓库自带的预编译 PE fixture，见 [examples/bin/windows-x64](../examples/bin/windows-x64) |

> 安装路径**不能包含 `!` 或 `^`**（Ghidra headless 无法启动）；默认 `%USERPROFILE%\tools` 安全。可用 `TOOLS_DIR` 环境变量覆盖。

## 二、安装 PowerShell 7（可选但推荐）

任选其一：

- winget：`winget install Microsoft.PowerShell`
- 或下载：<https://github.com/PowerShell/PowerShell/releases>（选 `PowerShell-7.x.x-win-x64.msi`）

装好后在「PowerShell 7」中操作。也可以直接用系统自带的「Windows PowerShell」，执行命令相同。

## 三、一键安装

```powershell
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup

# 若提示执行策略拦截，用 Bypass（仅对当前进程生效，不修改系统）
powershell -ExecutionPolicy Bypass -File .\install.ps1
# 在 pwsh 7 中：
pwsh -File .\install.ps1
```

安装器（5 步）：

1. 下载 Temurin JDK 21（windows/x64 zip）→ 解压到 `%USERPROFILE%\tools\jdk-21*`；
2. 检测系统 Node，不满足要求时解压便携 Node 24.22.0（`node-v24.22.0-win-x64`）；
3. 下载并解压 Ghidra（约 570MB）→ `%USERPROFILE%\tools\ghidra_<版本>_PUBLIC`；
4. 校验官方自带的 `win_x86_64\decompile.exe`；
5. 写入**用户级**环境变量（HKCU，免管理员，幂等）：
   - `JAVA_HOME`、`GHIDRA_INSTALL_DIR`、`GHIDRA_HEADLESS_MAXMEM`；
   - 向**用户** PATH 追加 `%JAVA_HOME%\bin`、便携 Node 目录、npm 全局目录 `%APPDATA%\npm`。

> 完成后**重新打开一个终端**让环境变量生效。脚本只写用户级 PATH，不会覆盖系统 PATH。

## 四、各运行环境

### 1. 物理本机（Windows 10/11 x64）

直接按第三节执行即可。

- 若 `decompile.exe` 报 `VCRUNTIME140.dll 缺失`，安装微软 VC++ Redist x64：
  <https://aka.ms/vs/17/release/vc_redist.x64.exe>（Ghidra 12.x 官方文档未强制要求，极少数精简系统需要）。

### 2. 虚拟机（VMware / Hyper-V / VirtualBox / Parallels）

- guest 为 **Windows x64** 时完全复用本流程。
- 建议分配 ≥4 vCPU / 8GB 内存 / 25GB 磁盘。
- 在 Apple Silicon Mac 上无法运行 Windows x64 虚拟机（没有 x86 虚拟化；x64 模拟仅适用于单个 Windows on ARM 环境）。

### 3. WSL（Windows Subsystem for Linux）

- WSL 里是 **Linux** 环境，**不要**在 WSL 内运行 PowerShell 安装脚本；请在 WSL 内使用 Linux 流程：
  ```bash
  bash install.sh
  ```
  详见 [platform-linux.md](platform-linux.md) 的 WSL2 章节。
- 你也可以同时在 Windows 宿主（PowerShell）和 WSL（bash）里各装一套，二者互不影响。

### 4. Docker 容器

- Windows 上的容器跑的是 **Linux 容器**（Docker Desktop / WSL2 后端），使用 [platform-docker.md](platform-docker.md) 的 `Dockerfile`。
- 原生 Windows 容器（`windows` base image）不提供 Ghidra headless 的标准支持，本项目**不针对 Windows 容器**。

### 5. 云电脑（Windows VDI / Azure Virtual Desktop / Windows 365）

- 大多数 Windows VDI 是 x64，复用本流程即可；脚本不依赖管理员、不装系统服务，适合在**非持久桌面**上执行。
- 注意：非持久 VDI 重启后用户目录可能被还原，需要重装；有持久用户盘时把 `TOOLS_DIR` 指向持久盘：
  ```powershell
  $env:TOOLS_DIR = 'U:\tools'   # 改为你的持久盘
  .\install.ps1
  ```
- 首次分析要启动 JVM，瘦客户端如有资源限制，可在安装后调小堆内存：
  ```powershell
  [Environment]::SetEnvironmentVariable('GHIDRA_HEADLESS_MAXMEM','512M','User')
  ```

## 五、验证与卸载

```powershell
# 验证（对仓库自带的预编译 PE 做真实分析，9 项断言）
powershell -ExecutionPolicy Bypass -File .\verify.ps1

# 卸载（交互确认；-Yes 跳过确认）
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

### 为什么 Windows 用「预编译 PE fixture」而不是现场编译？

Linux 上 `verify.sh` 用 gcc 现场编译 `examples/demo.c`；Windows 默认没有 C 编译器（MinGW/MSVC 都需要额外安装、且多需管理员）。因此仓库在
[`examples/bin/windows-x64/demo.exe`](../examples/bin/windows-x64) 直接提供一个由 Zig 交叉编译的最小 PE：

- `demo.exe`：把 `secret_check`、`calc_discount` 放进了 **PE 导出表**，使 Ghidra 能按函数名命名（普通 PE 的函数名在独立的 PDB 里，默认不带）；
- `demo-stripped.exe`：去除符号，用于验证无符号二进制仍可分析。

`verify.ps1` 断言：PE 识别（MZ）、导出函数、`format=pe`、函数数、字符串、`secret_check`（observed，含 `0x539`）、`calc_discount`（observed，含 `0x32`）、剥离版仍可分析。

> 如需自行重新生成 fixture（Linux 上交叉编译）：
> ```bash
> # 安装 Zig（自带 Windows 工具链）
> pip install ziglang
> ZIG=$(python3 -c "import ziglang,os;print(os.path.join(os.path.dirname(ziglang.__file__),'zig'))")
> "$ZIG" cc -target x86_64-windows-gnu -O2 examples/demo.c -o examples/bin/windows-x64/demo.exe
> "$ZIG" cc -target x86_64-windows-gnu -O2 -Wl,--strip-all examples/demo.c -o examples/bin/windows-x64/demo-stripped.exe
> ```

## 六、Windows on ARM64（受限）

- 脚本在检测到 ARM64 时会打印警告并继续安装 **x64** 版本，依赖 Windows 11 的 x64 模拟运行（JDK、Ghidra、native decompiler 都走模拟）。
- 官方 CI 仅在 x64（`windows-latest`）验证；ARM64 路径标记为「受限/未在 CI 实测」，如遇问题请在 x64 机器或 Linux arm64 流程中运行。
- 原生 ARM64 的 Ghidra native decompiler 官方发布包**不提供**（Windows 也没有对应 `win_arm_64` 目录的标准支持），因此当前不提供原生 ARM64 路径。

## 七、常见问题

- **执行策略被拦截（红字 / 无法加载脚本）**：用 `powershell -ExecutionPolicy Bypass -File .\install.ps1`，仅对当前进程生效，不降低系统安全设置。
- **`rea` / `npx` 不是内部或外部命令**：重新打开终端；仍失败时确认 `%APPDATA%\npm` 与便携 Node 目录在用户 PATH 中（安装脚本会自动加）。
- **Ghidra 启动报路径错误**：确认安装路径不含 `!`、`^`；用 `TOOLS_DIR` 改到纯英文路径。
- **首次 `npx` 很慢或超时**：它在首次下载 `rea-agents`；重试或先 `npm install -g rea-agents`。
- **想改默认堆内存**：设置用户级 `GHIDRA_HEADLESS_MAXMEM`（如 `512M` / `4G`）。
- 更多见 [troubleshooting.md](troubleshooting.md)。

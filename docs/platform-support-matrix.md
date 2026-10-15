[English](platform-support-matrix.en.md) | 简体中文

# 平台 × 运行环境支持矩阵

> 状态含义：
> - ✅ **支持**：有对应脚本/镜像，且在 CI 或本机实测通过。
> - 🟡 **部分**：可用但有前提（如仅 x86_64、需要额外步骤）。
> - 🟠 **受限**：官方未预编译某组件 / 需自行构建 / 无 CI 实跑，仅文档化。
> - ❌ **不支持**：平台本身无法运行，或官方不支持。
> - ➖ **不适用**：该组合在技术上不存在。
>
> 安装逻辑**按操作系统组织**；物理机 / 虚拟机 / 云电脑（VDI）复用对应 OS 的安装脚本，
> 差异仅在资源、网络与嵌套虚拟化。WSL 是 Windows 宿主上的 Linux 客户机，内部走 Linux 流程。
> 先运行 `bash scripts/detect-env.sh` 可自动识别当前系统、架构与运行环境。

## 零、锁定版本与统一能力（v3.x）

- 锁定版本（`config/versions.env`）：**Ghidra 12.1.4 / JDK 21 / 便携 Node 24.22.0 / REA 6.5.0**。
- 统一入口：`./rea-ghidra install|verify|doctor|mcp|export|batch|current|rollback|self-update`（Windows `.\rea-ghidra.ps1`）。
- 能力：MCP 一键对接（[mcp.md](mcp.md)）、静态导出（[export.md](export.md)）、批量并行 + 快照缓存（[batch.md](batch.md)）、多架构 fixture CI（`fixture-multiarch`，ELF32/AArch64/PE32）、自更新 ff-only / checksums 校验、`current-ghidra`·`current-jdk` 软链与回滚、Docker amd64+arm64、Release 附带 `checksums.txt` + SBOM。
- 发现逻辑：显式 env（`JAVA_HOME`/`GHIDRA_INSTALL_DIR`）＞ `~/tools/current-*` 软链 ＞ 版本化目录枚举（旧行为兜底）。

## 一、系统 × 运行环境总表

| 操作系统 | 物理本机 | 虚拟机 | WSL | Docker 容器 | 云电脑 VDI |
| --- | --- | --- | --- | --- | --- |
| **Linux** | ✅ x86_64 / 🟠 arm64 | ✅ x86_64 / 🟠 arm64 | ✅ WSL2（即 Linux 流程） | ✅ amd64 / ✅ arm64（镜像自动建 native，CI 原生实测） | ✅ x86_64 / 🟠 arm64 |
| **Windows** | ✅ 10/11 x64 | ✅ x64（复用脚本） | 🟡 WSL2 内走 Linux | 🟡 Docker Desktop（Linux 容器） | ✅ x64 VDI |
| **macOS** | ✅ Intel + Apple Silicon（arm64 自动建 native） | 🟡 Apple Silicon 仅能跑 arm64 guest | ➖ | 🟡 Docker Desktop（Linux 容器） | 🟡 云 Mac（arm64，自动建 native） |
| **ChromeOS** | 🟠 仅 Crostini（x86_64 完整 / arm64 需建 native） | ❌ 无通用嵌套虚拟化 | ➖ | 🟠 Crostini 内可装（无 KVM，构建慢） | ➖（Chromebook 当瘦客户端，按云端 OS 处理） |

### 逐格说明

- **Linux 物理/VM/VDI（x86_64）**：`install.sh` + `verify.sh`，本机与 GitHub Actions 均实测 9/9。
- **Linux arm64**：安装器与容器均会在检测到 aarch64 时自动 `make ghidra_opt` 构建
  `os/linux_arm_64`；`docker-arm64` CI 用原生 arm64 runner 实测；裸机 arm64 无 CI runner（仅文档）。
- **WSL2**：在 WSL 发行版内执行 `bash install.sh`；Docker 用 Docker Desktop WSL2 后端。
- **Windows 10/11 x64 物理/VM/VDI**：`install.ps1` / `verify.ps1` / `uninstall.ps1`，用户态免管理员，
  windows-latest CI 实测 9/9；REA Windows P0 只支持**固定本地 NTFS**，不支持网络/UNC/重解析点路径。
- **Windows on ARM64**：Ghidra 官方无 `win_arm64` native，REA 不支持该组合，标 ❌（文档如实说明）。
- **macOS**：`install-macos.sh` 三件套；Apple Silicon 上自动构建 `mac_arm_64` 并解除 Gatekeeper 隔离，
  macos-latest（arm64）CI 实测 9/9；Intel（`macos-13`）无 CI runner，脚本支持但仅文档化。
- **Apple Silicon 虚拟机**：Virtualization 框架只能跑 arm64 guest，不能跑 x86_64 虚拟机（Rosetta 只转译单个程序）。
- **ChromeOS**：本体 ❌；唯一途径是 **Crostini（Linux 开发环境，Debian 容器）**，其中复用 Linux 流程。
  x86_64 Chromebook 完整、ARM64 需构建 `linux_arm_64`；无 CI runner（仅文档化）；Crostini 内可装 Docker，
  但不支持通用嵌套虚拟化。

## 二、CPU 架构与 native decompiler

| 架构 | Ghidra native 目录 | 官方是否预编译 | 本项目处理 |
| --- | --- | --- | --- |
| Linux x86_64 | `os/linux_x86_64/decompile` | ✅ 预编译 | 直接校验存在 |
| Linux arm64 | `os/linux_arm_64/decompile` | ❌ 不预编译 | 安装器 / Dockerfile 自动 `make ghidra_opt` |
| Windows x86_64 | `os/win_x86_64/decompile.exe` | ✅ 预编译 | 直接校验存在 |
| Windows ARM64 | —（无） | ❌ 官方不支持 | ❌ |
| macOS Intel | `os/mac_x86_64/decompile` | 🟡 个别版本仅源码 | 缺失时自动构建 |
| macOS Apple Silicon | `os/mac_arm_64/decompile` | ❌ 不预编译 | 安装器自动 `make ghidra_opt ARCH_TYPE="-arch arm64"` |

> Mach-O 中 C 函数符号带前导下划线（`_secret_check`）；三个 verify 脚本统一用
> `rea search --kind procedures` 解析真实函数名后再反编译。

## 三、CI 实测覆盖（GitHub Actions）

| 作业 | runner | 内容 | 频率 |
| --- | --- | --- | --- |
| `lint-build` | ubuntu-latest | ShellCheck 全量 `.sh` + 版本一致性 + 编译 demo | 每次 push/PR |
| `lint-ps` | ubuntu-latest（pwsh） | PowerShell 语法解析 + PSScriptAnalyzer（Error/Warning 均失败） | 每次 push/PR |
| `e2e (linux)` | ubuntu-latest x64 | install.sh + verify.sh（ELF）9/9 | 每周/手动 |
| `e2e (macos)` | macos-latest **arm64** | install-macos.sh + 构建 `mac_arm_64` + verify-macos.sh（Mach-O）9/9 | 每周/手动 |
| `e2e (windows)` | windows-latest **x64** | install.ps1 + verify.ps1（PE fixture）9/9 | 每周/手动 |
| `docker` | ubuntu-latest x64 | 构建 amd64 镜像并在容器内跑 verify.sh | 每周/手动 |
| `docker-arm64` | ubuntu-24.04-arm（Public preview） | 原生构建 arm64 镜像（含 `linux_arm_64` 编译）+ 容器内 verify.sh | 每周/手动 |

无法 CI 实跑、仅文档化的组合：**ChromeOS（任何形态）**、**macOS Intel（macos-13）**、**裸机 Linux arm64**、
**各类云电脑 VDI**（与普通 OS 同脚本，差异在资源/网络策略）。

## 四、脚本与文件速查

| 系统 | 安装 | 验证 | 卸载 | 文档 |
| --- | --- | --- | --- | --- |
| Linux / WSL2 / Crostini / Linux VDI | `install.sh` | `verify.sh` | `uninstall.sh` | [platform-linux.md](platform-linux.md) |
| Windows x64 | `install.ps1` | `verify.ps1` | `uninstall.ps1` | [platform-windows.md](platform-windows.md) |
| macOS | `install-macos.sh` | `verify-macos.sh` | `uninstall-macos.sh` | [platform-macos.md](platform-macos.md) |
| ChromeOS（Crostini） | 容器内 `install.sh` | 容器内 `verify.sh` | 容器内 `uninstall.sh` | [platform-chromeos.md](platform-chromeos.md) |
| Docker（任意宿主） | `Dockerfile` / `docker-compose.yml` | 容器内 `verify.sh` | 删镜像 | [platform-docker.md](platform-docker.md) |

跨平台共用：`config/versions.env`（版本单一事实源）、`lib/common.sh` / `lib/common.ps1`、
`scripts/detect-env.sh`（环境识别）、`scripts/build-ghidra-native.sh`（native 构建）、
`scripts/verify-check.js`（三端统一断言）。

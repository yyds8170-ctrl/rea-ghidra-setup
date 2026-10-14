# 平台 × 运行环境支持矩阵

> 本矩阵在 v1.3 建立结构，并随后续版本逐格补齐。状态含义：
>
> - ✅ **支持**：有对应脚本/镜像，且在 CI 或本机实测通过。
> - 🟡 **部分**：可用但有前提（如仅 x86_64、需要额外步骤）。
> - 🟠 **受限**：官方未预编译某组件 / 需自行构建 / 无 CI 实跑，仅文档化。
> - ❌ **不支持**：平台本身无法运行，或官方不支持。
> - 🚧 **规划中**：脚本/文档将在标注版本提供。
> - ➖ **不适用**：该组合在技术上不存在。
>
> 运行环境的安装逻辑**按操作系统组织**；物理机 / 虚拟机 / 云电脑（VDI）
> 主要复用对应 OS 的安装脚本，差异仅在资源、网络与嵌套虚拟化，文档逐环境说明。
> WSL 是 Windows 宿主上的 Linux 客户机，故其内部走 Linux 流程。

## 总览（随版本更新，当前进度见各版本）

| 操作系统 | 物理本机 | 虚拟机 | WSL | Docker 容器 | 云电脑 VDI |
| --- | --- | --- | --- | --- | --- |
| **Linux** | ✅ x86_64 / 🟠 arm64 | ✅ x86_64 / 🟠 arm64 | ✅ WSL2（即 Linux） | ✅ amd64 / 🟠 arm64 | ✅ x86_64 |
| **Windows** | 🚧 v1.6 | 🚧 v1.6（复用脚本） | 🟡 WSL2 内走 Linux | 🟡 Docker Desktop（Linux 容器） | 🚧 v1.6 |
| **macOS** | 🚧 v1.5（x64 完整 / arm64 需自建 native） | 🚧 v1.5（Apple Silicon 仅 arm64 guest） | ➖ | 🟡 Docker Desktop（Linux 容器） | 🚧 v1.5（云 Mac 为 arm64） |
| **ChromeOS** | 🟠 仅 Crostini（v1.7，x86_64 可行 / arm64 受限） | ➖ | ➖ | 🟠 Crostini 内可装，嵌套受限 | ➖（多为连接远程 VDI，按其 OS 处理） |

> 说明：
> - **WSL 列**：WSL 是 Windows 的功能，其客户机是 Linux。因此「Windows + WSL」
>   与「Linux + WSL」在容器内实际都执行 `install.sh`（Linux 流程）。
> - **Docker 列**：Windows / macOS 的 Docker Desktop 运行的是 Linux 容器，
>   走 `Dockerfile`（`linux/amd64`）；`linux/arm64` 因官方不预编译 Ghidra native
>   decompiler（`os/linux_arm_64`）需自行构建。
> - **云电脑 VDI**：本质是远程的 Windows 或 Linux 桌面，按客户机 OS 选脚本，
>   额外注意离线授权、资源配额与网络策略。

## 关键架构事实（来自官方资料，详见各平台文档）

- **Ghidra 12.1.4 官方预编译 native decompiler**：
  - Linux x86_64、Windows x86_64、macOS x86_64：**官方自带**。
  - Linux arm64（`os/linux_arm_64`）、macOS arm64（`os/mac_arm_64`）：
    **官方不预编译，需自行构建**（`make ghidra_opt`，步骤见各平台文档）。
- **JDK**：Ghidra 12.x 要求 **JDK 21**（Temurin 各平台均有）。
- **Node / REA**：REA `rea-agents` 要求 Node `^22.19 || ^24.11 || >=26`。
- **ChromeOS**：本体不能直接运行 JDK/Ghidra；唯一官方途径是
  Crostini（设置 → 高级 → Linux 开发环境，Debian 容器），其中复用 Linux 流程。

## 版本补齐计划（目标，可能随实测调整）

| 版本 | 主题 |
| --- | --- |
| v1.3 | 版本单一事实源 + 文档/矩阵骨架（本版本） |
| v1.4 | Linux 加固（物理机/虚拟机/WSL/VDI 逐环境文档 + 安装健壮性） |
| v1.5 | macOS 支持（Intel + Apple Silicon） |
| v1.6 | Windows 支持（PowerShell 三件套） |
| v1.7 | ChromeOS 支持（Crostini 文档化） |
| v1.8 | 跨平台 CI matrix（ubuntu / windows / macos runner） |
| v1.9 | Docker 多架构（amd64/arm64）+ compose |
| v2.0 | 本矩阵总表定稿 + README 快速开始重构 |
| v2.1 | 跨平台技能 / doctor 诊断 / MCP 配置 |
| v2.2 | 校验和 + 离线安装 + 发布工程，全量复验 |

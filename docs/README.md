# 文档导航

本目录按「操作系统 + 运行环境」组织 REA + Ghidra 的部署、验证与使用文档。

## 快速选择

| 你的系统 | 安装脚本 | 验证脚本 | 卸载脚本 | 详细文档 |
| --- | --- | --- | --- | --- |
| **Linux**（物理机 / 虚拟机 / WSL2 / 云电脑 VDI / Crostini） | `install.sh` | `verify.sh` | `uninstall.sh` | [platform-linux.md](platform-linux.md) |
| **macOS**（Intel / Apple Silicon / 云 Mac） | `install-macos.sh` | `verify-macos.sh` | `uninstall-macos.sh` | [platform-macos.md](platform-macos.md) |
| **Windows**（物理机 / 虚拟机 / 云电脑 VDI） | `install.ps1` | `verify.ps1` | `uninstall.ps1` | [platform-windows.md](platform-windows.md) |
| **ChromeOS**（仅 Crostini Linux 开发环境） | 复用 `install.sh` | 复用 `verify.sh` | 复用 `uninstall.sh` | [platform-chromeos.md](platform-chromeos.md) |
| **Docker**（任意宿主，含 WSL2 / VDI / Crostini） | `Dockerfile` / `docker-compose.yml` | 容器内 `verify.sh` | 删除镜像 | [platform-docker.md](platform-docker.md) |

> 各平台专档（Linux / macOS / Windows / ChromeOS / Docker）均已就位；逐项验证状态见
> [platform-support-matrix.md](platform-support-matrix.md)。

> **不确定选哪行？** 先运行 `bash scripts/detect-env.sh`（或 `--json` / `--shell`），
> 它会报告你的操作系统、CPU 架构、运行环境（physical / wsl / crostini / docker / vm）、
> Ghidra native 目录及推荐安装脚本。

## 快速开始

- [entry.md](entry.md)：统一入口 `rea-ghidra` 子命令全表、self-update 校验、current/rollback 用法与边界。

## 通用文档

### 使用
- [mcp.md](mcp.md)：MCP 客户端一键注册 + stdio 连接自检（`--list/--dry-run/--check`）。
- [export.md](export.md)：Ghidra 静态分析导出（functions/strings/symbols/calls/decompiled JSON/C）。
- [batch.md](batch.md)：批量并行分析 + 快照缓存（`--jobs/--snapshot/失败隔离/summary.json`）。
- [offline.md](offline.md)：离线 / 内网（air-gapped）安装——`prepare-offline` 准备已校验离线包，`OFFLINE_DIR` 离线安装，镜像 save/load。

### 配置与供应链
- [configuration.md](configuration.md)：环境变量调优（内存/超时）、MCP server 接入、代理与镜像。
- [mirrors.md](mirrors.md)：国内镜像加速（`REA_MIRROR=cn`）+ 校验防篡改说明。

### 运维
- [troubleshooting.md](troubleshooting.md)：跨平台常见问题（JDK 版本、Node 门禁、Gatekeeper、native 构建、Windows PATH/路径、Docker 等）。
- [platform-support-matrix.md](platform-support-matrix.md)：4 系统 × 5 运行环境（物理机 / 虚拟机 / WSL / Docker / 云电脑 VDI）支持矩阵，逐项标注「支持 / 部分 / 受限 / 不支持」及原因。

## 版本

- 版本号单一事实源：[`config/versions.env`](../config/versions.env)（Ghidra / JDK / Node / REA 锁定版本）。
- 变更历史见根目录 [`README.md`](../README.md#版本历史) 的「版本历史」；发布标签见 GitHub Releases。

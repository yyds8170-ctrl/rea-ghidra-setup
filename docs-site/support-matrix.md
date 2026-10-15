[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/support-matrix/) | 简体中文

# 平台 × 环境支持矩阵

下表是摘要。完整的「4 系统 × 5 运行环境」逐项状态（含已知限制、CI 矩阵链接）见
[docs/platform-support-matrix.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-support-matrix.md)。

## 摘要

| 系统 / 环境 | x86_64 | arm64 / Apple Silicon | 备注 |
|---|---|---|---|
| Linux 物理机 / 虚拟机 | ✅ 完整 | ✅ 自动构建 native | WSL2 同 Linux |
| Windows 10/11 物理机 / 虚拟机 / VDI | ✅ 完整 | ⚠ 走 WSL2/CI | 用户态免管理员 |
| macOS Intel | ✅ 完整 | — | — |
| macOS Apple Silicon | — | ✅ 自动构建 native、去隔离属性 | |
| ChromeOS Crostini | ✅ 完整（x86_64） | ⚠ 需自建 native | 进 Linux 容器后走 Linux 流程 |
| Docker 任意宿主 | ✅ amd64 镜像 | ✅ arm64 镜像 | 非 root、HEALTHCHECK 只做文件探针 |

## 功能矩阵（核心子命令）

| 功能 | Linux | macOS | Windows | Docker | ChromeOS |
|---|---|---|---|---|---|
| `install` | ✅ | ✅ | ✅ | ✅（build 时） | ✅（容器内） |
| `doctor` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `verify` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mcp` | ✅ | ✅ | ✅ | ⚠ 容器内建议手配 | ✅ |
| `export` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `batch` | ✅ | ✅ | ✅（Start-Job） | ✅ | ✅ |
| `self-update` | ✅ | ✅ | ✅ | ⚠ 容器内不建议 | ✅ |
| `current` / `rollback` | ✅ | ✅ | ✅（junction） | ⚠ 单版本 | ✅ |
| `fixtures`（交叉编译） | ✅ | ✅ | ⚠ WSL/CI | ✅ | ⚠ 需装交叉工具链 |
| `walkthrough` | ✅ | ✅ | ⚠ WSL/CI | ✅ | ✅ |

图例：✅ 一等支持 · ⚠ 有条件支持/有已知限制 · — 不适用。

## 报告与链接

- 平台专属安装细节：[install.md](install.md)
- 排错：[docs/troubleshooting.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/troubleshooting.md)
- CI 实际跑的矩阵（badge）：见根 README 顶部的 CI badge 链接。

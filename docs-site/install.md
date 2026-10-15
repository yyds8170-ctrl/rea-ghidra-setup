[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/install/) | 简体中文

# 安装指南

> 不确定自己的环境？先跑 `bash scripts/detect-env.sh`（Windows 下跑 `pwsh scripts/detect-env.ps1`），它会识别系统/架构/运行环境并给出推荐命令。

## 选哪个？

| 环境 | 安装命令 | 验证命令 | 详细文档 |
|---|---|---|---|
| Linux 物理机 / 虚拟机 / WSL2 / 云电脑 | `./rea-ghidra install` | `./rea-ghidra verify` | [platform-linux.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-linux.md) |
| macOS（Intel / Apple Silicon） | `./rea-ghidra install` | `./rea-ghidra verify` | [platform-macos.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-macos.md) |
| Windows 10/11 x64 | `.\rea-ghidra.ps1 install` | `.\rea-ghidra.ps1 verify` | [platform-windows.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-windows.md) |
| ChromeOS（Crostini） | 进入 Linux 容器后走 Linux 流程 | 同 Linux | [platform-chromeos.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-chromeos.md) |
| Docker（任意宿主） | `docker build -t rea-ghidra .` | 容器内 `verify.sh` | [platform-docker.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-docker.md) |

## 最常用命令

```bash
# Linux / macOS：一键装 + 一键验
./rea-ghidra install
./rea-ghidra verify
./rea-ghidra doctor        # 只读环境自检
```

```powershell
# Windows：免管理员，用户态解压到 %LOCALAPPDATA%
.\rea-ghidra.ps1 install
.\rea-ghidra.ps1 verify
```

```bash
# Docker：多架构构建（amd64 / arm64）
docker build -t rea-ghidra .
docker run --rm --entrypoint bash rea-ghidra /opt/rea-ghidra-setup/verify.sh
# 或直接用 docker-compose
docker compose run --rm --entrypoint bash rea /opt/rea-ghidra-setup/verify.sh
```

## 离线 / 内网环境

没有外网时，先在一台有网机器上准备离线包：

```bash
bash scripts/prepare-offline.sh        # 拉 Ghidra/JDK/Node 到 offline/
# 把整个仓库（含 offline/）拷到内网机器，再：
REA_OFFLINE=1 ./rea-ghidra install
```

详见 [docs/offline.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/offline.md)。

## 国内镜像

下载慢或被墙时，设置：

```bash
export REA_MIRROR=tsinghua     # 或 ustc / aliyun
./rea-ghidra install
```

镜像切换逻辑与可用源列表见 [docs/mirrors.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/mirrors.md)。

## 卸载

```bash
# Linux / macOS
./uninstall.sh           # 或 uninstall-macos.sh
# Windows
.\uninstall.ps1
```

卸载脚本只删除本仓库安装到 `~/tools`（Windows：`%LOCALAPPDATA%\Programs`）的产物，不碰系统 JDK。

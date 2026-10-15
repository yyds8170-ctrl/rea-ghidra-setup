[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/faq/) | 简体中文

# 常见问题 FAQ

## Windows 需要管理员权限吗？

不需要。Windows 安装器走用户态解压到 `%LOCALAPPDATA%\Programs`，不写 `C:\Program Files`、不改系统 PATH、不动注册表 Run 键。需要管理员的只有极少数场景（如自定义 JDK 到系统目录），脚本会明确提示并退出，不会强行提权。

## 下载太慢 / 被墙怎么办？

```bash
export REA_MIRROR=tsinghua     # 或 ustc / aliyun
./rea-ghidra install
```

镜像逻辑与可用源见 [docs/mirrors.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/mirrors.md)。

## 完全没有外网的内网机器怎么装？

先在一台有网机器上跑 `bash scripts/prepare-offline.sh` 把 Ghidra/JDK/Node 拉到 `offline/`，把整个仓库（含 `offline/`）拷进内网，然后 `REA_OFFLINE=1 ./rea-ghidra install`。详见 [docs/offline.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/offline.md)。

## 需要哪个 JDK？

安装器自带并使用 **JDK 21**（便携解压到 `~/tools`，Windows 到 `%LOCALAPPDATA%\Programs`）。**不要**用系统 JDK 17 或更早版本——Ghidra 12.x 要求 JDK 21+。安装器会用自己解压的 JDK，不污染 `JAVA_HOME`。

## 怎么卸载？

```bash
# Linux / macOS
./uninstall.sh           # macOS 用 uninstall-macos.sh
# Windows
.\uninstall.ps1
```

卸载只删除本仓库安装到 `~/tools` / `%LOCALAPPDATA%\Programs` 的产物。你自己系统里装的 JDK、其他工具不动。

## self-update 安全吗？会把我本地改动覆盖吗？

- git 工作副本：只跑 `git pull --ff-only`，**拒绝 merge / force**；工作区有未提交改动时先提示、**不会自动 stash 或覆盖**。
- release tarball：下载 `<tag>.tar.gz` 与同名 `.checksums.txt`，sha256 不一致即拒绝；被替换的旧文件备份到 `.self-update-backup-<时间戳>/`，可整体回滚。
- 本地产物 `offline/`、`examples/fixtures/`、`.git/` **永不触碰**。

先用 `./rea-ghidra self-update --check` 看会更新什么，再决定是否真跑。

## 三个平台功能完全对等吗？

核心 install / doctor / verify / export / batch / mcp 在 Linux、macOS、Windows 上行为一致。差异主要在：

- `fixtures` 与 `walkthrough` 子命令在 Windows 上提示走 WSL/CI（不支持原生 Windows 编译跨架构 fixture）；
- arm64 Linux 与 Apple Silicon 上 native 库由安装器现场构建；
- 详细矩阵见 [support-matrix.md](support-matrix.md) 与 [docs/platform-support-matrix.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-support-matrix.md)。

## 合规与署名？

本项目采用 **PolyForm Noncommercial 1.0.0** 协议，维护者署名「洋洋」（[yyds8170-ctrl](https://github.com/yyds8170-ctrl)）。项目是**独立第三方**部署工具，不分发 Ghidra/REA 二进制，与 NSA、morluto 无隶属/背书关系。完整法律文本见
[LICENSE](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/LICENSE)、
[NOTICE](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/NOTICE)、
[TRADEMARKS](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/TRADEMARKS.md)。

## 还有别的问题？

- 根 README FAQ：[README.md#常见问题](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/README.md)
- 排错手册：[docs/troubleshooting.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/troubleshooting.md)
- 提 issue：[GitHub Issues](https://github.com/yyds8170-ctrl/rea-ghidra-setup/issues)

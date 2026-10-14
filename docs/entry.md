# 统一入口 `rea-ghidra`（v3.0）

一条命令收敛前几版散落的脚本。入口是**极薄分发层**：定位仓库根、选择对应脚本、透传参数并保留退出码；真实逻辑仍在 `install.sh` / `verify.sh` / `scripts/*`，不复制实现。

## 用法

| 平台 | 入口 |
|---|---|
| Linux / macOS | `./rea-ghidra <子命令> [参数...]` |
| Windows（PS 5.1/7） | `.\rea-ghidra.ps1 <子命令> [参数...]` |

## 子命令全表

| 子命令 | 作用 | 透传到 |
|---|---|---|
| `install` | 安装 JDK21 + Ghidra + 便携 Node（自动区分 Linux/macOS） | install.sh / install-macos.sh / install.ps1 |
| `doctor` | 只读环境自检 | scripts/doctor.{sh,ps1} |
| `verify` | 端到端验证（9 项分析/反编译断言） | verify.{sh,macos,ps1} |
| `mcp ...` | MCP 客户端对接，如 `mcp --check`、`mcp --dry-run --client claude-desktop` | scripts/mcp-setup.{sh,ps1} |
| `export ...` | Ghidra 静态导出，如 `export ./examples/demo --out /tmp/out --kind all` | scripts/ghidra-export.{sh,ps1} |
| `batch ...` | 批量并行 + 快照缓存 | scripts/batch-analyze.{sh,ps1} |
| `fixtures` | 交叉编译多架构 fixture（i686/aarch64/mingw 交叉工具链） | scripts/build-fixtures.sh（Windows 提示走 WSL/CI） |
| `walkthrough` | 端到端中文演练（幂等只读） | examples/walkthrough.sh（Windows 提示走 WSL/CI） |
| `version [--check]` | 打印 VERSION；`--check` 联网查 GitHub 最新 release（只读、离线降级） | — |
| `self-update [--check|--dry-run]` | 自更新（见下） | — |
| `current` | 列出 `~/tools` 下 Ghidra/JDK 版本与 current 软链指向 | — |
| `rollback` | 多版本并存时把 current 切回上一个 | — |
| `help` / `--help` | 中文用法 | — |

## 快速开始

```bash
# Linux / macOS
./rea-ghidra install
./rea-ghidra verify
./rea-ghidra mcp --check

# Windows
.\rea-ghidra.ps1 install
.\rea-ghidra.ps1 verify
```

## self-update 与校验

- **git 工作副本**（存在 `.git`）：仅 `git pull --ff-only`，拒绝 merge/force；工作区有未提交改动时先提示、**不自动 stash/覆盖**。
- **非 git（Release tarball 解压）**：从 GitHub 下载最新 `rea-ghidra-setup-<tag>.tar.gz` **与同名 `.checksums.txt`**，用 sha256 强校验——不一致或取不到 checksums 即拒绝退出；解压后覆盖脚本/文档，被替换的旧文件统一备份到 `.self-update-backup-<时间戳>/`（可整体拷回回滚）。`config/versions.env` 会随 release 刷新到上游新锁定版本（旧版已在备份目录可恢复）；而本地产物 `offline/`、`examples/fixtures/` 与 `.git/` **永不触碰**。bash 与 PowerShell 行为一致。
- `--check` / `--dry-run`：只报告当前→最新版本、是否需更新，**不写盘**。
- CI 里只跑 `self-update --check`，绝不真正升级。

## current / rollback 与边界

- 安装器在 `~/tools` 用 `ln -sfn`（Windows junction `mklink /J`）原子维护 `current-ghidra` / `current-jdk` 指向当前生效版本目录；发现逻辑优先读 current，再回退枚举版本化目录（旧行为不回归）。
- `rea-ghidra current`：列出所有 `ghidra_*_PUBLIC` / `jdk-21*` 与软链指向。
- `rea-ghidra rollback`：当存在 ≥2 个 Ghidra 版本化目录时切到另一个，并记录切换前到 `~/tools/current.previous`；只有一个版本时明确告知“无可回滚版本”。
- **诚实边界**：config 只锁定一个 Ghidra/JDK 版本，同版本重装不产生多版本；rollback 只在用户手工并存多个版本目录时生效，**不会自动下载旧版本**。

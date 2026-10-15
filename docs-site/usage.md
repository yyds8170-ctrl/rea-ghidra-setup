[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/usage/) | 简体中文

# 使用手册：统一入口 `rea-ghidra`

`rea-ghidra`（Linux/macOS 是 bash 脚本，Windows 是 `rea-ghidra.ps1`）是一个**极薄分发层**：定位仓库根、选择对应平台脚本、透传参数并保留退出码。真实逻辑仍在 `install.sh` / `verify.sh` / `scripts/*`。

## 子命令全表

| 子命令 | 作用 | 透传到 |
|---|---|---|
| `install` | 安装 JDK21 + Ghidra + 便携 Node | install.sh / install-macos.sh / install.ps1 |
| `doctor` | 只读环境自检 | scripts/doctor.{sh,ps1} |
| `verify` | 端到端 9 项分析/反编译断言 | verify.{sh,macos,ps1} |
| `mcp ...` | MCP 客户端注册与自检 | scripts/mcp-setup.{sh,ps1} |
| `export ...` | Ghidra 静态导出 JSON/伪代码 | scripts/ghidra-export.{sh,ps1} |
| `batch ...` | 批量并行 + 快照缓存 | scripts/batch-analyze.{sh,ps1} |
| `self-update [--check\|--dry-run]` | 自更新（强校验 sha256） | — |
| `current` | 列出 `~/tools` 下 Ghidra/JDK 版本与 current 软链 | — |
| `rollback` | 多版本并存时切回上一个 | — |
| `version [--check]` | 打印 VERSION；`--check` 查 GitHub 最新 release | — |
| `help` | 中文用法 | — |

详细说明见 [docs/entry.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/entry.md)。

## 常用片段

### doctor：环境自检

```bash
./rea-ghidra doctor          # 只读，不写盘；列出 JDK/Ghidra/Node/GHIDRA_INSTALL_DIR 状态
```

### verify：端到端验证

```bash
./rea-ghidra verify           # 跑 9 项断言（字符串/常量/函数名/xref），全过=0
```

### mcp：注册到 Claude Desktop / Cursor 等

```bash
./rea-ghidra mcp --list                          # 看本机识别到哪些客户端
./rea-ghidra mcp --dry-run --client claude-desktop
./rea-ghidra mcp --client claude-desktop --yes
./rea-ghidra mcp --check                         # stdio 握手 + provider 体检
```

支持客户端与配置路径见 [docs/mcp.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/mcp.md)。

### export：单目标静态导出

```bash
./rea-ghidra export ./examples/demo --out /tmp/out --kind all
# --kind: functions|strings|symbols|calls|decompiled|all
```

产物字段（functions.json / strings.json / symbols.json / calls.json / decompiled.json）见
[docs/export.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/export.md)。

### batch：批量并行 + 缓存

```bash
./rea-ghidra batch --dir ./bins --recurse --pattern '*.elf' \
  --kind all --jobs 4 --snapshot ./cache --continue
```

并行模型、失败隔离与 summary.json 见
[docs/batch.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/batch.md)。

### self-update / current / rollback

```bash
./rea-ghidra self-update --check      # 只报告，不写盘
./rea-ghidra self-update              # git 副本走 git pull --ff-only；release 包走 sha256 校验
./rea-ghidra current                  # 列出所有版本化目录与 current 软链指向
./rea-ghidra rollback                 # 切回上一个 Ghidra 版本（需手工并存多个版本）
```

!!! warning "诚实边界"
    `config/versions.env` 每次只锁定一个 Ghidra/JDK 版本；rollback **不会自动下载旧版本**，只在你手工并存了多个版本目录时生效。self-update 在 git 工作副本里只做 `git pull --ff-only`，工作区有未提交改动会先提示、**不会自动 stash/覆盖**。

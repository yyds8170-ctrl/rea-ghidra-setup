# REA 全量能力地图 / REA Capability Map

> 覆盖 **rea-agents 6.8.0** 的全部 **175 个命令**，按 10 个领域分组、逐条中英双语记录。
> Covers all **175 commands** of **rea-agents 6.8.0**, grouped into 10 domains with bilingual entries.
> 数据基线 / Baseline：2026-11-05 逐条 `--help` 与 `--llms-full` 实测。另有 `completions` / `mcp` 两个集成入口，见 [integrations.md](integrations.md)。

## 总数核对 / Count reconciliation

任务最初以"176 个命令"表述，经逐条实测确认 **Commands 段实为 175 个**；底部另有 `completions`、`mcp` 两个 Integration 入口（不计入 Commands）。本文件与 [coverage-matrix.md](coverage-matrix.md)、`config/command-baseline/rea-6.8.0.txt` 的命令名逐字一致。

The often-quoted "176 commands" resolves to **175 actual Commands**; two additional Integration entries (`completions`, `mcp`) are listed separately and not counted.

## 领域导航 / Domain navigation

| 领域 / Domain | 文件 / File | 命令数 / Count |
|---|---|---|
| ① 核心 / Ghidra 原生分析 Core native analysis | [domain-1-core.md](domain-1-core.md) | 20 |
| ② 离线二进制 ELF/PE/Mach-O/Go/Rust Offline binary | [domain-2-binary.md](domain-2-binary.md) | 20 |
| ③ 动态调试 / 运行时 / UI Dynamic & runtime | [domain-3-dynamic.md](domain-3-dynamic.md) | 15 |
| ④ Web / JS / Electron | [domain-4-web.md](domain-4-web.md) | 28 |
| ⑤ Android / APK / ADB | [domain-5-android.md](domain-5-android.md) | 33 |
| ⑥ Apple / macOS / iOS | [domain-6-apple.md](domain-6-apple.md) | 9 |
| ⑦ 多格式 WASM/EVM/pyc/BEAM/SQLite/pcap Multiformat | [domain-7-multiformat.md](domain-7-multiformat.md) | 15 |
| ⑧ 固件 / 嵌入式 / Flutter·Dart / HarmonyOS Firmware | [domain-8-firmware.md](domain-8-firmware.md) | 9 |
| ⑨ Evidence 与工程化 Evidence & engineering | [domain-9-evidence.md](domain-9-evidence.md) | 16 |
| ⑩ JEB 商业软件 + 平台自身 JEB & platform | [domain-10-jeb-platform.md](domain-10-jeb-platform.md) | 10 |
| **合计 / Total** | | **175** |
| 附录：集成入口 Integrations | [integrations.md](integrations.md) | 2 |
| 全量覆盖矩阵 Coverage matrix | [coverage-matrix.md](coverage-matrix.md) | 175 行 |

## 可测性图例 / Testability legend

| 固定写法 / Label | 数量 | 含义 / Meaning |
|---|---|---|
| ✅ 本机可实测 / Testable on Linux | 78 | 纯静态解析或平台自检，本环境可跑并验证 / static parsing or self-check, runnable here |
| 🔧 需安装工具 / Requires tool | 35 | 装好对应 CLI 后可在 Linux 验证 / verifiable on Linux once the tool is installed |
| 📱 需真机/设备 / Requires device | 50 | 依赖 adb/frida/浏览器等真机或运行时，本环境**未实测** / needs device or runtime, not tested here |
| 🍎 需 macOS / Requires macOS | 8 | 仅 Apple 平台，本环境**未实测** / Apple-only, not tested here |
| 💼 需商业软件 JEB / Requires JEB | 4 | JEB 命令，本环境**未实测** / needs commercial JEB, not tested here |
| **合计 / Total** | **175** | |

> 凡未在本环境真实跑通的条目，正文均保留"未实测 / 需 XX 前置"字样，未写成已实现。
> Entries not actually run here are explicitly marked as not tested / requiring a prerequisite.

## 全局选项（不重复灌入每条）/ Global options

下列开关对所有命令通用，统一在此说明，各领域条目只写该命令专属参数：

These flags apply globally and are not repeated per entry; domain files list only command-specific flags.

| 选项 / Option | 作用 / Purpose |
|---|---|
| `--format <toon\|json\|yaml\|md\|jsonl>` | 输出格式 / output format |
| `--schema` | 打印该命令的 JSON Schema / print JSON Schema |
| `--filter-output <keys>` | 按键路径过滤输出 / filter output by key paths |
| `--full-output` | 显示完整输出信封 / show full envelope |
| `--llms` / `--llms-full` | 打印 LLM 可读清单 / LLM-readable manifest |
| `--token-count` / `--token-limit` / `--token-offset` | 输出 token 计数与截断 / token count and limiting |
| `--provider` / `--snapshot` | 选择分析 provider / 快照落盘（受支持命令）/ provider selection and snapshot |

## 版本基线与演进机制 / Version baseline & evolution tracking

- **入库基线 / Tracked baseline**：[`config/command-baseline/rea-6.8.0.txt`](../../config/command-baseline/rea-6.8.0.txt)（175 行、字典序、无表头）。
- **每周巡检 / Weekly audit**：自动拉取最新版 `rea --help` 命令清单，与基线做 `comm`/`git diff`，识别新增、移除、改名的命令，并据此更新能力地图。比对方法：

  ```bash
  # 仅在新版出现（新增）/ added in new version
  comm -13 config/command-baseline/rea-6.8.0.txt <new-sorted-list>
  # 仅在基线出现（移除）/ removed
  comm -23 config/command-baseline/rea-6.8.0.txt <new-sorted-list>
  ```

- 升级到后续 REA 版本时，在 `config/command-baseline/` 新增对应版本文件，旧基线保留以追踪演进。
- **运行时领域路由 / Runtime domain routing**：[`config/command-baseline/command-domain.tsv`](../../config/command-baseline/command-domain.tsv)（175 行：命令名/领域/可测性）供 `rea-ghidra run|domains|d1..d10` 在运行时校验命令合法性与领域归属；用法见 [command-wrapper.md](../command-wrapper.md)。

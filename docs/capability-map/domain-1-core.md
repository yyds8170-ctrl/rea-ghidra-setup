# 领域 ① · 核心 / Ghidra 原生（domain-1-core）

> REA 6.8.0 全量能力地图 · 本领域共 **20** 个命令 / 20 commands
> 数据底座：`research/B_commands_176.json`（rea-agents 6.8.0，2026-11-05）
> 可测性图例：✅ 本机可实测 / Testable on Linux · 🔧 需安装工具 / Requires tool · 📱 需真机 / Requires device · 🍎 需 macOS / Requires macOS · 💼 需商业软件 JEB / Requires JEB

## 目录

1. [`address-to-file-offset`](#address-to-file-offset)
2. [`analyze`](#analyze)
3. [`annotate-native-function`](#annotate-native-function)
4. [`decompile`](#decompile)
5. [`decompile-all`](#decompile-all)
6. [`function`](#function)
7. [`inspect`](#inspect)
8. [`inspect-native-api`](#inspect-native-api)
9. [`inspect-native-data-type`](#inspect-native-data-type)
10. [`inspect-native-instruction`](#inspect-native-instruction)
11. [`inspect-native-load-image`](#inspect-native-load-image)
12. [`instructions`](#instructions)
13. [`match-native-functions`](#match-native-functions)
14. [`read-bytes`](#read-bytes)
15. [`resolve-native-call-targets`](#resolve-native-call-targets)
16. [`search`](#search)
17. [`search-bytes`](#search-bytes)
18. [`trace`](#trace)
19. [`trace-native-values`](#trace-native-values)
20. [`xrefs`](#xrefs)

---

### `address-to-file-offset`

- **用途 / Purpose**：将分析地址（analysis address）解析回其在原始文件中的字节偏移。Resolve an analysis address to its original file byte offset.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea address-to-file-offset <path> <address> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `analyze`

- **用途 / Purpose**：获取一个应用的总体概览（格式/架构/函数数/字符串等）。Get an overview of an app.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`、`--integrity-policy`、`--source-path`、`--source-paths-json`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea analyze <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra provider）/ Requires tool. 本环境已用 Ghidra 12.1.4 真实跑通（verify.sh 9/9）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `annotate-native-function`

- **用途 / Purpose**：编辑函数注解（命名/注释），并返回刷新后的分析结果。Edit function annotations and return refreshed analysis.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--name`、`--comment`、`--inline-comment`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea annotate-native-function <path> <procedure> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `decompile`

- **用途 / Purpose**：以伪代码读取应用的某一部分；位置参数 address 与 `--procedure` 至少给一个，也可单独使用 `--file-offset`；两者取值相等时接受，冲突则报错。Read one part of an app as code. Supply at least one of the positional address or `--procedure`. Alternatively, use `--file-offset` alone. Equal positional and `--procedure` values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--procedure`、`--file-offset`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea decompile <path> [address] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `decompile-all`

- **用途 / Purpose**：将每个函数的伪代码写入输出目录，并返回 manifest 清单。Write every function's pseudocode into a directory and return a manifest.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--output`、`--layout`、`--resume`、`--name`、`--namespace`、`--address-start`、`--address-end`、`--limit`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：落盘——写入输出目录（每个函数的伪代码）+ manifest 清单。Writes output directory + manifest; every function pseudocode is persisted to disk.
- **示例 / Example**：
  ```bash
  rea decompile-all <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `function`

- **用途 / Purpose**：带 evidence 完整分析单个函数；位置参数 address 与 `--procedure` 至少给一个，取值相等时接受，冲突则报错。Analyze one complete function with evidence. Supply at least one of the positional address or `--procedure`. Equal values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--procedure`、`--snapshot`、`--detail`、`--evidence_output`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea function <path> [address] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `inspect`

- **用途 / Purpose**：带 evidence 检查应用总体概览。Inspect an app overview with evidence.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `inspect-native-api`

- **用途 / Purpose**：带 evidence 重建单个原生函数的 API 边界；位置参数 address 与 `--procedure` 至少给一个，取值相等时接受，冲突则报错。Reconstruct one native function API boundary with evidence. Supply at least one of the positional address or `--procedure`. Equal values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--procedure`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-native-api <path> [address] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `inspect-native-data-type`

- **用途 / Purpose**：检查一个恢复出的数据库类型或带类型的数据对象。Inspect one recovered database type or typed data object.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--type`、`--address`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-native-data-type <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `inspect-native-instruction`

- **用途 / Purpose**：检查单条原生指令及其解码后的操作数事实。Inspect one native instruction with decoded operand facts.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-native-instruction <path> <address> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `inspect-native-load-image`

- **用途 / Purpose**：校验已加载的原生字节、源映射、重定位与入口点。Verify loaded native bytes, source mappings, relocations and entry.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-native-load-image <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `instructions`

- **用途 / Purpose**：不反编译，逐条读取全部原始指令；位置参数 address 与 `--procedure` 至少给一个，取值相等时接受，冲突则报错。Read every raw instruction without decompiling. Supply at least one of the positional address or `--procedure`. Equal values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--procedure`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea instructions <path> [address] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `match-native-functions`

- **用途 / Purpose**：不执行目标，匹配两份观测到的原生函数清单。Match two observed native function inventories without executing targets.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--source_bundle`、`--evidence_output`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea match-native-functions <input> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `read-bytes`

- **用途 / Purpose**：在指定分析地址读取 provider 的精确内存字节。Read exact provider memory bytes at one analysis address.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--length`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea read-bytes <path> <address> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `resolve-native-call-targets`

- **用途 / Purpose**：解析一个静态原生调用点（call site）。Resolve one static native call site.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea resolve-native-call-targets <path> <address> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `search`

- **用途 / Purpose**：搜索所有已分析字符串或过程名；位置参数 pattern 与 `--pattern` 至少给一个，取值相等时接受，冲突则报错。Search every analyzed string or procedure name. Supply at least one of the positional pattern or `--pattern`. Equal values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--pattern`、`--kind`、`--mode`、`--case-sensitive`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea search <path> [pattern] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `search-bytes`

- **用途 / Purpose**：在已初始化的 provider 内存中查找带掩码的字节模式。Find masked byte patterns in initialized provider memory.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--mask`、`--start`、`--end`、`--cursor`、`--limit`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea search-bytes <path> <pattern> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `trace`

- **用途 / Purpose**：沿已分析引用追踪一个字面特征；位置参数 query 与 `--query` 至少给一个，取值相等时接受，冲突则报错。Trace a literal feature through analyzed references. Supply at least one of the positional query or `--query`. Equal values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--query`、`--case-sensitive`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea trace <path> [query] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `trace-native-values`

- **用途 / Purpose**：有界追踪原生 def-use 与调用依赖。Trace bounded native def-use and call dependencies.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--max-depth`、`--max-functions`、`--max-call-sites`、`--max-nodes`、`--max-edges`、`--offset`、`--limit`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea trace-native-values <path> <procedure> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

### `xrefs`

- **用途 / Purpose**：列出对某已分析地址的有界交叉引用；位置参数 address 与 `--address` 至少给一个，取值相等时接受，冲突则报错。List bounded references to an analyzed address. Supply at least one of the positional address or `--address`. Equal values are accepted; conflicts fail.
- **前置与外部工具 / Prerequisites & external tools**：需配置原生分析 provider（Ghidra ≥12.1 / Hopper / IDA / Kuna），并已载入目标二进制作为分析对象。A native analysis provider (Ghidra ≥12.1 / Hopper / IDA / Kuna) configured, with a target binary loaded.
- **关键参数 / Key flags**：`--address`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea xrefs <path> [address] [options]
  ```
- **可测性 / Testability**：🔧 需安装工具（Ghidra ≥12.1 / Hopper / IDA / Kuna provider）/ Requires tool. 本环境未实测/需配置原生分析 provider 并载入目标二进制前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea ；[docs] https://github.com/morluto/rea/blob/HEAD/docs/cli.md

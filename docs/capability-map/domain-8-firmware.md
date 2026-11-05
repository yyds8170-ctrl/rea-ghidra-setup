# 领域⑧ · 固件 / 嵌入式 / Flutter / Dart / HarmonyOS

> 基线：rea-agents 6.8.0（2026-11-05），数据底座 `research/B_commands_176.json`。
> **本领域 9 个命令 / 9 commands in this domain。**
> 可测性分布：✅ linux-testable 9 条（全部为静态解析；部分解包器另需安装解包工具）。

## 目录 / TOC

- [`extract-artifact`](#extract-artifact)
- [`extract-firmware`](#extract-firmware)
- [`identify-flutter-build`](#identify-flutter-build)
- [`inspect-dart-aot`](#inspect-dart-aot)
- [`inspect-desktop-application`](#inspect-desktop-application)
- [`inspect-devicetree`](#inspect-devicetree)
- [`inspect-firmware-regions`](#inspect-firmware-regions)
- [`inspect-kernel-module`](#inspect-kernel-module)
- [`project-harmony-application-graph`](#project-harmony-application-graph)

---

### `extract-artifact`

- **用途 / Purpose**：解包支持的归档内容；DMG 解包不可用。Extract regular contents of supported artifacts; DMG extraction is unavailable.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--integrity-policy`
- **Evidence 产出 / Evidence outputs**：把归档内容解包到磁盘。
- **示例 / Example**：
  ```bash
  rea extract-artifact <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 静态解包，部分解包器另需系统解包工具；本批文档未逐条跑通，合并前由实施者在 Linux 验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `extract-firmware`

- **用途 / Purpose**：解包选定的固件字节范围，返回已校验文件与溯源信息。Extract selected firmware bytes and return verified files and provenance.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--offset`、`--length`、`--max-depth`、`--max-output-bytes`、`--max-output-files`、`--publication-timeout-ms`、`--analysis-timeout-ms`
- **Evidence 产出 / Evidence outputs**：把已校验的解包固件文件写出到目录。
- **示例 / Example**：
  ```bash
  rea extract-firmware <path> <outputDirectory> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 静态解包；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `identify-flutter-build`

- **用途 / Purpose**：通过纯 APK 解析识别 Flutter 构建的 Dart snapshot hash 与引擎事实。Identify a Flutter build's Dart snapshot hash and engine facts by pure APK parsing.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea identify-flutter-build <path>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯 APK 静态解析；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-dart-aot`

- **用途 / Purpose**：检查某一 ABI 的 Dart AOT snapshot：节、头与字符串池。Inspect one ABI's Dart AOT snapshot: sections, headers, and the string pool.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--abi`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-dart-aot <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态 snapshot 解析；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-desktop-application`

- **用途 / Purpose**：基于有界目录与文件头观察，识别桌面运行时候选。Identify desktop runtime candidates from bounded directory and header observations.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--max_entries`、`--detail`、`--evidence_output`、`--max_probe_bytes`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-desktop-application <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯目录/文件头探测；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-devicetree`

- **用途 / Purpose**：在不执行 flattened devicetree blob 的前提下检查其内容。Inspect a flattened devicetree blob without executing it.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-nodes`、`--max-properties`、`--max-depth`、`--detail`、`--evidence_output`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-devicetree <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯 DTB 静态解析；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-firmware-regions`

- **用途 / Purpose**：不解包，直接检查固件中的签名候选区域。Inspect firmware signature candidates without extracting them.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--analysis-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-firmware-regions <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯固件区域扫描；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-kernel-module`

- **用途 / Purpose**：在不执行模块的前提下检查 Linux 内核模块元数据。Inspect Linux kernel module metadata without executing the module.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-entries`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-kernel-module <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯内核模块 ELF 静态解析；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `project-harmony-application-graph`

- **用途 / Purpose**：把已认证的 HarmonyOS HAP / HSP / App Pack 清单 Evidence 投影为应用 graph。Project authenticated HarmonyOS HAP, HSP, or App Pack inventory Evidence into an application graph.
- **前置与外部工具 / Prerequisites & external tools**：输入为固件/嵌入式归档（静态解析）；部分解包器需要另外安装解包工具。A firmware/embedded artifact (static parse); some extractors need installed unpack tools.
- **关键参数 / Key flags**：无命令专属参数（投影输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea project-harmony-application-graph <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯 Evidence JSON 投影，无需真机；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

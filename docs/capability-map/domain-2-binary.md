# 领域 ② · 离线二进制 ELF / PE / Mach-O / Go / Rust（domain-2-binary）

> REA 6.8.0 全量能力地图 · 本领域共 **20** 个命令 / 20 commands
> 数据底座：`research/B_commands_176.json`（rea-agents 6.8.0，2026-11-05）
> 可测性图例：✅ 本机可实测 / Testable on Linux · 🔧 需安装工具 / Requires tool · 📱 需真机 / Requires device · 🍎 需 macOS / Requires macOS · 💼 需商业软件 JEB / Requires JEB

## 目录

1. [`compare-managed-members`](#compare-managed-members)
2. [`inspect-artifact`](#inspect-artifact)
3. [`inspect-binary-layout`](#inspect-binary-layout)
4. [`inspect-byte-entropy`](#inspect-byte-entropy)
5. [`inspect-elf-notes`](#inspect-elf-notes)
6. [`inspect-go-binary`](#inspect-go-binary)
7. [`inspect-macho`](#inspect-macho)
8. [`inspect-managed-artifact`](#inspect-managed-artifact)
9. [`inspect-managed-members`](#inspect-managed-members)
10. [`inspect-managed-native-boundaries`](#inspect-managed-native-boundaries)
11. [`inspect-native-exports`](#inspect-native-exports)
12. [`inspect-pe-certificates`](#inspect-pe-certificates)
13. [`inspect-pe-imports`](#inspect-pe-imports)
14. [`inspect-pe-load-config`](#inspect-pe-load-config)
15. [`inspect-pe-resources`](#inspect-pe-resources)
16. [`inspect-rust-binary`](#inspect-rust-binary)
17. [`inspect-signature`](#inspect-signature)
18. [`inspect-with-objdump`](#inspect-with-objdump)
19. [`list-architectures`](#list-architectures)
20. [`list-objdump-architectures`](#list-objdump-architectures)

---

### `compare-managed-members`

- **用途 / Purpose**：按声明类型、名称与签名精确比较两个 PE/CLI 托管成员清单；仅凭名称永不构成匹配。Compare managed PE/CLI member inventories by exact declared type, name, and signature; names alone never form a match.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：无专属命令级参数 / none（全局参数统一见 README）。
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea compare-managed-members <leftPath> <rightPath>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-artifact`

- **用途 / Purpose**：检查单个 artifact，返回全部可用观测与下一步探测建议。Inspect one artifact and return all available observations and next probes.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--integrity-policy`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea inspect-artifact <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-binary-layout`

- **用途 / Purpose**：不执行所选目标对象，检查二进制文件/链接布局。Inspect binary file/linked layout without executing the selected object.
- **前置与外部工具 / Prerequisites & external tools**：调用方在 Linux x64 上自备 pwntools。Caller-supplied pwntools on Linux x64.
- **关键参数 / Key flags**：`--pwntools-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-binary-layout <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `pwntools`（调用方自备，Linux x64）/ Requires tool. 本环境未实测/需 pwntools 前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-byte-entropy`

- **用途 / Purpose**：不执行文件，检查文件级与分块字节熵。Inspect file-wide and block byte entropy without executing the file.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--block-size`、`--offset`、`--length`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-byte-entropy <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-elf-notes`

- **用途 / Purpose**：不执行镜像，检查 ELF PT_NOTE 与 SHT_NOTE 标识。Inspect ELF PT_NOTE and SHT_NOTE identities without executing the image.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-entries`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-elf-notes <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-go-binary`

- **用途 / Purpose**：不执行目标，检查内嵌的 Go 编译器、modules 与构建设置。Inspect embedded Go compiler, modules and build settings without target execution.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--architecture`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea inspect-go-binary <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-macho`

- **用途 / Purpose**：不启动 Hopper，运行 inspect_macho 做 Mach-O 静态检查。Run inspect_macho without launching Hopper.
- **前置与外部工具 / Prerequisites & external tools**：目标为 Mach-O / Swift / ObjC artifact（静态解析，无需 Hopper）。A Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required).
- **关键参数 / Key flags**：`--native-command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-macho <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（静态解析 Mach-O，无需 Hopper / 无需 macOS）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-managed-artifact`

- **用途 / Purpose**：不加载目标代码，检查 PE/CLI 身份信息。Inspect PE/CLI identity without loading target code.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：无专属命令级参数 / none（全局参数统一见 README）。
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-managed-artifact <path>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-managed-members`

- **用途 / Purpose**：不加载目标代码，检查 PE/CLI 元数据成员、签名、CIL 锚点与 ldstr 字符串字面量。Inspect PE/CLI metadata members, signatures, CIL anchors, and ldstr string literals without loading target code.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--type`、`--detail`、`--evidence-bundle`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-managed-members <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-managed-native-boundaries`

- **用途 / Purpose**：不加载目标代码，检查 PE/CLI PInvoke 与原生实现边界声明。Inspect PE/CLI PInvoke and native implementation boundary declarations without loading target code.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：无专属命令级参数 / none（全局参数统一见 README）。
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-managed-native-boundaries <path>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-native-exports`

- **用途 / Purpose**：不执行镜像，检查 PE 或 ELF 镜像的导出表。Inspect a PE or ELF image's export table without executing it.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--detail`、`--evidence_output`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea inspect-native-exports <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-pe-certificates`

- **用途 / Purpose**：不验证签名，检查 PE Authenticode 证书表标识。Inspect PE Authenticode certificate table identities without verifying signatures.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-entries`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-pe-certificates <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-pe-imports`

- **用途 / Purpose**：不执行镜像，检查 PE 导入表与延迟加载（delay-load）表标识。Inspect PE import and delay-load table identities without executing the image.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-dlls`、`--max-functions`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-pe-imports <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-pe-load-config`

- **用途 / Purpose**：不执行镜像，检查 PE TLS 回调与加载配置。Inspect PE TLS callbacks and load configuration without executing the image.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-callbacks`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-pe-load-config <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-pe-resources`

- **用途 / Purpose**：检查 PE 资源标识、payload 范围、哈希与图标组（icon-group）关系。Inspect PE resource identities, payload ranges, hashes and icon-group relationships.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-entries`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-pe-resources <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-rust-binary`

- **用途 / Purpose**：不执行目标，检查内嵌的 cargo-auditable Rust 依赖清单。Inspect an embedded cargo-auditable Rust dependency list without target execution.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--architecture`、`--view`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea inspect-rust-binary <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯静态解析，不执行目标文件）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-signature`

- **用途 / Purpose**：不启动 Hopper，运行 inspect_signature 做签名检查。Run inspect_signature without launching Hopper.
- **前置与外部工具 / Prerequisites & external tools**：目标为 Mach-O / Swift / ObjC artifact（静态解析，无需 Hopper）。A Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required).
- **关键参数 / Key flags**：`--native-command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-signature <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（静态解析 Mach-O，无需 Hopper / 无需 macOS）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-with-objdump`

- **用途 / Purpose**：用 GNU objdump 检查本地 artifact，并将其原始输出保留为 Evidence。Inspect a local artifact with GNU objdump and retain its raw output as Evidence.
- **前置与外部工具 / Prerequisites & external tools**：已安装 GNU objdump（binutils）。GNU objdump (binutils) installed.
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--symbol`、`--follow-debug-links`、`--command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle（含 objdump 原始输出）写入文件（落盘）。Writes canonical Evidence bundle (with raw objdump output) via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea inspect-with-objdump <path> <file_headers|section_headers|symbols|relocations|dwarf|disassemble|disassemble_all> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 GNU `objdump`（binutils）/ Requires tool. 本环境未实测/需 binutils 前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-architectures`

- **用途 / Purpose**：不启动 Hopper，运行 list_architectures 列出架构。Run list_architectures without launching Hopper.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--native-command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--format json` 向 stdout 返回规范 Evidence JSON；除非显式指定参数，否则不产生副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-architectures <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（静态列出，无需 Hopper / 无需 macOS）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-objdump-architectures`

- **用途 / Purpose**：列出已安装 GNU objdump 所支持的 BFD targets。List BFD targets advertised by the installed GNU objdump.
- **前置与外部工具 / Prerequisites & external tools**：已安装 GNU objdump（binutils）。GNU objdump (binutils) installed.
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 将规范 Evidence bundle 写入文件（落盘）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea list-objdump-architectures [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 GNU `objdump`（binutils）/ Requires tool. 本环境未实测/需 binutils 前置。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

# 领域 ⑦ · 多格式（Multi-format：WASM / EVM / pyc / BEAM / SQLite / pcap 等）

> 本领域共 **15 个命令**。数据底座：`research/B_commands_176.json`（rea-agents 6.8.0）。
> 其中纯静态解析类（Erlang BEAM、EVM、GPU code object、IL2CPP、模型权重头、pyc、SQLite、pcap-client 自检）可在 Linux 实测；依赖 WABT / tshark / sigrok 等外部工具的命令本环境**未实测/需对应工具前置**。

## 目录 / Table of contents

1. [`compare-wasm-interfaces`](#compare-wasm-interfaces)
2. [`decode-signal-recording`](#decode-signal-recording)
3. [`inspect-erlang-beam`](#inspect-erlang-beam)
4. [`inspect-evm-interface`](#inspect-evm-interface)
5. [`inspect-gpu-code-objects`](#inspect-gpu-code-objects)
6. [`inspect-il2cpp-metadata`](#inspect-il2cpp-metadata)
7. [`inspect-model-artifact`](#inspect-model-artifact)
8. [`inspect-packet-capture`](#inspect-packet-capture)
9. [`inspect-packet-fields`](#inspect-packet-fields)
10. [`inspect-pcap-capture`](#inspect-pcap-capture)
11. [`inspect-pcap-client`](#inspect-pcap-client)
12. [`inspect-python-pyc`](#inspect-python-pyc)
13. [`inspect-signal-decoders`](#inspect-signal-decoders)
14. [`inspect-sqlite-database`](#inspect-sqlite-database)
15. [`inspect-wasm-artifact`](#inspect-wasm-artifact)

---

### `compare-wasm-interfaces`

- **用途 / Purpose**：对比两份精确 inspect Evidence 记录中的核心 WASM 接口。Compare core WASM interfaces from two exact inspection Evidence records.
- **前置与外部工具 / Prerequisites & external tools**：已安装 WABT（wasm-objdump / wasm2wat）。WABT (wasm-objdump / wasm2wat) installed.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-wasm-interfaces <input>
  ```
- **可测性 / Testability**：🔧 需安装工具 `WABT`（wasm-objdump / wasm2wat）/ Requires tool —— 装好 WABT 后可在 Linux 验证；本环境**未实测/需 WABT 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `decode-signal-recording`

- **用途 / Purpose**：用调用方提供的 sigrok 解码一份已有的信号录制。Decode an existing signal recording with caller-supplied sigrok.
- **前置与外部工具 / Prerequisites & external tools**：调用方提供的 sigrok + sigrok-decoders；（解码时）一份 sigrok 录制。caller-supplied sigrok + sigrok-decoders; (for decode) a sigrok recording.
- **关键参数 / Key flags**：`--decoders`、`--input_format`、`--annotations`、`--line_offset`、`--line_limit`、`--all_lines`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea decode-signal-recording <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `sigrok` + `sigrok-decoders` / Requires tool —— 装好后可在 Linux 验证；本环境**未实测/需 sigrok + 录制前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-erlang-beam`

- **用途 / Purpose**：不执行字节码，检查 Erlang BEAM 的 atoms、exports、imports 与 Code 头。Inspect Erlang BEAM atoms, exports, imports and Code header without executing bytecode.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-chunks`、`--max-atoms`、`--detail`、`--evidence_output`、`--view`
- **Evidence 产出 / Evidence outputs**：按 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-erlang-beam <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-evm-interface`

- **用途 / Purpose**：从显式提供的本地 EVM 字节码推断接口候选。Infer interface candidates from explicit local EVM bytecode.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-evm-interface <path> <raw|hex> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-gpu-code-objects`

- **用途 / Purpose**：检查内嵌的 CUDA/HIP 目标及选定的静态 kernel 元数据。Inspect embedded CUDA/HIP targets and selected static kernel metadata.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--view`、`--analysis`、`--expected_sha256`、`--object_ids`、`--targets`
- **Evidence 产出 / Evidence outputs**：按 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-gpu-code-objects <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-il2cpp-metadata`

- **用途 / Purpose**：盘点 IL2CPP global-metadata.dat 中的 names、owners 与字符串字面量；可选从 native 二进制关联方法地址。Inventory IL2CPP global-metadata.dat names, owners and string literals, optionally linking method addresses from the native binary.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--binary`、`--architecture`、`--generic-instances`、`--ghidra-seeds`、`--seed-base`
- **Evidence 产出 / Evidence outputs**：按 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-il2cpp-metadata <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-model-artifact`

- **用途 / Purpose**：不加载模型权重，只检查 GGUF 或 safetensors 头。Inspect GGUF or safetensors headers without loading model weights.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--view`、`--hash`
- **Evidence 产出 / Evidence outputs**：按 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-model-artifact <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-packet-capture`

- **用途 / Purpose**：用调用方提供的 TShark 检查一份已有数据包捕获。Inspect an existing packet capture with caller-supplied TShark.
- **前置与外部工具 / Prerequisites & external tools**：已安装 tshark + capinfos（Wireshark）。tshark + capinfos (Wireshark) installed.
- **关键参数 / Key flags**：`--fields`、`--display_filter`、`--decode_as`、`--packet_limit`、`--two_pass`、`--match_offset`、`--match_limit`、`--all_matches`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-packet-capture <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `tshark` + `capinfos`（Wireshark）/ Requires tool —— 装好后可在 Linux 验证；本环境**未实测/需 Wireshark 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-packet-fields`

- **用途 / Purpose**：搜索已安装 TShark 的协议与字段定义。Search installed TShark protocol and field definitions.
- **前置与外部工具 / Prerequisites & external tools**：已安装 tshark + capinfos（Wireshark）。tshark + capinfos (Wireshark) installed.
- **关键参数 / Key flags**：`--kind`、`--protocol`、`--query`、`--offset`、`--limit`、`--all`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-packet-fields [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `tshark` + `capinfos`（Wireshark）/ Requires tool —— 装好后可在 Linux 验证；本环境**未实测/需 Wireshark 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-pcap-capture`

- **用途 / Purpose**：检查一份 pcap/pcapng 捕获：端点、DNS、TLS SNI 与协议分布。Inspect one pcap/pcapng capture: endpoints, DNS, TLS SNI, and protocol distribution.
- **前置与外部工具 / Prerequisites & external tools**：已安装 tshark + capinfos（Wireshark）。tshark + capinfos (Wireshark) installed.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-pcap-capture <path>
  ```
- **可测性 / Testability**：🔧 需安装工具 `tshark` + `capinfos`（Wireshark）/ Requires tool —— 装好后可在 Linux 验证；本环境**未实测/需 Wireshark 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-pcap-client`

- **用途 / Purpose**：不读取捕获文件，仅检查调用方选定的 tshark 与 capinfos 二进制。Inspect the caller-selected tshark and capinfos binaries without reading a capture.
- **前置与外部工具 / Prerequisites & external tools**：对应启动器二进制（adb/apktool/tshark）在 PATH 上。The corresponding launcher binary (adb/apktool/tshark) on PATH.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-pcap-client
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 平台自检类命令（探测 PATH 上的客户端二进制），本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-python-pyc`

- **用途 / Purpose**：不执行字节码，检查受支持的 CPython 3.7–3.13 pyc 头与 marshal code object。Inspect a supported CPython 3.7–3.13 pyc header and marshal code objects without executing bytecode.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-objects`、`--max-depth`、`--max-string-bytes`、`--detail`、`--evidence_output`、`--view`
- **Evidence 产出 / Evidence outputs**：按 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-python-pyc <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-signal-decoders`

- **用途 / Purpose**：搜索已安装的 sigrok 解码器，或查看选定解码器的帮助。Search installed sigrok decoders or selected decoder help.
- **前置与外部工具 / Prerequisites & external tools**：调用方提供的 sigrok + sigrok-decoders；（解码时）一份 sigrok 录制。caller-supplied sigrok + sigrok-decoders; (for decode) a sigrok recording.
- **关键参数 / Key flags**：`--decoder`、`--query`、`--offset`、`--limit`、`--all`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-signal-decoders [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `sigrok` + `sigrok-decoders` / Requires tool —— 装好后可在 Linux 验证；本环境**未实测/需 sigrok 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-sqlite-database`

- **用途 / Purpose**：从本地快照检查 SQLite schema 及可选的普通表行。Inspect SQLite schema and optional ordinary-table rows from a local snapshot.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析 / none, built-in。
- **关键参数 / Key flags**：`--worker-timeout-ms`、`--table`、`--column`、`--schema-scope`、`--row-limit`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-sqlite-database <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-wasm-artifact`

- **用途 / Purpose**：用 WABT 检查一个显式指定的本地 WASM 产物。Inspect an explicit local WASM artifact with WABT.
- **前置与外部工具 / Prerequisites & external tools**：已安装 WABT（wasm-objdump / wasm2wat）。WABT (wasm-objdump / wasm2wat) installed.
- **关键参数 / Key flags**：`--command-timeout-ms`、`--glue_paths`、`--candidate_paths`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-wasm-artifact <path> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `WABT`（wasm-objdump / wasm2wat）/ Requires tool —— 装好 WABT 后可在 Linux 验证；本环境**未实测/需 WABT 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

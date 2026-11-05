# 领域 ③ · 动态调试 / 运行时 / UI 观察（Dynamic Debugging / Runtime / UI Observation）

> 本领域共 **15 个命令**。数据底座：`research/B_commands_176.json`（rea-agents 6.8.0）。
> 本领域多依赖真机/运行时会话、GDB/Rizin/Cutter/Frida 等外部调试器，凡未在本环境真实跑通的均标注"未实测/需 XX 前置"。

## 目录 / Table of contents

1. [`capture-native-ui-scenario`](#capture-native-ui-scenario)
2. [`capture-process`](#capture-process)
3. [`compare-process-captures`](#compare-process-captures)
4. [`cutter-command`](#cutter-command)
5. [`debug-with-gdb`](#debug-with-gdb)
6. [`debug-with-rizin`](#debug-with-rizin)
7. [`execute-rizin-command`](#execute-rizin-command)
8. [`inspect-recorded-crash`](#inspect-recorded-crash)
9. [`instrument-with-frida`](#instrument-with-frida)
10. [`list-cutter-sessions`](#list-cutter-sessions)
11. [`list-frida-devices`](#list-frida-devices)
12. [`list-frida-processes`](#list-frida-processes)
13. [`observe-native-calls`](#observe-native-calls)
14. [`observe-native-ui`](#observe-native-ui)
15. [`trace-native-ui-action`](#trace-native-ui-action)

---

### `capture-native-ui-scenario`

- **用途 / Purpose**：在某个精确的原生应用窗口内，按声明式方式执行一组 AX（accessibility）动作或等待。Run declarative AX actions or waits in one exact native application window.
- **前置与外部工具 / Prerequisites & external tools**：一个活着的进程 / UI 会话。A live process / UI session.
- **关键参数 / Key flags**：`--pid`、`--window-id`、`--screenshot`、`--accessibility`、`--max-nodes`、`--native-ui-deadline-ms`、`--steps`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea capture-native-ui-scenario <path> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖存活进程与原生 UI 会话，本环境**未实测/需真机或运行时会话前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `capture-process`

- **用途 / Purpose**：捕获一个由调用方选定的进程运行场景。Capture one caller-selected process scenario.
- **前置与外部工具 / Prerequisites & external tools**：一个活着的进程 / UI 会话。A live process / UI session.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea capture-process <scenario>
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖存活进程场景，本环境**未实测/需真机或运行时会话前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare-process-captures`

- **用途 / Purpose**：对比两份进程捕获得到的 Evidence JSON 文件。Compare two process capture Evidence JSON files.
- **前置与外部工具 / Prerequisites & external tools**：一个活着的进程 / UI 会话。A live process / UI session.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-process-captures <left> <right> [traceSpec]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 输入来自进程捕获产物，本环境**未实测/需真机或运行时会话前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `cutter-command`

- **用途 / Purpose**：在一个已连接的活跃 Cutter 实例中执行一条 Rizin 命令。Execute one Rizin command in a selected live Cutter instance.
- **前置与外部工具 / Prerequisites & external tools**：一个活跃的 Cutter 实例 + REA Python 插件桥接。A live Cutter instance + REA Python plugin bridge.
- **关键参数 / Key flags**：`--json-output`、`--json`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea cutter-command <sessionId> <expectedGeneration> <command> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `Cutter`（及 REA Python 插件桥接）/ Requires tool —— 本环境**未实测/需 Cutter + 插件桥接前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `debug-with-gdb`

- **用途 / Purpose**：在一个临时的 GDB MI 会话中执行一条不受限的 GDB 控制台命令；提供 inferior TTY，以便在 attach 存活目标后安全 detach。Run one unrestricted GDB console command in an ephemeral MI session; provide an inferior TTY so a live target can be safely detached.
- **前置与外部工具 / Prerequisites & external tools**：已安装 GDB；一个存活的调试目标（inferior）。GDB installed; a live target inferior.
- **关键参数 / Key flags**：`--inferior-tty`、`--detail`、`--evidence_output`
- **Evidence 产出 / Evidence outputs**：按 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea debug-with-gdb <command> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `GDB` / Requires tool —— 装好 GDB 后可在 Linux 验证；存活目标部分本环境**未实测/需 GDB + 存活 inferior 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `debug-with-rizin`

- **用途 / Purpose**：在一个临时会话中执行一条不受限的 Rizin 调试器命令。Run one unrestricted Rizin debugger command in an ephemeral session.
- **前置与外部工具 / Prerequisites & external tools**：已安装 Rizin（`rizin`）。Rizin (rizin) installed.
- **关键参数 / Key flags**：`--inferior-tty`、`--backend`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea debug-with-rizin <path> <command> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `Rizin` / Requires tool —— 装好 Rizin 后可在 Linux 验证；本环境**未实测/需 Rizin 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `execute-rizin-command`

- **用途 / Purpose**：对一个本地产物执行一条 Rizin 命令。Execute one Rizin command against a local artifact.
- **前置与外部工具 / Prerequisites & external tools**：已安装 Rizin（`rizin`）。Rizin (rizin) installed.
- **关键参数 / Key flags**：`--command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea execute-rizin-command <path> <command> [options]
  ```
- **可测性 / Testability**：🔧 需安装工具 `Rizin` / Requires tool —— 装好 Rizin 后可在 Linux 验证；本环境**未实测/需 Rizin 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-recorded-crash`

- **用途 / Purpose**：检查提供的 core 寄存器/信号，以及可选的调试器映射证据。Inspect supplied core registers/signals and optional debugger mapping evidence.
- **前置与外部工具 / Prerequisites & external tools**：一个活着的进程 / UI 会话。A live process / UI session.
- **关键参数 / Key flags**：`--debugger-context`、`--pwntools-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-recorded-crash <path> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖崩溃/调试上下文，本环境**未实测/需真机或运行时会话前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `instrument-with-frida`

- **用途 / Purpose**：对选定进程运行一个 Frida 脚本后 detach；`--script` 与 `--script-file` 必须二选一且仅给一个。Run one Frida script against a selected process and detach. Provide exactly one of --script or --script-file.
- **前置与外部工具 / Prerequisites & external tools**：已安装 frida / frida-tools；一个存活的目标进程或设备。frida / frida-tools installed; a live target process or device.
- **关键参数 / Key flags**：`--remote-address`、`--token`、`--certificate`、`--origin`、`--keepalive-interval`、`--device-id`、`--script`、`--script-file`、`--argument`、`--duration-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea instrument-with-frida <attach|spawn> <target> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖 Frida 与存活进程/设备，本环境**未实测/需 frida + 目标进程或设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-cutter-sessions`

- **用途 / Purpose**：列出通过 REA Python 插件桥接连接的活跃 Cutter 实例。List live Cutter instances connected through the REA Python plugin bridge.
- **前置与外部工具 / Prerequisites & external tools**：一个活跃的 Cutter 实例 + REA Python 插件桥接。A live Cutter instance + REA Python plugin bridge.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-cutter-sessions
  ```
- **可测性 / Testability**：🔧 需安装工具 `Cutter`（及 REA Python 插件桥接）/ Requires tool —— 本环境**未实测/需 Cutter + 插件桥接前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-frida-devices`

- **用途 / Purpose**：列出本地 Frida 设备，并可选列出一个远程端点。List local Frida devices and an optional remote endpoint.
- **前置与外部工具 / Prerequisites & external tools**：已安装 frida / frida-tools；一个存活的目标进程或设备。frida / frida-tools installed; a live target process or device.
- **关键参数 / Key flags**：`--remote-address`、`--token`、`--certificate`、`--origin`、`--keepalive-interval`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-frida-devices [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖 Frida 运行时与设备枚举，本环境**未实测/需 frida + 目标进程或设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-frida-processes`

- **用途 / Purpose**：列出通过某个 Frida 设备可见的进程。List processes visible through a Frida device.
- **前置与外部工具 / Prerequisites & external tools**：已安装 frida / frida-tools；一个存活的目标进程或设备。frida / frida-tools installed; a live target process or device.
- **关键参数 / Key flags**：`--remote-address`、`--token`、`--certificate`、`--origin`、`--keepalive-interval`、`--device-id`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-frida-processes [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖 Frida 设备进程枚举，本环境**未实测/需 frida + 目标进程或设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `observe-native-calls`

- **用途 / Purpose**：在 LLDB 下启动一个 Mach-O，并记录对选定函数或 Objective-C 方法的调用进入。Launch a Mach-O under LLDB and record entries into selected functions or Objective-C methods.
- **前置与外部工具 / Prerequisites & external tools**：macOS 宿主机、LLDB、一个 Mach-O 目标。macOS host, LLDB, a Mach-O target.
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea observe-native-calls <path> <inputJson>
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅 Apple 平台（LLDB + Mach-O），本环境为 Linux，**未实测/需 macOS + LLDB 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `observe-native-ui`

- **用途 / Purpose**：按 PID 与 window ID 观察一个已在运行的原生应用窗口。Observe one already-running native application window by PID and window ID.
- **前置与外部工具 / Prerequisites & external tools**：一个活着的进程 / UI 会话。A live process / UI session.
- **关键参数 / Key flags**：`--pid`、`--window-id`、`--screenshot`、`--accessibility`、`--max-nodes`、`--native-ui-deadline-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea observe-native-ui <path> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖存活原生 UI 会话，本环境**未实测/需真机或运行时会话前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-native-ui-action`

- **用途 / Purpose**：把一个已编译的 UI action selector 追溯到其 native handler 与直接被调用者。Trace a compiled UI action selector to its native handler and direct callees.
- **前置与外部工具 / Prerequisites & external tools**：一个活着的进程 / UI 会话。A live process / UI session.
- **关键参数 / Key flags**：`--max-depth`、`--max-nodes`、`--max-edges`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea trace-native-ui-action <path> <action> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖存活进程/UI 会话与 provider，本环境**未实测/需真机或运行时会话前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

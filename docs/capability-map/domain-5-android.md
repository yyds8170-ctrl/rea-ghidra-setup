# 领域⑤ · Android / APK / ADB 能力地图（rea-agents 6.8.0）

> 本领域共 **33 个命令**：其中 `adb-*` 设备侧命令 24 个（📱 需真机/模拟器），离线 APK 解析与投影类命令 9 个（✅ 本机可实测）。
> 基线版本：rea-agents 6.8.0（2026-11-05）。全局参数（`--format`、`--filter-output`、`--token-*` 等）见总索引 README，本文件不重复列出。

## 目录

- [`capture-adb-screen`](#capture-adb-screen)
- [`collect-adb-bugreport`](#collect-adb-bugreport)
- [`decode-android-resources`](#decode-android-resources)
- [`inspect-adb-client`](#inspect-adb-client)
- [`inspect-adb-device`](#inspect-adb-device)
- [`inspect-adb-display`](#inspect-adb-display)
- [`inspect-adb-package`](#inspect-adb-package)
- [`inspect-adb-window`](#inspect-adb-window)
- [`inspect-android-class`](#inspect-android-class)
- [`inspect-android-method`](#inspect-android-method)
- [`inspect-android-package`](#inspect-android-package)
- [`inspect-apk-signature`](#inspect-apk-signature)
- [`inspect-apktool-client`](#inspect-apktool-client)
- [`install-adb-package`](#install-adb-package)
- [`list-adb-devices`](#list-adb-devices)
- [`list-adb-directory`](#list-adb-directory)
- [`list-adb-features`](#list-adb-features)
- [`list-adb-packages`](#list-adb-packages)
- [`list-adb-processes`](#list-adb-processes)
- [`list-adb-services`](#list-adb-services)
- [`project-android-application-graph`](#project-android-application-graph)
- [`pull-adb-file`](#pull-adb-file)
- [`pull-adb-package`](#pull-adb-package)
- [`push-adb-file`](#push-adb-file)
- [`read-adb-logcat`](#read-adb-logcat)
- [`read-adb-setting`](#read-adb-setting)
- [`resolve-adb-packages`](#resolve-adb-packages)
- [`search-android-classes`](#search-android-classes)
- [`start-adb-activity`](#start-adb-activity)
- [`start-adb-app`](#start-adb-app)
- [`stop-adb-app`](#stop-adb-app)
- [`trace-android-references`](#trace-android-references)
- [`uninstall-adb-package`](#uninstall-adb-package)

---

### `capture-adb-screen`

- **用途 / Purpose**：截取当前屏幕一帧，输出为经过摘要消化（digested）的 PNG。Capture one screen frame as a digested PNG.
- **前置与外部工具 / Prerequisites & external tools**：`adb`（Android Debug Bridge）在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--output-directory`
- **Evidence 产出 / Evidence outputs**：写入经过摘要消化的 PNG 截图证据文件。Writes a digested PNG / capture artifact.
- **示例 / Example**：
  ```bash
  rea capture-adb-screen <serial> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `collect-adb-bugreport`

- **用途 / Purpose**：采集并摘要消化设备生成的一份 bugreport 归档。Collect and digest one device-generated bugreport archive.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--output-directory`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea collect-adb-bugreport <serial> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `decode-android-resources`

- **用途 / Purpose**：用 apktool 解码一个 APK 的 manifest、元数据与字符串资源。Decode one APK's manifest, metadata, and string resources with apktool.
- **前置与外部工具 / Prerequisites & external tools**：无命令级显式前置；解码过程内部调用 apktool（launcher 自检见 `inspect-apktool-client`）。No explicit command-level prerequisite; apktool is invoked internally.
- **关键参数 / Key flags**：`--locale`、`--string-tables-only`、`--locales`、`--decode-timeout-ms`、`--strings`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea decode-android-resources <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-adb-client`

- **用途 / Purpose**：在不接触任何设备的前提下，检查调用方选定的 adb 客户端本体。Inspect the caller-selected adb client without contacting devices.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-adb-client
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-adb-device`

- **用途 / Purpose**：通过固定的 getprop 白名单检查一台设备的构建标识。Inspect one device's build identity through a fixed getprop whitelist.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-adb-device <serial>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-adb-display`

- **用途 / Purpose**：报告显示屏声明的分辨率尺寸与密度。Report the display's declared size and density.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-adb-display <serial>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-adb-package`

- **用途 / Purpose**：通过 dumpsys 检查一个已安装包的版本、安装来源与 flags。Inspect one installed package's version, installer, and flags through dumpsys.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-adb-package <serial> <package>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-adb-window`

- **用途 / Purpose**：报告 window manager 当前的焦点窗口声明。Report the window manager's current focus declarations.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-adb-window <serial>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-android-class`

- **用途 / Purpose**：检查 APK 中某个确切类的成员清单。Inspect one exact APK class's member inventory.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析（目标为本地 APK 文件）。None, built-in parsing of a local APK.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-android-class <path> <className>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-android-method`

- **用途 / Purpose**：反编译 APK 中的一个方法，并可显式选择重载版本。Decompile one APK method with explicit overload selection.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析（目标为本地 APK 文件）。None, built-in parsing of a local APK.
- **关键参数 / Key flags**：`--overload-index`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-android-method <path> <className> <methodName> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-android-package`

- **用途 / Purpose**：在不执行 APK 的前提下检查其声明与解码后的 manifest。Inspect APK declarations and decoded manifest without executing it.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析（目标为本地 APK 文件）。None, built-in parsing of a local APK.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-android-package <path>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-apk-signature`

- **用途 / Purpose**：检查 APK 声明的签名方案、签名者与内容摘要。Inspect declared APK signing schemes, signers and content digests.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析（目标为本地 APK/ZIP/AAB）。None, built-in parsing of a local APK/ZIP/AAB.
- **关键参数 / Key flags**：`--detail <complete|summary>`、`--evidence_output <string>`、`--view <string>`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 写入规范 Evidence bundle（never overwrites）。Writes canonical Evidence bundle via `--evidence_output`.
- **示例 / Example**：
  ```bash
  rea inspect-apk-signature <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-apktool-client`

- **用途 / Purpose**：在不做任何解码的前提下，检查调用方选定的 apktool 启动器。Inspect the caller-selected apktool launcher without decoding anything.
- **前置与外部工具 / Prerequisites & external tools**：对应启动器二进制（adb/apktool/tshark）在 PATH 上。The corresponding launcher binary (adb/apktool/tshark) on PATH.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-apktool-client
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 需 apktool 在 PATH；本环境**未实测/需 apktool 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `install-adb-package`

- **用途 / Purpose**：安装一个本地 APK；`--replace` 请求重装模式以保留既有应用数据。Install one local APK; `--replace` requests reinstall mode to keep existing app data.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--replace`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea install-adb-package <serial> <apk-path> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**（该命令会修改设备状态，属破坏性操作）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-adb-devices`

- **用途 / Purpose**：列出已连接设备的序列号、状态、transport 类型与推断出的设备种类。List attached devices with serial, state, transport, and inferred kind.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-adb-devices
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-adb-directory`

- **用途 / Purpose**：列出设备上一个目录的条目类型、权限与大小。List one device directory with kinds, permissions, and sizes.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-adb-directory <serial> <device-path>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-adb-features`

- **用途 / Purpose**：列出设备声明的硬件与软件 feature。List the device's declared hardware and software features.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-adb-features <serial>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-adb-packages`

- **用途 / Purpose**：列出一台设备上已安装的包及其基础 APK 的设备路径。List installed packages on one device with base APK device paths.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--scope`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-adb-packages <serial> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-adb-processes`

- **用途 / Purpose**：按 `ps -A` 的原始输出列出运行中的进程。List running processes exactly as `ps -A` reports them.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-adb-processes <serial>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-adb-services`

- **用途 / Purpose**：列出设备的 binder 服务与接口。List the device's binder services and interfaces.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea list-adb-services <serial>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `project-android-application-graph`

- **用途 / Purpose**：把已认证的 APK 清单 Evidence 投影为一张 Android 应用图。Project authenticated APK inventory Evidence into an Android application graph.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线投影（输入为已认证的 Evidence JSON）。None, offline projection over authenticated Evidence JSON input.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea project-android-application-graph <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线投影；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `pull-adb-file`

- **用途 / Purpose**：把设备上一个文件拉取到本地副本，并附带 SHA-256 摘要。Pull one device file to a local copy with a SHA-256 digest.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--output-directory`
- **Evidence 产出 / Evidence outputs**：写出拉取的文件及其 SHA-256 摘要。Writes pulled files with SHA-256 digests.
- **示例 / Example**：
  ```bash
  rea pull-adb-file <serial> <device-path> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `pull-adb-package`

- **用途 / Purpose**：把一个已安装包的完整 APK 集合拉取下来，并附带 SHA-256 摘要。Pull one installed package's complete APK set with SHA-256 digests.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--output-directory`
- **Evidence 产出 / Evidence outputs**：写出拉取的文件及其 SHA-256 摘要。Writes pulled files with SHA-256 digests.
- **示例 / Example**：
  ```bash
  rea pull-adb-package <serial> <package> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `push-adb-file`

- **用途 / Purpose**：把一个本地文件推送到设备；目标已存在时若不加 `--overwrite` 会拒绝写入。Push one local file to the device; refuses existing targets without `--overwrite`.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--overwrite`
- **Evidence 产出 / Evidence outputs**：把本地文件推送到设备。Pushes a local file to device.
- **示例 / Example**：
  ```bash
  rea push-adb-file <serial> <local-path> <device-path> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**（该命令会写入设备文件系统）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `read-adb-logcat`

- **用途 / Purpose**：有界读取某个 logcat 缓冲区的设备日志转储。Read a bounded dump of the device log for one buffer.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--count <number>`、`--buffer <main|system|radio|events|crash>`、`--pid <number>`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea read-adb-logcat <serial> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `read-adb-setting`

- **用途 / Purpose**：从 system、secure 或 global 命名空间读取一个 settings 键值。Read one settings value from system, secure, or global.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea read-adb-setting <serial> <system|secure|global> <key>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `resolve-adb-packages`

- **用途 / Purpose**：按大小写不敏感的名称子串查找已安装包。Find installed packages by case-insensitive name substring.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea resolve-adb-packages <serial> <query>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `search-android-classes`

- **用途 / Purpose**：搜索 APK 中的类名；查询串为空时枚举全部类。Search APK class names; empty query inventories all classes.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析（目标为本地 APK 文件）。None, built-in parsing of a local APK.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea search-android-classes <path> <query>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `start-adb-activity`

- **用途 / Purpose**：通过 `am start` 发起一个 intent（action、URI、component、extras）。Start an intent with `am start` (action, URI, component, extras).
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：`--data-uri`、`--component`、`--extra`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea start-adb-activity <serial> <action> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**（该命令会在设备上启动 Activity）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `start-adb-app`

- **用途 / Purpose**：解析并启动一个已安装应用的 launcher activity。Start one installed app by resolving and launching its launcher activity.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea start-adb-app <serial> <package>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `stop-adb-app`

- **用途 / Purpose**：强制停止一个包的全部进程。Force-stop every process of one package.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea stop-adb-app <serial> <package>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**（该命令会强杀设备进程）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-android-references`

- **用途 / Purpose**：为一个类或选定方法追踪 APK 中指向它的使用（incoming use）节点。Trace incoming APK using nodes for a class or selected method.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析（目标为本地 APK 文件）。None, built-in parsing of a local APK.
- **关键参数 / Key flags**：`--method-name`、`--overload-index`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea trace-android-references <path> <className> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线解析；本环境仅核对 6.8.0 help，**未跑通样本 APK**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `uninstall-adb-package`

- **用途 / Purpose**：从设备上卸载一个包及其数据。Uninstall one package and its data from the device.
- **前置与外部工具 / Prerequisites & external tools**：`adb` 在 PATH 上；一台已连接的 Android 设备或模拟器。adb on PATH, plus an attached/connected Android device or emulator.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea uninstall-adb-package <serial> <package>
  ```
- **可测性 / Testability**：📱 需真机/设备 —— 本环境无 Android 设备，**未实测/需 adb + 已连接授权设备前置**（该命令会删除设备上的应用与数据，不可逆）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

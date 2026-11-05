# 领域 ⑥ · Apple / macOS / iOS（Apple / macOS / iOS）

> 本领域共 **9 个命令**。数据底座：`research/B_commands_176.json`（rea-agents 6.8.0）。
> 多数为 Apple 平台产物解析，依赖 macOS 目标产物；其中 `demangle-swift`、`inspect-native-dispatch-metadata` 为纯静态解析，可在 Linux 实测，其余本环境**未实测/需 Apple 产物或 macOS 前置**。

## 目录 / Table of contents

1. [`decode-interface-builder`](#decode-interface-builder)
2. [`demangle-swift`](#demangle-swift)
3. [`inspect-apple-ips`](#inspect-apple-ips)
4. [`inspect-asset-catalog`](#inspect-asset-catalog)
5. [`inspect-keyed-archive`](#inspect-keyed-archive)
6. [`inspect-native-dispatch-metadata`](#inspect-native-dispatch-metadata)
7. [`inspect-plist`](#inspect-plist)
8. [`project-apple-application-graph`](#project-apple-application-graph)
9. [`trace-dylib-resolution`](#trace-dylib-resolution)

---

### `decode-interface-builder`

- **用途 / Purpose**：解码应用 bundle 中已编译的 storyboard 与 nib 归档。Decode compiled storyboard and nib archives from an app bundle.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：`--max-documents`、`--max-objects`、`--max-connections`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea decode-interface-builder <path> [options]
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple 平台产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `demangle-swift`

- **用途 / Purpose**：无需 Hopper 即可对 Swift 符号进行 demangle（反修饰）。Demangle Swift symbols without Hopper.
- **前置与外部工具 / Prerequisites & external tools**：一个 Mach-O / Swift / ObjC 产物（静态解析，无需 Hopper）。A Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required).
- **关键参数 / Key flags**：`--native-command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea demangle-swift <path> <symbols...> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，不依赖 Apple 运行时，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-apple-ips`

- **用途 / Purpose**：无需执行目标，即可检查一份 Apple .ips 崩溃报告。Inspect an Apple .ips crash report without executing a target.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：`--max-file-bytes`、`--max-threads`、`--max-frames`、`--max-images`、`--max-registers`、`--max-integer-text-bytes`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-apple-ips <path> [options]
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple 崩溃报告产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-asset-catalog`

- **用途 / Purpose**：检查已编译的 Apple asset catalog 元数据。Inspect compiled Apple asset catalog metadata.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：`--offset`、`--limit`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-asset-catalog <path> [options]
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple asset catalog 产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-keyed-archive`

- **用途 / Purpose**：把一个 Foundation keyed archive 作为对象引用图进行检查。Inspect a Foundation keyed archive as an object-reference graph.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：`--root`、`--offset`、`--limit`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-keyed-archive <path> [archive] [options]
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple Foundation 归档产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-native-dispatch-metadata`

- **用途 / Purpose**：检查带类型的 Objective-C 与 Swift dispatch 元数据。Inspect typed Objective-C and Swift dispatch metadata.
- **前置与外部工具 / Prerequisites & external tools**：一个 Mach-O / Swift / ObjC 产物（静态解析，无需 Hopper）。A Mach-O / Swift / ObjC artifact (static parse; Hopper NOT required).
- **关键参数 / Key flags**：`--max-records`、`--max-input-bytes`、`--snapshot`、`--target-format`、`--architecture`、`--entry-point`、`--provider`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-native-dispatch-metadata <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析，不依赖 Apple 运行时，本环境可跑并验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-plist`

- **用途 / Purpose**：无需启动 Hopper 即可解析应用 plist 元数据。Parse app plist metadata without launching Hopper.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：`--relative-path`、`--native-command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-plist <path> [options]
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple plist 产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `project-apple-application-graph`

- **用途 / Purpose**：把已认证的 IPA 或 macOS app 清单 Evidence 投影成一棵 Apple 应用图。Project authenticated IPA or macOS app inventory Evidence into an Apple application graph.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：无命令级专属参数（none, command-level）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea project-apple-application-graph <inputJson>
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple 应用清单产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-dylib-resolution`

- **用途 / Purpose**：为一个 Mach-O、或为 app bundle 中每个可执行文件，追溯 dyld load-path 解析。Trace dyld load-path resolution for a Mach-O or every executable in an app bundle.
- **前置与外部工具 / Prerequisites & external tools**：Apple/macOS 或 iOS 产物（.app/.ipa/storyboard/plist）。Apple/macOS or iOS artifact (.app/.ipa/storyboard/plist).
- **关键参数 / Key flags**：`--root`、`--architecture`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea trace-dylib-resolution <path> [options]
  ```
- **可测性 / Testability**：🍎 需 macOS / Requires macOS —— 仅处理 Apple dyld/Mach-O 产物，本环境为 Linux，**未实测/需 Apple 产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

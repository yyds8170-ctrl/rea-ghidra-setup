# 领域④ · Web / JS / Electron

> 基线：rea-agents 6.8.0（2026-11-05），数据底座 `research/B_commands_176.json`。
> **本领域 28 个命令 / 28 commands in this domain。**
> 可测性分布：✅ linux-testable 11 条；📱 needs-device 17 条（均依赖已运行的 Chromium/Electron/Node CDP 端点）。

## 目录 / TOC

- [`analyze-javascript-application`](#analyze-javascript-application)
- [`analyze-web-bundle`](#analyze-web-bundle)
- [`capture-browser-scenario`](#capture-browser-scenario)
- [`capture-electron-scenario`](#capture-electron-scenario)
- [`capture-web-screenshot`](#capture-web-screenshot)
- [`compare-application-versions`](#compare-application-versions)
- [`compare-javascript-export-shapes`](#compare-javascript-export-shapes)
- [`compare-source-to-bundle`](#compare-source-to-bundle)
- [`compare-web-captures`](#compare-web-captures)
- [`compare-web-screenshots`](#compare-web-screenshots)
- [`discover-webmcp-tools`](#discover-webmcp-tools)
- [`export-web-scripts`](#export-web-scripts)
- [`inspect-electron-fuses`](#inspect-electron-fuses)
- [`inspect-electron-page`](#inspect-electron-page)
- [`inspect-web-event-listeners`](#inspect-web-event-listeners)
- [`inspect-web-network-capture`](#inspect-web-network-capture)
- [`inspect-web-page`](#inspect-web-page)
- [`list-browser-targets`](#list-browser-targets)
- [`list-electron-targets`](#list-electron-targets)
- [`list-javascript-runtime-targets`](#list-javascript-runtime-targets)
- [`observe-javascript-runtime`](#observe-javascript-runtime)
- [`observe-web-execution`](#observe-web-execution)
- [`observe-web-session`](#observe-web-session)
- [`reconcile-javascript-runtime`](#reconcile-javascript-runtime)
- [`recover-javascript-sources`](#recover-javascript-sources)
- [`trace-javascript-semantics`](#trace-javascript-semantics)
- [`trace-web-module-imports`](#trace-web-module-imports)
- [`trace-web-source-location`](#trace-web-source-location)

---

### `analyze-javascript-application`

- **用途 / Purpose**：静态重建一个本地 JavaScript / Electron 应用的结构与语义。Statically reconstruct a local JavaScript/Electron application.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；目标为本地 JS/Electron 应用目录。None, built-in static parser on a local JS/Electron application directory.
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--view`、`--max-semantic-nodes`、`--max-semantic-nodes-per-file`、`--max-semantic-unknowns`、`--max-semantic-unknowns-per-file`、`--source-path`、`--source-paths-json`、`--max-heap-mb`、`--analysis-timeout-ms`、`--artifact-format`、`--integrity-policy`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea analyze-javascript-application <path> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析、无外部运行时；本批文档未逐条跑通，合并前由实施者在 Linux 验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `analyze-web-bundle`

- **用途 / Purpose**：捕获并静态分析页面 bundle，默认取已选 target 的 origin。Capture and statically analyze a page bundle, defaulting to the selected target origin.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`、`--detail`、`--evidence_output`、`--view`、`--observation-ms`、`--fetch-source-maps`、`--max-heap-mb`、`--analysis-timeout-ms`、`--total-analysis-timeout-ms`、`--source-map-fetch-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea analyze-web-bundle <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的 Chromium/Electron/Node CDP 端点（Playwright 捕获），本环境无对应运行时目标，**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `capture-browser-scenario`

- **用途 / Purpose**：执行一个有界的 Playwright 浏览器场景并返回 Evidence。Run one bounded Playwright browser scenario and return Evidence.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：无命令专属参数（场景输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea capture-browser-scenario <inputJson>
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点与 Playwright 捕获能力，本环境**未实测/需 CDP 端点 + Playwright 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `capture-electron-scenario`

- **用途 / Purpose**：执行一个归属于本进程的 Electron 场景，动作可取消。Run one owned Electron scenario with cancellable actions.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：无命令专属参数（场景输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea capture-electron-scenario <inputJson>
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的 Electron 应用并暴露 CDP 端点，本环境**未实测/需 Electron CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `capture-web-screenshot`

- **用途 / Purpose**：在给定 origin 范围内截取一个可见页面视口。Capture one visible page viewport within the supplied origin scope.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：写出经 digest 的 PNG / 捕获产物文件。
- **示例 / Example**：
  ```bash
  rea capture-web-screenshot <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点，本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare-application-versions`

- **用途 / Purpose**：对比两个已认证的 JavaScript Application Graph 版本。Compare two authenticated JavaScript Application Graph versions.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；需先有两份应用分析 Evidence 作为 `<inputJson>`。None, built-in; requires two prior application-analysis Evidence inputs.
- **关键参数 / Key flags**：无命令专属参数（对比输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-application-versions <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯 Evidence JSON 对比，无外部运行时；本批文档未逐条跑通，合并前由实施者在 Linux 验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare-javascript-export-shapes`

- **用途 / Purpose**：不执行代码，静态对比 JavaScript 导出函数的精确返回形状。Compare exact static JavaScript export return shapes without execution.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析。None, built-in static parser.
- **关键参数 / Key flags**：无命令专属参数（对比输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-javascript-export-shapes <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态对比，无外部运行时；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare-source-to-bundle`

- **用途 / Purpose**：将历史源码（内联 graph 或 `{kind:file,path}` 引用）与已认证的应用 Evidence 对比；完整 JSON 可保存后用 `inspect-analysis-view` 查询。Compare historical source (inline graph or reference `{kind:file,path}`) with authenticated application Evidence; save the complete JSON to query with `inspect-analysis-view`.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析。None, built-in static parser.
- **关键参数 / Key flags**：无命令专属参数（对比输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-source-to-bundle <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态对比，无外部运行时；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare-web-captures`

- **用途 / Purpose**：对比两份归一化后的被动捕获或已录制的浏览器场景。Compare two normalized passive captures or recorded browser scenarios.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--normalization-json`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-web-captures <beforeJson> <afterJson> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖捕获阶段产生的运行时目标；本环境**未实测/需先有 Web 捕获产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare-web-screenshots`

- **用途 / Purpose**：对比两份自校验的 PNG 产物 JSON。Compare two self-verifying PNG artifact JSON values.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--channel-threshold`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea compare-web-screenshots <beforeJson> <afterJson> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖 `capture-web-screenshot` 类命令产生的 PNG 产物；本环境**未实测/需先有截图产物前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `discover-webmcp-tools`

- **用途 / Purpose**：被动发现页面声明的 WebMCP 工具。Passively discover page-declared WebMCP tools.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`、`--observation-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea discover-webmcp-tools <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点；本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `export-web-scripts`

- **用途 / Purpose**：把保留在捕获中的网站脚本导出到一个尚不存在的目录，供静态 JS 分析使用。Export retained website scripts into an absent directory for static JavaScript analysis.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；需先有 Web 捕获产物。None, built-in; requires a prior web capture artifact.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：将保留的网站脚本写出到指定目录。
- **示例 / Example**：
  ```bash
  rea export-web-scripts <capturePath> <outputDirectory>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯文件解包导出；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-electron-fuses`

- **用途 / Purpose**：不启动应用，直接检查已打包 Electron 的 fuse 字节。Inspect packaged Electron fuse bytes without launching the application.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；目标为已打包的 Electron 二进制。None, built-in static parser on a packaged Electron binary.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-electron-fuses <path>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态字节解析，无需启动 Electron；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-electron-page`

- **用途 / Purpose**：被动检查一个 Electron file 页面。Passively inspect one Electron file page.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--observation-ms`、`--include-script-sources`、`--command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-electron-page <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的 Electron CDP 端点；本环境**未实测/需 Electron CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-web-event-listeners`

- **用途 / Purpose**：在主文档首个 CSS 选择器命中处，检查原生事件监听器的源码位置。Inspect native listener source locations on the first main-document CSS match.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-web-event-listeners <endpoint> <targetId> <selector> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点；本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-web-network-capture`

- **用途 / Purpose**：在不重新请求录制 URL 的前提下，检查保留的 HAR、原生 mitmproxy、Fiddler SAZ 或 aioquic qlog 记录。Inspect retained HAR, native mitmproxy, Fiddler SAZ or aioquic qlog records without fetching recorded URLs.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；输入为已落盘的 HAR / mitmproxy / saz / qlog 文件。None, built-in static parser on a HAR/mitmproxy/saz/qlog capture file.
- **关键参数 / Key flags**：`--detail`、`--evidence_output`、`--protobuf-framing`、`--protobuf-body-pointer`、`--protobuf-schema`、`--protobuf-message`、`--record`、`--sensitive-value`、`--capture-timeout-ms`
- **Evidence 产出 / Evidence outputs**：通过 `--evidence_output` 落盘规范 Evidence bundle。
- **示例 / Example**：
  ```bash
  rea inspect-web-network-capture <capturePath> <har|mitmproxy|saz|qlog> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态解析离线网络捕获文件；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-web-page`

- **用途 / Purpose**：通过 CDP 被动检查一个页面，默认取当前 origin。Passively inspect one page through CDP, defaulting to its current origin.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`、`--observation-ms`、`--include-accessibility-text`、`--include-console-text`、`--include-json-body-shapes`、`--include-websocket-shapes`、`--include-script-sources`、`--include-storage-keys`、`--include-storage-fingerprints`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-web-page <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点；本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-browser-targets`

- **用途 / Purpose**：从选定的回环 CDP 浏览器列出页面 target，可按 origin 过滤。List page targets from a selected loopback CDP browser, optionally filtered by origin.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-browser-targets <endpoint> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点；本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-electron-targets`

- **用途 / Purpose**：列出选定 Electron CDP 端点暴露的本地 file 页面。List local file pages exposed by the selected Electron CDP endpoint.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-electron-targets <endpoint>
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的 Electron CDP 端点；本环境**未实测/需 Electron CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-javascript-runtime-targets`

- **用途 / Purpose**：列出 Node/Electron V8 Inspector target。List Node/Electron V8 Inspector targets.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-javascript-runtime-targets <endpoint>
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的 Node/Electron V8 Inspector 端点；本环境**未实测/需 Inspector 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `observe-javascript-runtime`

- **用途 / Purpose**：被动观察一个精确的 Node/Electron Inspector target。Passively observe one exact Node/Electron Inspector target.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--runtime-kind`、`--observation-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea observe-javascript-runtime <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的 Node/Electron V8 Inspector 端点；本环境**未实测/需 Inspector 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `observe-web-execution`

- **用途 / Purpose**：观察页面的精确执行；会重置计数器并临时关闭优化。Observe precise page execution; resets counters and temporarily disables optimization.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`、`--observation-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea observe-web-execution <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点；本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `observe-web-session`

- **用途 / Purpose**：在选定时间窗口内观察用户驱动的页面导航。Observe user-driven page navigation during a chosen window.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture).
- **关键参数 / Key flags**：`--allowed-origins`、`--command-timeout-ms`、`--observation-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea observe-web-session <endpoint> <targetId> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖已运行的浏览器 CDP 端点并存在真实用户会话；本环境**未实测/需 CDP 端点前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `reconcile-javascript-runtime`

- **用途 / Purpose**：对账静态应用 Evidence 与被动运行时 Evidence JSON。Reconcile static application and passive runtime Evidence JSON.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；需先有静态分析与运行时观察两份 Evidence。None, built-in; requires prior static-analysis and runtime-observation Evidence.
- **关键参数 / Key flags**：无命令专属参数（对账输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea reconcile-javascript-runtime <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯 Evidence JSON 对账；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `recover-javascript-sources`

- **用途 / Purpose**：恢复可读的 JavaScript 模块，带源码溯源与文件校验。Recover readable JavaScript modules with source provenance and verified files.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；输入为已捕获的脚本 bundle。None, built-in; takes a captured script bundle as input.
- **关键参数 / Key flags**：`--additional-path`、`--extraction-mode`、`--rewrite-level`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea recover-javascript-sources <path> <outputDirectory> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态反混淆/恢复；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-javascript-semantics`

- **用途 / Purpose**：在已认证的应用 Evidence 上，追踪有界的静态语义关系。Trace bounded static semantic relations through authenticated application Evidence.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析。None, built-in static parser.
- **关键参数 / Key flags**：无命令专属参数（追踪输入由 `<inputJson>` 提供）。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea trace-javascript-semantics <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯静态语义追踪；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-web-module-imports`

- **用途 / Purpose**：把一段已捕获脚本的原生 import 追溯到 URL 与已捕获源码候选。Trace one captured script's native imports to URLs and captured source candidates.
- **前置与外部工具 / Prerequisites & external tools**：需运行中的 Chromium/Electron/Node 目标并暴露 CDP/Inspector 端点（Playwright 负责捕获）；输入为已落盘的捕获 manifest。A running Chromium/Electron/Node target exposing a CDP/Inspector endpoint (Playwright for capture); input is a persisted capture manifest.
- **关键参数 / Key flags**：`--importer-url`、`--import-map-path`、`--import-map-base-url`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea trace-web-module-imports <manifestPath> <scriptIndex> [options]
  ```
- **可测性 / Testability**：📱 需真机/设备 / Requires device —— 依赖 Web 捕获产物；本环境**未实测/需先有捕获 manifest 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-web-source-location`

- **用途 / Purpose**：通过显式指定的本地 source map，把一段保留脚本的位置追溯回源码行列。Trace one retained script position through an explicitly selected local source map.
- **前置与外部工具 / Prerequisites & external tools**：无，内置纯解析；输入为已落盘的捕获 manifest 与本地 source map 文件。None, built-in; takes a persisted capture manifest and a local source map.
- **关键参数 / Key flags**：`--decode-timeout-ms`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea trace-web-source-location <manifestPath> <scriptIndex> <sourceMapPath> <sourceMapUrl> <line> <column> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯本地 source map 解码；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

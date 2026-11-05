# 领域⑨ · Evidence 与工程化能力地图（rea-agents 6.8.0）

> 本领域共 **16 个命令**，全部为离线 Evidence JSON 处理 / 环境 bundle 构建与比对类命令（✅ 本机可实测）。
> 基线版本：rea-agents 6.8.0（2026-11-05）。全局参数（`--format`、`--filter-output`、`--token-*` 等）见总索引 README，本文件不重复列出。

## 目录

- [`build-reconstruction-obligation-ledger`](#build-reconstruction-obligation-ledger)
- [`compare`](#compare)
- [`environment-build`](#environment-build)
- [`environment-compare`](#environment-compare)
- [`environment-export`](#environment-export)
- [`environment-serve`](#environment-serve)
- [`evaluate-reconstruction-coverage`](#evaluate-reconstruction-coverage)
- [`evidence-export`](#evidence-export)
- [`evidence-import`](#evidence-import)
- [`import-managed-reconstruction`](#import-managed-reconstruction)
- [`import-reference-source`](#import-reference-source)
- [`inspect-analysis-view`](#inspect-analysis-view)
- [`inspect-evidence-bundle`](#inspect-evidence-bundle)
- [`project-managed-application-graph`](#project-managed-application-graph)
- [`trace-application-feature`](#trace-application-feature)
- [`verify-managed-native-boundaries`](#verify-managed-native-boundaries)

---

### `build-reconstruction-obligation-ledger`

- **用途 / Purpose**：生成一份确定性的、Evidence 支撑的重建义务台账（reconstruction obligation ledger）页面。Generate a deterministic Evidence-backed reconstruction obligation ledger page.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线投影（输入为既有 Evidence JSON）。None, offline projection over existing Evidence JSON.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea build-reconstruction-obligation-ledger <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线投影；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `compare`

- **用途 / Purpose**：比对两个规范 Evidence bundle（别名 `compare-bundles`）。Compare two canonical Evidence bundles.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线比对（输入为两个 Evidence bundle JSON 路径）。None, offline comparison over two Evidence bundle JSON paths.
- **关键参数 / Key flags**：`--record_pairs <string>`（显式的 left_evidence_id/right_evidence_id 观测对 JSON 数组）
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea compare <left> <right> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线比对；本环境仅核对 6.8.0 help，**未跑通样本 bundle**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `environment-build`

- **用途 / Purpose**：一步离线地从录制的 capture 构建 agent 环境 bundle：检查 HAR（或读取 capture Evidence）→ 投影环境 manifest → 推导状态 → 报告环境从状态应答哪些工具、replay 哪些、以及每次写入为何被保留（withhold），最后写出 bundle（即 `environment-export` 所写的内容）。Build an agent environment bundle from a recorded capture in one offline step.
- **前置与外部工具 / Prerequisites & external tools**：无命令级显式前置；输入为 `.har` 文件或来自 `inspect-web-network-capture` / `capture-browser-scenario` 的 capture Evidence JSON。Input is a `.har` file or capture Evidence JSON.
- **关键参数 / Key flags**：`--name <string>`、`--template-rule <array>`、`--format-rules-only`、`--package-tarball <string>`、`--dry-run`、`--capture-timeout-ms <number>`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定（或省略 directory 仅配合 `--dry-run`），否则在目标目录写出环境 bundle。Returns canonical Evidence JSON on stdout; writes the bundle directory unless `--dry-run`.
- **示例 / Example**：
  ```bash
  rea environment-build <capture> [directory] [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线；本环境仅核对 6.8.0 help，**未跑通样本 HAR/capture**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `environment-compare`

- **用途 / Purpose**：把环境与其来源应用的 probe 录制做比对：每个 probe 是对全新重置应用的一次调用序列，由环境从重置状态应答，按步骤、工具与 probe 逐项报告一致度。Compare an environment with probe captures of the application it was captured from.
- **前置与外部工具 / Prerequisites & external tools**：无命令级显式前置；输入为环境 manifest（及 `--evidence` 指定的 capture Evidence、`--probe` 指定的 probe 录制）。Input is an environment manifest plus optional Evidence/probe captures.
- **关键参数 / Key flags**：`--evidence`、`--probe`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea environment-compare <manifest> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线；本环境仅核对 6.8.0 help，**未跑通样本环境与 probe**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `environment-export`

- **用途 / Purpose**：把环境 manifest 及其 capture Evidence 导出为一个 agentenv 框架可通过 `agent-env run` 运行的环境 bundle 目录。Export an environment manifest and its capture Evidence as an agent environment bundle folder.
- **前置与外部工具 / Prerequisites & external tools**：无命令级显式前置；输入为环境 manifest 与 capture Evidence。Input is an environment manifest plus capture Evidence.
- **关键参数 / Key flags**：`--evidence`、`--package-tarball`、`--name`
- **Evidence 产出 / Evidence outputs**：写出一个 agent-env 环境 bundle 目录。Writes an agent-env environment bundle folder.
- **示例 / Example**：
  ```bash
  rea environment-export <manifest> <directory> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线；本环境仅核对 6.8.0 help，**未跑通样本环境**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `environment-serve`

- **用途 / Purpose**：把环境 manifest 作为 agent 环境通过 streamable HTTP 对外提供服务，直到收到 SIGINT/SIGTERM：读工具、以及其效果被 capture 确认过的写工具，从 capture 观察到的状态（启动时推导）应答；加 `--replay-only` 或状态不可用时全部工具 replay 保留的 capture 记录。Serve an environment manifest as an agent environment over streamable HTTP until SIGINT or SIGTERM.
- **前置与外部工具 / Prerequisites & external tools**：无命令级显式前置；输入为环境 manifest；运行期占用本地 HTTP 端口。Input is an environment manifest; binds a local HTTP port at runtime.
- **关键参数 / Key flags**：`--evidence`、`--replay-only`、`--host`、`--port`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件（运行期为本地 HTTP 服务）。Returns canonical Evidence JSON on stdout; runs a local HTTP server for the session.
- **示例 / Example**：
  ```bash
  rea environment-serve <manifest> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线自包含服务；本环境仅核对 6.8.0 help，**未跑通样本环境**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `evaluate-reconstruction-coverage`

- **用途 / Purpose**：评估内联 fail-closed 重建覆盖率。Evaluate inline fail-closed reconstruction coverage.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线评估（输入为既有 Evidence JSON）。None, offline evaluation over existing Evidence JSON.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea evaluate-reconstruction-coverage <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线评估；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `evidence-export`

- **用途 / Purpose**：校验并以原子方式导出规范 Evidence JSON。Validate and atomically export canonical Evidence JSON.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线文件操作。None, offline file operation.
- **关键参数 / Key flags**：`--overwrite`
- **Evidence 产出 / Evidence outputs**：原子化导出规范 Evidence JSON bundle 文件。Atomically exports canonical Evidence JSON bundle.
- **示例 / Example**：
  ```bash
  rea evidence-export <source> <output> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线文件操作；本环境仅核对 6.8.0 help，**未跑通样本 bundle**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `evidence-import`

- **用途 / Purpose**：校验并导入一个有界的本地 Evidence bundle。Validate and import a bounded local Evidence bundle.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线文件操作。None, offline file operation.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：导入一个本地 Evidence bundle（结果经 stdout 报告）。Imports a local Evidence bundle.
- **示例 / Example**：
  ```bash
  rea evidence-import <path>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线文件操作；本环境仅核对 6.8.0 help，**未跑通样本 bundle**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `import-managed-reconstruction`

- **用途 / Purpose**：对照精确的静态成员 Evidence，导入反编译器产出的 managed 层重建结果。Import decompiler-produced managed reconstruction against exact static member evidence.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线导入（输入为反编译重建 JSON 与静态成员 Evidence）。None, offline import over reconstruction + static member Evidence JSON.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea import-managed-reconstruction <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线导入；本环境仅核对 6.8.0 help，**未跑通样本重建数据**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `import-reference-source`

- **用途 / Purpose**：把一个源码树作为历史参考资料导入（仅参考用途）。Import a source tree as historical reference only.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线读取本地源码树。None, offline ingestion of a local source tree.
- **关键参数 / Key flags**：`--detail`、`--outline-depth`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea import-reference-source <root> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线读取；本环境仅核对 6.8.0 help，**未跑通样本源码树**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-analysis-view`

- **用途 / Purpose**：为受支持的分析操作，从已完成的 Evidence JSON 中投影出选定视图。Project a selected view of completed Evidence JSON for a supported analysis operation.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线投影（输入为既有 Evidence JSON）。None, offline projection over existing Evidence JSON.
- **关键参数 / Key flags**：`--evidence-bundle`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-analysis-view <inputJson> [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线投影；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-evidence-bundle`

- **用途 / Purpose**：检查本地 Evidence bundle 的完整或部分 discovery 元数据。Inspect complete or selected discovery metadata from a local Evidence bundle.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线读取本地 Evidence bundle。None, offline read of a local Evidence bundle.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea inspect-evidence-bundle <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线读取；本环境仅核对 6.8.0 help，**未跑通样本 bundle**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `project-managed-application-graph`

- **用途 / Purpose**：把已认证的 managed 层静态 Evidence 投影为一张应用图。Project authenticated managed static Evidence into an application graph.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线投影（输入为已认证的 managed 静态 Evidence JSON）。None, offline projection over authenticated managed static Evidence JSON.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea project-managed-application-graph <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线投影；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `trace-application-feature`

- **用途 / Purpose**：在已认证的应用 Evidence JSON 中，沿类型化种子（typed seed）做特征追踪。Trace a typed seed through authenticated application Evidence JSON.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线追踪（输入为已认证的应用 Evidence JSON）。None, offline tracing over authenticated application Evidence JSON.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea trace-application-feature <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线追踪；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `verify-managed-native-boundaries`

- **用途 / Purpose**：对照已认证的 native Evidence，校验 managed 层的 P/Invoke 声明。Verify managed P/Invoke declarations against authenticated native Evidence.
- **前置与外部工具 / Prerequisites & external tools**：无，纯离线校验（输入为 managed 与 native 两侧的已认证 Evidence JSON）。None, offline verification over authenticated managed + native Evidence JSON.
- **关键参数 / Key flags**：无命令级专属参数（仅全局参数）。None beyond global flags.
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。Returns canonical Evidence JSON on stdout; no side-effect file unless flagged.
- **示例 / Example**：
  ```bash
  rea verify-managed-native-boundaries <inputJson>
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯离线校验；本环境仅核对 6.8.0 help，**未跑通样本 Evidence JSON**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

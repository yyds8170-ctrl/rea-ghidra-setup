# 领域⑩ · JEB 商业软件 + 平台自身

> 基线：rea-agents 6.8.0（2026-11-05），数据底座 `research/B_commands_176.json`。
> **本领域 10 个命令 / 10 commands in this domain。**
> 可测性分布：✅ linux-testable 6 条（平台自检/配置类）；💼 needs-jeb 4 条（JEB 项目/反编译/客户端，本环境无 JEB，未实测）。

## 目录 / TOC

- [`capabilities`](#capabilities)
- [`decompile-jeb-item`](#decompile-jeb-item)
- [`doctor`](#doctor)
- [`inspect-jeb-client`](#inspect-jeb-client)
- [`list-jeb-units`](#list-jeb-units)
- [`open-jeb-project`](#open-jeb-project)
- [`providers`](#providers)
- [`setup`](#setup)
- [`uninstall`](#uninstall)
- [`update`](#update)

---

### `capabilities`

- **用途 / Purpose**：列出各 provider 的能力与副作用。List provider capabilities and side effects.
- **前置与外部工具 / Prerequisites & external tools**：无，内置平台自检。None, built-in platform introspection.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea capabilities
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯平台自检；本批文档未逐条跑通，合并前由实施者在 Linux 验证。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `decompile-jeb-item`

- **用途 / Purpose**：把一个 JEB 类型或方法反编译为引擎伪代码。Decompile one JEB type or method to engine pseudo-code.
- **前置与外部工具 / Prerequisites & external tools**：需运行并已授权的 JEB（商业逆向套件）。JEB (commercial reverse-engineering suite) running / licensed.
- **关键参数 / Key flags**：`--unit-path`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea decompile-jeb-item <item-address> <type|method> [options]
  ```
- **可测性 / Testability**：💼 需商业软件 JEB / Requires JEB —— 需运行并已授权的 JEB 套件，本环境无 JEB，**未实测/需 JEB 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `doctor`

- **用途 / Purpose**：检查 REA 是否已就绪。Check whether REA is ready.
- **前置与外部工具 / Prerequisites & external tools**：无，内置平台自检。None, built-in platform introspection.
- **关键参数 / Key flags**：`--target`、`--client`、`--provider`、`--skill`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea doctor [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯平台自检；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `inspect-jeb-client`

- **用途 / Purpose**：不打开目标，直接检查正在运行的 JEB MCP 客户端。Inspect the running JEB MCP client without opening a target.
- **前置与外部工具 / Prerequisites & external tools**：需运行并已授权的 JEB（商业逆向套件）。JEB (commercial reverse-engineering suite) running / licensed.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea inspect-jeb-client
  ```
- **可测性 / Testability**：💼 需商业软件 JEB / Requires JEB —— 需运行中的 JEB 及 MCP 客户端，本环境无 JEB，**未实测/需 JEB 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `list-jeb-units`

- **用途 / Purpose**：按路径与类型列出 JEB 工程单元，可加过滤。List JEB project units by path and type with optional filter.
- **前置与外部工具 / Prerequisites & external tools**：需运行并已授权的 JEB（商业逆向套件）。JEB (commercial reverse-engineering suite) running / licensed.
- **关键参数 / Key flags**：`--filter`、`--parent-unit-path`、`--index`、`--count`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea list-jeb-units [options]
  ```
- **可测性 / Testability**：💼 需商业软件 JEB / Requires JEB —— 需已打开工程的 JEB 实例，本环境无 JEB，**未实测/需 JEB 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `open-jeb-project`

- **用途 / Purpose**：从一个归档或 `.jdb2` 数据库打开或创建 JEB 工程。Open or create a JEB project from an artifact or `.jdb2` database.
- **前置与外部工具 / Prerequisites & external tools**：需运行并已授权的 JEB（商业逆向套件）。JEB (commercial reverse-engineering suite) running / licensed.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea open-jeb-project <path>
  ```
- **可测性 / Testability**：💼 需商业软件 JEB / Requires JEB —— 需运行并已授权的 JEB 套件，本环境无 JEB，**未实测/需 JEB 前置**。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `providers`

- **用途 / Purpose**：列出已配置的分析 provider。List configured analysis providers.
- **前置与外部工具 / Prerequisites & external tools**：无，内置平台自检。None, built-in platform introspection.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea providers
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 纯平台自检；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `setup`

- **用途 / Purpose**：配置 agent 集成与可选的分析 provider。Configure agent integrations and optional analysis providers.
- **前置与外部工具 / Prerequisites & external tools**：无，内置平台配置；可选安装 Hopper（仅 macOS 可用）。None, built-in; optional Hopper install (macOS only).
- **关键参数 / Key flags**：`--yes`、`--install-hopper`、`--client`、`--skill-client`、`--all-detected`、`--skill`、`--dry-run`、`--accessible`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea setup [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 可用 `--dry-run` 干跑；本批文档未逐条跑通。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `uninstall`

- **用途 / Purpose**：移除 REA 自身管理的 agent 配置与 skill 文件。Remove REA-owned agent configuration and skill files.
- **前置与外部工具 / Prerequisites & external tools**：无，内置平台配置；会改动本用户目录，建议先 `--dry-run`（如支持）或备份。None, built-in; mutates user-owned files, prefer backup/dry-run first.
- **关键参数 / Key flags**：`--purge-data`
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea uninstall [options]
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 属平台自身卸载动作，有副作用，本环境未真实执行（**未实测/避免误删本机配置**）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

### `update`

- **用途 / Purpose**：更新本 REA 安装并校验已安装版本。Update this REA installation and verify the installed release.
- **前置与外部工具 / Prerequisites & external tools**：无，内置平台配置；需要 npm 可访问 registry。None, built-in; requires npm registry access.
- **关键参数 / Key flags**：无命令专属参数。
- **Evidence 产出 / Evidence outputs**：`--format json` 时向 stdout 返回规范 Evidence JSON；除非显式指定，否则无副作用文件。
- **示例 / Example**：
  ```bash
  rea update
  ```
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux —— 属自更新动作，会改动本环境 rea 安装版本，本环境未真实执行（**未实测/避免误升级**）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

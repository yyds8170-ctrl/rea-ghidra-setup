# 集成入口 / Integrations — completions & mcp

> 这两个入口出现在 `rea --help` 底部的 **Integrations** 段，**不计入 175 个命令**。
> They are listed under the **Integrations** section of `rea --help` and are not counted among the 175 commands.
> 数据来源：rea-agents 6.8.0 实测 `--help`（2026-11-05）。Source: live `--help` output.

## `completions` — 生成 shell 补全脚本 / Generate shell completion script

- **用途 / Purpose**：为指定 shell 生成命令补全脚本。Generate a shell completion script for the chosen shell.
- **用法 / Usage**：`rea completions <bash|fish|nushell|zsh>`
- **安装方式 / Setup**：

  ```bash
  # bash —— 加入 ~/.bashrc
  eval "$(rea completions bash)"
  # fish —— 加入 ~/.config/fish/config.fish
  rea completions fish | source
  # zsh —— 加入 ~/.zshrc
  eval "$(rea completions zsh)"
  # nushell —— 见 rea completions nushell 的输出
  ```

- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（纯文本生成，无副作用 / pure text generation, no side effects）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents

## `mcp` — 注册为 MCP 服务器 / Register as MCP server

- **用途 / Purpose**：把 REA 注册为 Model Context Protocol（MCP）服务器，并校验其启动与工具清单。Register REA as an MCP server and validate startup/tool listing.
- **用法 / Usage**：`rea mcp <command>`
- **子命令 / Subcommands**：
  - `add` —— 注册为 MCP 服务器 / Register as MCP server。
  - `doctor` —— 校验 MCP 服务器启动与工具列出 / Validate MCP server startup and tool listing。
- **本仓库的 MCP 接入 / In this repo**：仓库提供 `scripts/mcp-setup.sh` / `mcp-setup.ps1` 自动为各 MCP 客户端（Claude Desktop、Codex、Gemini 等）写入配置；其 `--check` 已在本环境实测 stdio 握手通过（`server=rea 6.8.0`，Ghidra provider available）。详见 [../../docs/mcp.md](../../docs/mcp.md)。
- **可测性 / Testability**：✅ 本机可实测 / Testable on Linux（stdio 握手已在本环境验证 / stdio handshake verified here）。
- **来源 / Sources**：[help] https://www.npmjs.com/package/rea-agents ；[docs] https://github.com/morluto/rea

## 与 175 命令的关系 / Relationship to the 175 commands

| 类别 / Category | 数量 / Count | 说明 |
|---|---|---|
| 命令 / Commands | 175 | 见各 [domain 文件](README.md) 与 [coverage-matrix.md](coverage-matrix.md) |
| 集成入口 / Integrations | 2 | `completions`、`mcp`（本文件） |
| **合计 / Total** | **177 个 help 条目 / help entries** | 命令盘点按 175 个 Commands 计数 |

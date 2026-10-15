[English](mcp.en.md) | 简体中文

# REA MCP 客户端对接（一键注册 + 连接自检）

REA 自带一个 MCP server（`rea-agents --mcp`，stdio 传输）。本仓库提供
`scripts/mcp-setup.sh`（Linux/macOS）与 `scripts/mcp-setup.ps1`（Windows），
帮你把这个 server 注册进主流 MCP 客户端，并做一次连接自检。

> 安装器**不会**在安装时静默改你的客户端配置；下面命令都由你手动触发。

## 快速开始

```bash
# 1) 看看本机装了哪些客户端、将要写到哪里
bash scripts/mcp-setup.sh --list

# 2) 预览将要写入的 stdio JSON（不写盘）
bash scripts/mcp-setup.sh --dry-run --client claude-desktop

# 3) 确认无误后真正注册（写前自动备份 .bak，只合并 rea 条目）
bash scripts/mcp-setup.sh --client claude-desktop --yes

# 4) 连接自检：原生 MCP stdio 握手 +（有 Ghidra 时）provider 体检
bash scripts/mcp-setup.sh --check
```

Windows PowerShell：
```powershell
pwsh -File .\scripts\mcp-setup.ps1 -List
pwsh -File .\scripts\mcp-setup.ps1 -DryRun -Client claude-desktop
pwsh -File .\scripts\mcp-setup.ps1 -Client claude-desktop -Yes
pwsh -File .\scripts\mcp-setup.ps1 -Check
```

## 支持的客户端与配置路径

| `--client` | 配置文件（Linux / macOS / Windows） |
| --- | --- |
| `claude-desktop` | `~/.config/Claude/claude_desktop_config.json`（Linux）· `~/Library/Application Support/Claude/...`（macOS）· `%APPDATA%\Claude\...`（Windows） |
| `cursor` | `~/.config/Cursor/User/globalStorage/mcp.json`（Linux）· `~/Library/.../Cursor/...`（macOS）· `%APPDATA%\Cursor\...`（Windows） |
| `vscode` | `~/.config/Code/User/mcp.json`（Linux）· `~/Library/.../Code/...`（macOS）· `%APPDATA%\Code\...`（Windows） |
| `claude-code` | `~/.claude.json` |

注册的 server 名为 `rea`，标准 stdio 条目形如：

```json
{
  "command": "/opt/nodejs/22/bin/npx",
  "args": ["-y", "rea-agents@6.5.0", "--mcp"],
  "env": {
    "JAVA_HOME": "/home/user/tools/jdk-21.0.12.1+1",
    "GHIDRA_INSTALL_DIR": "/home/user/tools/ghidra_12.1.4_PUBLIC"
  }
}
```

- `command` 用 **npx 的绝对路径**（脚本自动 `command -v npx` 解析），避免客户端 PATH 找不到。
- `env` 仅在已设置时写入 `JAVA_HOME` / `GHIDRA_INSTALL_DIR`；`REA_MIRROR=cn` 时会带上 `REA_MIRROR=cn`。
- 不写全局 npm 配置，不改 `.npmrc`。

## 连接自检 `--check` 做了什么

1. **原生 MCP stdio 握手**：按 JSON-RPC 2.0 发一行 `initialize`（带 protocolVersion/capabilities/clientInfo），
   读到合法 `result`（含 `serverInfo.name=rea`）即判定 server 可启动、协议通。
   - 实测 rea-agents 的 MCP over stdio 是**换行分隔 JSONL（无 Content-Length 帧）**。
2. **Ghidra provider 体检**：仅当 `JAVA_HOME` 与 `GHIDRA_INSTALL_DIR` 都已设置时，
   跑 `rea doctor --provider ghidra --format json`，断言 `providerInspections[].id=ghidra.available==true`；
   否则优雅跳过第 2 步（第 1 步必过）。

## 安全与幂等

- 默认**不写盘**；只有 `--client <名> --yes`（PS：`-Client <名> -Yes`）才写。
- 写前把原配置备份为 `<file>.bak`；只合并/更新本项目的 `rea` server 条目，**不删除其它 server**。
- 重复执行幂等：第二次只是覆盖同一个 `rea` 条目，不会重复追加。
- 未知 `--client` 打印已知列表并退出 2。

## 常见问题

- **`--check` 握手超时/无响应**：确认 `npx -y rea-agents@<ver> --mcp` 能单独启动；国内网络可先 `REA_MIRROR=cn bash scripts/mcp-setup.sh --check`。
- **客户端里找不到 rea 工具**：注册后**重启客户端**；确认 `command` 指向的 npx 存在、`JAVA_HOME`/`GHIDRA_INSTALL_DIR` 路径正确。
- **想完全用官方交互向导**：可直接 `npx -y rea-agents@<ver> setup --client claude --yes`（会顺带装 skill）；本脚本只做最小 stdio 注册，便于自动化。

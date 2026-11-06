[English](mcp.en.md) | [简体中文](mcp.md)

# REA MCP client wiring (one-command register + connection self-check)

REA ships an MCP server (`rea-agents --mcp`, stdio transport). This repo provides
`scripts/mcp-setup.sh` (Linux/macOS) and `scripts/mcp-setup.ps1` (Windows) to
register this server into mainstream MCP clients and run a connection self-check.

> The installer does **not** silently edit your client config during install; all
> commands below are triggered by you manually.

## Quick start

```bash
# 1) See which clients are installed and where it will write
bash scripts/mcp-setup.sh --list

# 2) Preview the stdio JSON that would be written (no disk write)
bash scripts/mcp-setup.sh --dry-run --client claude-desktop

# 3) Register for real after confirming (auto .bak backup before write, merges only the rea entry)
bash scripts/mcp-setup.sh --client claude-desktop --yes

# 4) Connection self-check: native MCP stdio handshake + (if Ghidra present) provider check
bash scripts/mcp-setup.sh --check
```

Windows PowerShell:
```powershell
pwsh -File .\scripts\mcp-setup.ps1 -List
pwsh -File .\scripts\mcp-setup.ps1 -DryRun -Client claude-desktop
pwsh -File .\scripts\mcp-setup.ps1 -Client claude-desktop -Yes
pwsh -File .\scripts\mcp-setup.ps1 -Check
```

## Supported clients and config paths

| `--client` | Config file (Linux / macOS / Windows) |
| --- | --- |
| `claude-desktop` | `~/.config/Claude/claude_desktop_config.json` (Linux) · `~/Library/Application Support/Claude/...` (macOS) · `%APPDATA%\Claude\...` (Windows) |
| `cursor` | `~/.config/Cursor/User/globalStorage/mcp.json` (Linux) · `~/Library/.../Cursor/...` (macOS) · `%APPDATA%\Cursor\...` (Windows) |
| `vscode` | `~/.config/Code/User/mcp.json` (Linux) · `~/Library/.../Code/...` (macOS) · `%APPDATA%\Code\...` (Windows) |
| `claude-code` | `~/.claude.json` |

The registered server is named `rea`; a standard stdio entry looks like:

```json
{
  "command": "/opt/nodejs/22/bin/npx",
  "args": ["-y", "rea-agents@6.8.0", "--mcp"],
  "env": {
    "JAVA_HOME": "/home/user/tools/jdk-21.0.12.1+1",
    "GHIDRA_INSTALL_DIR": "/home/user/tools/ghidra_12.1.4_PUBLIC"
  }
}
```

- `command` uses the **absolute path to npx** (resolved via `command -v npx`), so the client's PATH does not matter.
- `env` writes `JAVA_HOME` / `GHIDRA_INSTALL_DIR` only when already set; with `REA_MIRROR=cn` it also carries `REA_MIRROR=cn`.
- It does not touch global npm config or `.npmrc`.

## What `--check` does

1. **MCP stdio end-to-end self-check**: delegates to `examples/web-samples/run-mcp-e2e.sh`,
   which really starts `rea-agents --mcp` and walks a full JSON-RPC round —
   `initialize` → `notifications/initialized` → `tools/list` → several **offline tools/call**:
   - `inspect_byte_entropy` (Shannon entropy of a temp file),
     `inspect_analysis_settings`, `list_unknowns`, `binary_session` (session-level, no Ghidra/device);
   - plus 2 error-envelope assertions: an unadvertised tool must return a top-level
     JSON-RPC `error` (code `-32602`), and a missing required argument must return
     `result.isError==true`.
   Every step validates `jsonrpc=="2.0"`, `id` correlation, the `result`/`error` envelope,
   and `content[].type=="text"`; any failure prints a per-check FAIL list and exits 1.
   - rea-agents' MCP over stdio is **newline-delimited JSONL (no Content-Length framing)**.
2. **Ghidra provider check**: only when both `JAVA_HOME` and `GHIDRA_INSTALL_DIR` are set, runs `rea doctor --provider ghidra --format json` and asserts `providerInspections[].id=ghidra.available==true`; otherwise it gracefully skips step 2 (step 1 must still pass).

> To re-run on its own / dump the wire transcript:
> `bash examples/web-samples/run-mcp-e2e.sh [--out transcript.log]`.

## Safety and idempotency

- By default it **does not write**; only `--client <name> --yes` (PS: `-Client <name> -Yes`) writes.
- Before writing it backs up the original config as `<file>.bak`; it only merges/updates this project's `rea` server entry and **never deletes other servers**.
- Repeated runs are idempotent: the second run overwrites the same `rea` entry rather than appending.
- Unknown `--client` prints the known list and exits 2.

## FAQ

- **`--check` handshake times out / no response**: confirm `npx -y rea-agents@<ver> --mcp` starts on its own; on a restricted network try `REA_MIRROR=cn bash scripts/mcp-setup.sh --check`.
- **rea tools not found in the client**: **restart the client** after registering; confirm the npx at `command` exists and `JAVA_HOME`/`GHIDRA_INSTALL_DIR` paths are correct.
- **Prefer the official interactive wizard**: run `npx -y rea-agents@<ver> setup --client claude --yes` (also installs the skill); this script does the minimal stdio registration for automation.

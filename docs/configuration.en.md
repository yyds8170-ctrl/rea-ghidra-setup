[English](configuration.en.md) | [简体中文](configuration.md)

# Configuration and MCP wiring guide

> Covers three parts: ① env tuning (memory/timeout/paths); ② registering REA as an MCP server into Claude Code / Cursor / Claude Desktop; ③ proxy and npm mirror.
> For install see the per-platform docs; first run `bash scripts/detect-env.sh` and `scripts/doctor.sh` (Windows: `scripts/doctor.ps1`).

## 1. Key environment variables

| Variable | Purpose | Default / values |
| --- | --- | --- |
| `GHIDRA_INSTALL_DIR` | Ghidra extracted dir (contains `support/analyzeHeadless`) | written by installer; REA also searches common dirs when unset |
| `JAVA_HOME` | JDK 21 dir (contains `bin/java`) | written by installer; Ghidra 12.x requires **exactly 21** |
| `GHIDRA_HEADLESS_MAXMEM` | headless-only JVM max heap (`-Xmx`) | highest priority; else `GHIDRA_MAXMEM`, else `2G` |
| `GHIDRA_MAXMEM` | max heap for all Ghidra instances (incl. GUI) | default `2G` |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | ms to wait for Ghidra provider startup/import/analysis | default `330000` (330s); raise to `600000` for big binaries |
| `REA_GHIDRA_LANGUAGE_ID` | force Ghidra language ID (e.g. `x86:LE:32:default`) | usually not needed; set when auto-id fails |
| `PATH` | must include JDK `bin`, Node `bin`, (Windows) `%APPDATA%\npm` | auto-appended by installer |

### How to set memory

On low-RAM machines (4GB / cloud desktop / Crostini) drop headless heap to 512M:

```bash
# Linux / macOS (write into ~/.bashrc or ~/.zshrc)
export GHIDRA_HEADLESS_MAXMEM=512M
export REA_GHIDRA_STARTUP_TIMEOUT_MS=600000
```

```powershell
# Windows (user-level persistent)
[Environment]::SetEnvironmentVariable('GHIDRA_HEADLESS_MAXMEM','512M','User')
[Environment]::SetEnvironmentVariable('REA_GHIDRA_STARTUP_TIMEOUT_MS','600000','User')
```

> Note: `GHIDRA_HEADLESS_MAXMEM` limits only the JVM heap, not JVM resident RSS, Node heap, or the whole process family. 512M is validated on the small sample (examples/demo); large targets still need more heap.

## 2. Register REA as an MCP server

### Auto registration (`rea mcp add`)
```bash
rea mcp add --agent claude-code
rea mcp add --agent cursor
rea mcp add -c "pnpm rea-agents --mcp"        # override the launch command
rea mcp add --agent claude-code --no-global   # current project only
rea mcp doctor --json                        # self-check the server starts and lists tools
```

### Interactive setup (`rea setup`)
```bash
rea setup --all-detected --yes
rea setup --client claude-code --yes
rea setup --dry-run
```

### Manual config (Claude Desktop example)
Edit `claude_desktop_config.json` (macOS `~/Library/Application Support/Claude/`, Windows `%APPDATA%\Claude\`):

```json
{
  "mcpServers": {
    "rea": {
      "command": "npx",
      "args": ["-y", "rea-agents@6.5.0", "--mcp"]
    }
  }
}
```

- If installed globally you can use `command: "rea"`, `args: ["--mcp"]`.
- If Ghidra is non-standard, add `env` (`GHIDRA_INSTALL_DIR`, `JAVA_HOME`, `GHIDRA_HEADLESS_MAXMEM`).
- Restart the client after editing; `rea --mcp` is a stdio server and does not stay resident.
- The MCP client's own request timeout must also be long enough.

### Verify
```bash
rea doctor
rea mcp doctor --json
bash scripts/doctor.sh      # cross-platform env pre-check (Linux/macOS)
.\scripts\doctor.ps1        # Windows
```

## 3. Proxy and mirrors

- **Downloads via proxy**: set `HTTPS_PROXY`/`HTTP_PROXY` (e.g. `http://127.0.0.1:7890`). The download kernel (v2.3+) auto-mirrors uppercase to lowercase so curl recognizes them.
- **GitHub release proxy pool (Ghidra ~400MB)**: default order official → built-in `https://gh-proxy.com/`; override with `REA_GITHUB_PROXIES`. Artifacts still must pass the GitHub API SHA-256 digest.
- **Download tuning**: `REA_DL_RETRIES` (5), `REA_DL_CONNECT_TIMEOUT` (15s), `REA_DL_MAX_TIME` (1800s).
- **China mirror acceleration (v2.4+)**: `REA_MIRROR=cn bash install.sh` routes Node/JDK/npm via npmmirror/Huawei/TUNA, official fallback, still official checksummed. See [mirrors.en.md](mirrors.en.md).
- **npm mirror**: in cn mode the installer uses `npm_config_registry=https://registry.npmmirror.com` for this process only, never writes global `.npmrc`.
- **Fully offline / air-gapped**: see [offline.md](offline.md) (Chinese). Common errors: [troubleshooting.en.md](troubleshooting.en.md).

## 4. Non-interactive / parameterized install (automation, CI)

Since v2.5 all three installers accept CLI args; default (no-arg) behavior is unchanged.

```bash
bash install.sh --dry-run                 # zero-side-effect preview
bash install.sh --yes                     # non-interactive (idempotent skip if installed)
REA_MIRROR=cn bash install.sh -y --prefix "$HOME/tools" --skip-node --no-native
```

Windows: `pwsh -File .\install.ps1 -DryRun -Mirror cn -Yes`.

Common args: `--help` / `--dry-run` / `--yes` / `--prefix <dir>` (PS `-ToolsDir`) / `--mirror auto|cn|global` / `--skip-node` / `--no-native` / `--provider <name>` / `--offline-dir <dir>` / `--ghidra-version|--node-version|--rea-version`. Unknown args exit 2.

## 5. Static export and batch

```bash
scripts/ghidra-export.sh <binary> --out <dir> --kind all
scripts/batch-analyze.sh a.elf b.elf --out ./batch-out --kind functions --jobs 4 --snapshot ./cache
```

See [export.en.md](export.en.md) and [batch.en.md](batch.en.md). JDK21/Ghidra auto-discovery applies to batch as well.

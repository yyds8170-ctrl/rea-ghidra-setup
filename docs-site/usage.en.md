[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/usage/) | English

# Usage: the unified `rea-ghidra` entrypoint

`rea-ghidra` (a bash script on Linux/macOS, `rea-ghidra.ps1` on Windows) is a **thin dispatch layer**: it locates the repo root, picks the right platform script, forwards args and preserves the exit code. Real logic stays in `install.sh` / `verify.sh` / `scripts/*`.

## Subcommand table

| Subcommand | What it does | Delegates to |
|---|---|---|
| `install` | Install JDK21 + Ghidra + portable Node | install.sh / install-macos.sh / install.ps1 |
| `doctor` | Read-only environment self-check | scripts/doctor.{sh,ps1} |
| `verify` | End-to-end 9-assertion analysis/decompile check | verify.{sh,macos,ps1} |
| `mcp ...` | Register / self-check MCP clients | scripts/mcp-setup.{sh,ps1} |
| `export ...` | Static Ghidra export to JSON/pseudocode | scripts/ghidra-export.{sh,ps1} |
| `batch ...` | Parallel batch with snapshot cache | scripts/batch-analyze.{sh,ps1} |
| `self-update [--check\|--dry-run]` | Self-update (sha256-enforced) | — |
| `current` | List Ghidra/JDK versions and the `current` symlinks under `~/tools` | — |
| `rollback` | Switch back to the previous version (when multiple exist) | — |
| `version [--check]` | Print VERSION; `--check` queries the latest GitHub release | — |
| `help` | Usage text | — |

See [docs/entry.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/entry.md) for the long form.

## Common recipes

### doctor: environment check

```bash
./rea-ghidra doctor          # read-only, never writes; lists JDK/Ghidra/Node/GHIDRA_INSTALL_DIR
```

### verify: end-to-end

```bash
./rea-ghidra verify           # runs 9 assertions (strings/constants/function names/xrefs); all pass = 0
```

### mcp: register into Claude Desktop / Cursor etc.

```bash
./rea-ghidra mcp --list                          # which clients are detected on this box
./rea-ghidra mcp --dry-run --client claude-desktop
./rea-ghidra mcp --client claude-desktop --yes
./rea-ghidra mcp --check                         # stdio handshake + provider health
```

Supported clients and config paths: [docs/mcp.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/mcp.md).

### export: single-target static dump

```bash
./rea-ghidra export ./examples/demo --out /tmp/out --kind all
# --kind: functions|strings|symbols|calls|decompiled|all
```

Output fields (functions.json / strings.json / symbols.json / calls.json / decompiled.json) are documented at
[docs/export.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/export.md).

### batch: parallel + cached

```bash
./rea-ghidra batch --dir ./bins --recurse --pattern '*.elf' \
  --kind all --jobs 4 --snapshot ./cache --continue
```

Parallel model, failure isolation and summary.json:
[docs/batch.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/batch.md).

### self-update / current / rollback

```bash
./rea-ghidra self-update --check      # report only, no writes
./rea-ghidra self-update              # git clone: `git pull --ff-only`; release tarball: sha256 verified
./rea-ghidra current                  # list all versioned dirs and where `current` points
./rea-ghidra rollback                 # switch to the previous Ghidra (requires multiple versions present)
```

!!! warning "Honest boundaries"
    `config/versions.env` pins exactly one Ghidra/JDK version at a time; rollback **never downloads an old version** — it only works when you have manually kept multiple versioned directories. In a git working copy, self-update only runs `git pull --ff-only`; uncommitted changes are surfaced first and **never auto-stashed/overwritten**.

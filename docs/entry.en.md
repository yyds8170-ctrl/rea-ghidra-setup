[English](entry.en.md) | [简体中文](entry.md)

# Unified entrypoint `rea-ghidra` (v3.0)

A single command that consolidates the scripts scattered across earlier versions. The entrypoint is a **very thin dispatcher**: locate the repo root, pick the right script, forward arguments and preserve the exit code. The real logic still lives in `install.sh` / `verify.sh` / `scripts/*`; nothing is duplicated.

## Usage

| Platform | Entrypoint |
|---|---|
| Linux / macOS | `./rea-ghidra <subcommand> [args...]` |
| Windows (PS 5.1/7) | `.\rea-ghidra.ps1 <subcommand> [args...]` |

## Subcommand reference

| Subcommand | Purpose | Forwards to |
|---|---|---|
| `install` | Install JDK21 + Ghidra + portable Node (auto Linux/macOS) | install.sh / install-macos.sh / install.ps1 |
| `doctor` | Read-only environment self-check | scripts/doctor.{sh,ps1} |
| `verify` | End-to-end verification (9 analyze/decompile assertions) | verify.{sh,macos,ps1} |
| `mcp ...` | MCP client wiring, e.g. `mcp --check`, `mcp --dry-run --client claude-desktop` | scripts/mcp-setup.{sh,ps1} |
| `export ...` | Ghidra static export, e.g. `export ./examples/demo --out /tmp/out --kind all` | scripts/ghidra-export.{sh,ps1} |
| `batch ...` | Parallel batch + snapshot cache | scripts/batch-analyze.{sh,ps1} |
| `fixtures` | Cross-compile multi-arch fixtures (i686/aarch64/mingw cross toolchains) | scripts/build-fixtures.sh (Windows: use WSL/CI) |
| `walkthrough` | End-to-end guided walkthrough (idempotent, read-only) | examples/walkthrough.sh (Windows: use WSL/CI) |
| `version [--check]` | Print VERSION; `--check` queries GitHub latest release (read-only, degrades offline) | — |
| `self-update [--check|--dry-run]` | Self-update (see below) | — |
| `current` | List installed Ghidra/JDK versions under `~/tools` and current symlink targets | — |
| `rollback` | When multiple versions coexist, switch current back to the previous one | — |
| `help` / `--help` | Usage | — |

## Quick start

```bash
# Linux / macOS
./rea-ghidra install
./rea-ghidra verify
./rea-ghidra mcp --check

# Windows
.\rea-ghidra.ps1 install
.\rea-ghidra.ps1 verify
```

## self-update and verification

- **git working copy** (`.git` present): only `git pull --ff-only`; refuses merge/force. When the working tree has uncommitted changes it warns first and **never auto-stashes/overwrites**.
- **non-git (Release tarball extracted)**: downloads the latest `rea-ghidra-setup-<tag>.tar.gz` **and its matching `.checksums.txt`** from GitHub and strongly verifies sha256 — mismatch or missing checksums aborts with non-zero. After verification, scripts/docs are overwritten; replaced old files are backed up to `.self-update-backup-<timestamp>/` (copy back to roll back). `config/versions.env` tracks the upstream locked version (the old copy is recoverable from the backup), while local artifacts `offline/`, `examples/fixtures/` and `.git/` are **never touched**. bash and PowerShell behave identically.
- `--check` / `--dry-run`: only report current → latest and whether an update is needed; **no disk writes**.
- CI only runs `self-update --check`; it never actually upgrades.

## current / rollback and honest boundaries

- The installer atomically maintains `current-ghidra` / `current-jdk` (Linux `ln -sfn`; Windows junction `mklink /J`) pointing at the active version directory; discovery reads current first and falls back to enumerating versioned directories (old behavior preserved).
- `rea-ghidra current`: lists all `ghidra_*_PUBLIC` / `jdk-21*` and symlink targets.
- `rea-ghidra rollback`: when ≥2 Ghidra versioned directories exist, switches to another and records the previous target in `~/tools/current.previous`; with a single version it clearly says "no version to roll back to".
- **Honest boundary**: config locks only one Ghidra/JDK version; reinstalling the same version does not create multiple versions. rollback only works when the user manually keeps multiple version directories; it **never auto-downloads an older version**.

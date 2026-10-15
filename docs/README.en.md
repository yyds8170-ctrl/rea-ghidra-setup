[English](README.en.md) | [简体中文](README.md)

# Documentation index

This directory organizes deployment, verification and usage docs for REA + Ghidra by OS and runtime.

## Getting started

- [entry.md](entry.en.md): unified `rea-ghidra` entrypoint — subcommand table, self-update verification, current/rollback and boundaries.

## Platforms

- Per-platform pages (Linux / macOS / Windows / ChromeOS / Docker): [platform-linux.md](platform-linux.md), [platform-macos.md](platform-macos.md), [platform-windows.md](platform-windows.md), [platform-chromeos.md](platform-chromeos.md), [platform-docker.md](platform-docker.md) — **(中文 / Chinese only)**.
- [platform-support-matrix.md](platform-support-matrix.en.md): OS × runtime support matrix (support / partial / limited / unsupported) and CI coverage.

## Usage

- [mcp.md](mcp.en.md): one-command MCP client registration + stdio self-check (`--list/--dry-run/--check`).
- [export.md](export.en.md): Ghidra static export (functions/strings/symbols/calls/decompiled JSON/C).
- [batch.md](batch.en.md): parallel batch analysis + snapshot cache (`--jobs/--snapshot/failure isolation/summary.json`).
- [offline.md](offline.md): offline / air-gapped install — **(中文 / Chinese only)**.

## Configuration & supply chain

- [configuration.md](configuration.en.md): env tuning (memory/timeout), MCP server wiring, proxy and mirrors.
- [mirrors.md](mirrors.en.md): China mirror acceleration (`REA_MIRROR=cn`) + checksum anti-tamper notes.

## Operations

- [troubleshooting.md](troubleshooting.en.md): cross-platform issues (JDK version, Node gate, Gatekeeper, native build, Windows PATH, Docker).
- [platform-support-matrix.md](platform-support-matrix.en.md): 4 OS × 5 runtimes support matrix.

> Not sure which to pick? Run `bash scripts/detect-env.sh` (or `--json` / `--shell`); it reports your OS, CPU arch, runtime (physical / wsl / crostini / docker / vm), Ghidra native dir and the recommended install script.

## Versions

- Single source of versions: [`config/versions.env`](../config/versions.env) (locked Ghidra / JDK / Node / REA).
- Changelog history: [`README.md`](../README.md#版本历史) (Chinese); releases on GitHub Releases.

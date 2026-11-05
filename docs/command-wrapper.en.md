# REA Command Wrapper

[English](command-wrapper.en.md) | [简体中文](command-wrapper.md)

> Since v5.4.0, `rea-ghidra` / `rea-ghidra.ps1` add a set of **unified REA command wrapper** subcommands alongside the existing install/verify commands:
> they validate the command against the baseline and resolve the environment *before* invoking `rea` (or the pinned `npx -y rea-agents@<version>`), then layer a stable exit-code classification on top of REA.
>
> This layer does not reimplement REA; it does three things only: **baseline validation → environment resolution → uniform invocation and exit-code mapping**.

## Subcommands

| Subcommand | Purpose |
| --- | --- |
| `run <command> [switches] [-- passthrough...]` | Generic entry: validate the command is in the baseline, resolve JDK/Ghidra, then call REA. |
| `domains` | List the 10 REA domains and their command counts. |
| `d1` … `d10 <command> [switches] [-- passthrough...]` | Domain entry: use `command-domain.tsv` to verify the command **belongs** to that domain (else exit 2); otherwise equivalent to `run`. |

bash:

```bash
./rea-ghidra run providers --json
./rea-ghidra domains
./rea-ghidra d1 analyze --json --out /tmp/analyze.json -- examples/demo --provider ghidra --snapshot /tmp/demo.snap
```

PowerShell:

```powershell
.\rea-ghidra.ps1 run providers --json
.\rea-ghidra.ps1 domains
.\rea-ghidra.ps1 d1 analyze --json --out C:\tmp\analyze.json -- .\examples\demo --provider ghidra
```

## Wrapper switches

These switches are parsed **by the wrapper before passthrough**; everything after `--` is forwarded verbatim to REA.

| Switch | Effect |
| --- | --- |
| `--json` | Force-append `--format json` (placed after passthrough args so it wins over REA). |
| `--schema` | Forward REA's `--schema`; print the command's JSON Schema. |
| `--out <file>` | Redirect REA **stdout** to `<file>` (parent dirs auto-created); without it stdout passes through. |
| `--quiet` | Suppress REA's stderr (the wrapper's own classification messages still go to stderr). |
| `--` | Everything after this token is passed verbatim to REA (e.g. `--provider ghidra --snapshot snap`). |

> Wrapper switches must come before REA's own flags; anything destined for REA goes after `--`.
> Unknown switches or a missing `--out` value are rejected (exit 2) **before** npx is invoked.

## Exit codes

| Code | Meaning | When produced |
| --- | --- | --- |
| `0` | Success | REA ran successfully (REA native exit 0). |
| `2` | Usage error | Command not in the 175-command baseline, bad wrapper switch, missing `--out` value, or a `dN` entry whose command does not belong to that domain — judged by the wrapper **before npx**. |
| `3` | Prerequisite missing | A `1-core-native` (Ghidra-native) command cannot resolve a usable JDK 21 or Ghidra — **npx is not called**. |
| `4` | Runtime failure | REA was executed but returned non-zero (analysis failure, missing file, bad flag, …). |

> **Important**: REA itself exits only `0` (success / `--help` / `--schema` / `--llms*`) or `1` (unknown command, bad flag, missing argument, missing file, analysis failure, and all other errors).
> The `2 / 3 / 4` above are **classifications produced by this wrapper from its pre-checks and REA's exit code; they are NOT REA's native exit codes**. Upstream scripts should consume this table rather than assume REA returns these codes.

## Domain routing

Runtime domain membership comes from the in-repo file [`config/command-baseline/command-domain.tsv`](../config/command-baseline/command-domain.tsv) (175 rows, `command<TAB>domain<TAB>testability`, matching `rea-6.8.0.txt` verbatim).

| Entry | Domain | Count | Notes |
| --- | --- | ---: | --- |
| `d1` | `1-core-native` | 20 | Ghidra native analysis (analyze/decompile/search/…). **Requires JDK 21 + Ghidra**; missing → exit 3. |
| `d2` | `2-offline-binary` | 20 | Offline static parsing of ELF/PE/Mach-O/Go/Rust. |
| `d3` | `3-dynamic-debug` | 15 | Dynamic debugging / runtime / UI capture. |
| `d4` | `4-web-js-electron` | 28 | Web / JS / Electron. |
| `d5` | `5-android-adb` | 33 | Android / APK / ADB. |
| `d6` | `6-apple` | 9 | Apple / macOS / iOS. |
| `d7` | `7-multiformat` | 15 | WASM/EVM/pyc/BEAM/SQLite/pcap and other formats. |
| `d8` | `8-firmware-embedded` | 9 | Firmware / embedded / Flutter·Dart / HarmonyOS. |
| `d9` | `9-evidence-engineering` | 16 | Evidence and engineering. |
| `d10` | `10-platform-jeb` | 10 | Platform self commands (doctor/providers/capabilities/…) + JEB. |

> `d1..d10` only enforce **domain membership**, not tool availability: a command routed to the wrong entry is rejected (exit 2), but whether its other tools (adb/frida/JEB/…) are ready is still REA's call; failures there map to exit 4.

## Copy-paste examples

```bash
# 1) Platform self-check, JSON forced, exit 0
./rea-ghidra run providers --json

# 2) Persist JSON to a deep path (parent dirs auto-created), quiet
./rea-ghidra run providers --json --out /tmp/rea-out/providers.json --quiet

# 3) Actually run a Ghidra analysis (d1; auto-resolves and exports JDK/Ghidra)
export PATH=/opt/nodejs/22/bin:$PATH
./rea-ghidra d1 analyze --json --out /tmp/analyze.json -- \
    examples/demo --provider ghidra --snapshot /tmp/demo.snap

# 4) Error path: unknown command (exit 2)
./rea-ghidra run not-a-command            # → 2

# 5) Error path: wrong domain (doctor belongs to d10, not d2)
./rea-ghidra d2 doctor                    # → 2
```

## Implementation

| Side | Library | Entry |
| --- | --- | --- |
| bash | `lib/rea-wrap.sh` (`rea_wrap_exec` / `rea_domain_dispatch` / `rea_tsv_lookup` / `rea_domains_table`) | `rea-ghidra` |
| PowerShell | `lib/rea-wrap.ps1` (`Invoke-ReaCommand` / `Get-ReaDomainsTable` / `Get-ReaCommandRecord`) | `rea-ghidra.ps1` |

Internally it reuses `lib/common.sh` / `lib/common.ps1` (`resolve_jdk_home` / `resolve_ghidra_dir` / `rea_mode`) and builds the REA invocation the same way `verify.sh` does: prefer the global `rea`, else `npx -y rea-agents@<REA_VERSION>`; cn mode pulls via the npmmirror registry (process-local only).

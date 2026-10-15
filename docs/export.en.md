[English](export.en.md) | [简体中文](export.md)

# Ghidra static analysis export (no REA required)

`ghidra-export` uses Ghidra's native `analyzeHeadless` to analyze a binary and export machine-readable artifacts (JSON / pseudocode), **without relying on rea-agents / Node / npm** — pure Ghidra capability. Good for: batch reverse engineering, exporting function lists / call graphs to downstream tools, and binary regression in CI.

## Quick usage

```bash
# Linux / macOS
scripts/ghidra-export.sh <binary> --out <dir> --kind all
scripts/ghidra-export.sh ./examples/demo --out /tmp/out --kind functions
scripts/ghidra-export.sh --help

# Windows (PowerShell)
pwsh -File scripts/ghidra-export.ps1 -Bin .\examples\bin\windows-x64\demo.exe -Out .\out -Kind all
```

- Auto-locates `GHIDRA_INSTALL_DIR` (env first, then `~/tools/ghidra_*_PUBLIC`) and `JAVA_HOME`.
- Each run uses an isolated temp Ghidra project dir (`mktemp -d`) cleaned up automatically, so the project store is not polluted.
- Cross-platform timeout: prefers GNU `timeout`, then `gtimeout` (macOS coreutils), else bare run; override with `REA_EXPORT_TIMEOUT` (seconds, default 1800).

## --kind and artifact fields

`--kind` takes `functions|strings|symbols|calls|decompiled|all` (default `all`). `all` exports all 5 kinds at once.

| Artifact | Script | Fields |
|---|---|---|
| `functions.json` | ExportFunctions | `address`, `name`, `signature`, `thunk` |
| `strings.json` | ExportStrings | `address`, `value`, `length` |
| `symbols.json` | ExportSymbols | `address`, `name`, `type`, `namespace` |
| `calls.json` | ExportCalls | `caller_address`, `caller`, `callee_address`, `callee` |
| `decompiled.json` | ExportDecompiled | object: `"function name": "C pseudocode text"` |

Scripts live in `scripts/ghidra/` and run via `-postScript`; each script takes arg 1 = output dir. Direct analyzeHeadless example:

```bash
"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" <projDir> Proj \
  -import <binary> -scriptPath scripts/ghidra \
  -postScript ExportAll.java <outDir> -deleteProject
```

JSON is hand-escaped by the scripts (gson is not guaranteed on classpath); artifacts parse directly with `python3 -c "import json;json.load(open('functions.json'))"`.

## Regression self-test

```bash
bash scripts/selftest-export.sh
```

Runs `--kind all` against `examples/demo` and asserts: all JSON legal, ≥1 function, `main` present, and non-empty strings/symbols/call edges/pseudocode. The three-platform e2e wires in this regression (Windows runs `functions` against `examples/bin/windows-x64/demo.exe`).

## Relationship to legacy scripts

- `scripts/DecompileAll.java` + `scripts/ghidra-decompile.sh` (since v2.2) remain as a backward-compatible thin entry; the new capability is a superset, and `--kind decompiled` corresponds to its decompile artifact.
- All new scripts are licensed under this repo's PolyForm Noncommercial 1.0.0 (original code, not copied from MIT projects).

## Output example (examples/demo)

```
functions.json: 21 functions (incl. main, _init, printf, etc.)
strings.json:   83 strings
symbols.json:    102 symbols (Function / Label)
calls.json:      14 call edges
decompiled.json: pseudocode for 18 functions
```

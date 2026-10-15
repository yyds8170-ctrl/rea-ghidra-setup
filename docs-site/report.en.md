[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/report/) | English

# Structured reverse-engineering report generator

The report generator turns a Ghidra analysis of a binary into a **human-readable Markdown** report and a **self-contained HTML** (inline minimal CSS, no CDN, no JS) — ready to archive, share with colleagues, or paste into an issue.

## Command

```bash
# Linux / macOS
./rea-ghidra export ./examples/demo --out /tmp/out --kind all
# After export, scripts/ghidra-report assembles the report:
bash scripts/ghidra-report /tmp/out --binary ./examples/demo --report-dir /tmp/report

# Windows PowerShell
.\rea-ghidra.ps1 export .\examples\demo --out .\out --kind all
pwsh -File scripts\ghidra-report.ps1 .\out -Binary .\examples\demo -ReportDir .\report
```

Outputs:

```
/tmp/report/
├── report.md        # human-readable Markdown
└── report.html      # self-contained HTML (inline CSS, works offline)
```

## Sections

| # | Section | Content | Source |
|---|---|---|---|
| 1 | Metadata | path, format (ELF/PE/Mach-O), arch, language ID, compiler ID, md5, sha256, entry | shell-side md5/sha256 before import; `getExecutableFormat()` / `getLanguageID()` / `getCompiler()` |
| 2 | Segments | name, start, end, size, R/W/X bits | `Memory.getBlocks()` |
| 3 | Security | NX, Canary, PIE, stripped flags | inferred from segment perms and import names (e.g. `__stack_chk_fail`) |
| 4 | Imports | external libraries and imported names | `ExternalManager` / `getExternalSymbols()` |
| 5 | Exports | global functions (excluding thunks / externals) | `FunctionManager` |
| 6 | Strings | printable strings ≥ 4 bytes (address + value) | `ExportStrings` |
| 7 | Key functions & constants | function list (address, signature); high-entropy constants | `ExportFunctions` |
| 8 | Cross-references | refs to key addresses (call / data / read / write) | `ReferenceManager.getReferencesTo(Address)` |
| 9 | Call graph | caller → callee edges | `ExportCalls` |
| 10 | Decompiled summary | C pseudocode snippets for key functions | `DecompInterface` (`-analysisTimeoutPerFile 300`) |

## Sample Markdown

```markdown
# Reverse Engineering Report — demo

## 1. Metadata
| Field | Value |
|---|---|
| Format | ELF : x86-64 (shared object) |
| Compiler | gcc 13.2 (DWARF: -O0 -g) |
| MD5 | 3f2a…c91b |
| SHA-256 | 9b7e…04d2 |
| Entry | 0x00001060 |

## 3. Security
- NX: enabled (stack segment is RW, not RWE)
- Canary: present (imports __stack_chk_fail)
- PIE: enabled (ET_DYN)
- Stripped: no (symbols present)

## 6. Strings
| Address | Value |
|---|---|
| 0x00002004 | "Usage: %s <password>\n" |
| 0x0000201c | "Access granted\n" |
| 0x0000202c | "Wrong password\n" |
```

## Design principles

- **Zero third-party deps**: relies only on the JDK and classes shipped with Ghidra; hand-rolled JSON escaping, no gson.
- **Offline-friendly**: inline CSS in HTML, no CDN fonts/JS/icons — opens on an air-gapped box.
- **CI-friendly**: `-analysisTimeoutPerFile 300`, isolated temp project dir, `-deleteProject`, no residue.
- **Address-decoupled assertions**: addresses/constants are printed in both decimal and `0x…` form so downstream assertion scripts can match either.

> The report generator lives under `scripts/ghidra-report` and is maintained by the organizer; this page describes behavior and usage only. Actual script paths/args:
> [scripts/ tree](https://github.com/yyds8170-ctrl/rea-ghidra-setup/tree/main/scripts).

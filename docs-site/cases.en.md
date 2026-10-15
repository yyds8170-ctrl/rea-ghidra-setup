[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/cases/) | English

# Case library walkthrough

The case library lives under the repo's [`examples/`](https://github.com/yyds8170-ctrl/rea-ghidra-setup/tree/main/examples) directory and is exercised end-to-end by `examples/walkthrough.sh`. Every case follows the same design rules:

- Built with `gcc -O0 -g -fno-builtin` so function names are legible;
- A stripped twin is kept, to prove that key constants/strings are recognizable without symbols;
- Assertions rely **only on strings, constants and function names** — **never on absolute addresses** (which drift with compile/link offsets);
- In Ghidra decompiler output, constants may render as decimal or `0x…`; assertions search both forms.

The five themes below go from easy to harder. Each one tells you what you'll actually learn.

## 1. crackme password check

- **Key constants/strings**: hard-coded password, length-comparison constant, success string `Access granted` / failure string `Wrong password`.
- **What you learn**:
    - Pull prompt strings straight out of `strings.json` and locate the comparison near `main`;
    - Recognize `strcmp` / `strncmp` / hand-rolled length compare in pseudocode;
    - On the stripped binary, reverse-engineer the entry function via string xrefs.

## 2. license-key check

- **Key constants/strings**: hard-coded salt, prefix/suffix constants (e.g. `RK-2026-`), failure messages.
- **What you learn**:
    - Tell "online check" apart from "local check" — local checks usually reduce to a single bool-returning function;
    - Spot checksum signatures (CRC32 / simple XOR / hand-rolled LCG) via characteristic constants (e.g. CRC32 polynomial `0xEDB88320`);
    - Use `calls.json` to drop noise (printf/exit) and focus on the validator.

## 3. tiered pricing

- **Key constants/strings**: bracket thresholds (e.g. `100 / 1000 / 10000` units), per-tier unit prices, unit strings `USD/CNY`.
- **What you learn**:
    - Recognize the chain `if (n < 100) … else if (n < 1000) …`;
    - Translate magic numbers in decompiler output back into business semantics;
    - Use the `signature` field of `functions.json` to count parameters and isolate the pricing function.

## 4. switch dispatch (jump table)

- **Key constants/strings**: case count, default branch, the prompt string each case prints.
- **What you learn**:
    - Watch Ghidra reconstruct a `switch` as a jump table;
    - Follow `calls.json` to see which child function each case actually jumps to;
    - See how optimization (`-O0` vs `-O2`) changes jump-table vs if-else-chain shape.

## 5. export pipeline

- **Key artifacts**: `functions.json` / `strings.json` / `symbols.json` / `calls.json` / `decompiled.json`.
- **What you learn**:
    - Point the `export` subcommand at a real binary and inspect each of the five JSON kinds;
    - Use `batch` to run `demo` and `demo_stripped` side by side and diff the symbols;
    - Build a CI binary regression: run export once per build and diff the JSON.

## Run it

```bash
# Build fixtures (demo / demo_stripped / multi-arch cross artifacts)
bash scripts/build-fixtures.sh

# End-to-end walkthrough (idempotent, read-only)
bash examples/walkthrough.sh

# Single-target export
./rea-ghidra export ./examples/demo --out /tmp/out --kind all
```

> Real case sources and assertion scripts are maintained in parallel by another engineer; this page is only a guide. Actual paths follow the `examples/` tree:
> [examples/ tree](https://github.com/yyds8170-ctrl/rea-ghidra-setup/tree/main/examples).

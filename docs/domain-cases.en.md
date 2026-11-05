# Domain Cases — Automated Assertions (v5.6.0)

> Turns the capability-map entries marked "✅ testable on Linux / 🔧 requires tool" into **real, CI-run assertions** rather than just doc labels.
> Runner: [`scripts/run-domain-cases.sh`](../scripts/run-domain-cases.sh); fixture generator: [`scripts/build-domain-fixtures.sh`](../scripts/build-domain-fixtures.sh).
> CI job: `domain-cases` in `.github/workflows/ci.yml` (schedule / workflow_dispatch only).

## Principles

- **Real Linux runs only**: no Android devices, no JEB, no macOS, no docker. When a prerequisite is missing the case is **explicitly skipped with a reason** — never silently counted as tested.
- **Pass contract**: success means rea-wrap exit 0 **and** the JSON contains the expected fields (`architecture` / `procedure_count` / `string_count` / `segment_count`, or the matching inspect structure); any non-zero exit is a failure.
- **Skip contract**: missing tool / sample / runtime version profile → counted as skipped, does not fail the job (CI only requires `failed=0`).

## Fixtures (gitignored products; sources committed)

`scripts/build-domain-fixtures.sh` writes into `examples/domain-fixtures/` (gitignored):

| Fixture | How it is built | Commands under test |
|---|---|---|
| `sample.pyc` | `py_compile` of [`sample.py`](../examples/domain-fixtures_src/sample.py) (holds `DOMFIX-2026`, `greet`, `Counter`) | `inspect-python-pyc` |
| `sample.db` | stdlib sqlite3, tables `items`/`meta` with rows | `inspect-sqlite-database` |
| `sample.pcap` | Python `struct`: libpcap header + one ethernet/IP/TCP packet | `inspect-pcap-capture` / `inspect-pcap-client` |
| `add.wasm` / `sub.wasm` | `wat2wasm` of [`add.wat`](../examples/domain-fixtures_src/add.wat) / [`sub.wat`](../examples/domain-fixtures_src/sub.wat) (different export sets) | `inspect-wasm-artifact` / `compare-wasm-interfaces` |
| `linux_x86_64` ELF | reused `examples/fixtures/` output of [`build-fixtures.sh`](../scripts/build-fixtures.sh) | objdump / pwntools / gdb / rizin / built-in static commands |

## Covered commands and prerequisite profiles

| REA command | Domain | Prerequisite (else skip) | Asserted fields |
|---|---|---|---|
| `inspect-python-pyc` | ⑦ multiformat | python3 (built-in) | header.python_version=3.x, code_objects names include greet, const holds DOMFIX-2026 |
| `inspect-sqlite-database` | ⑦ multiformat | **Node ≥ 24.15** (REA sqlite provider) | normalized_result non-empty, table items present |
| `inspect-wasm-artifact` | ⑦ multiformat | **REA_WABT_BIN_DIRECTORY → WABT 1.0.42** | validation=valid, export add present |
| `compare-wasm-interfaces` | ⑦ multiformat | same (two inspect Evidence records, left/right/scope) | scope=exports, changes non-empty |
| `inspect-pcap-client` | ⑦ multiformat | **Wireshark tshark/capinfos 4.x** | Evidence envelope mentions tshark |
| `inspect-pcap-capture` | ⑦ multiformat | same + sample.pcap | normalized_result non-empty |
| `inspect-with-objdump` | ② offline binary | binutils objdump | raw stdout contains elf64-x86-64 |
| `list-objdump-architectures` | ② offline binary | binutils objdump | raw stdout contains elf64-x86-64 |
| `inspect-binary-layout` | ② offline binary | **REA_PWNTOOLS_PYTHON pinned pwntools4.15.0/pyelftools0.33/unicorn2.1.2** | architecture.bits=64, sections non-empty |
| `debug-with-gdb` | ③ dynamic | gdb + a pty as --inferior-tty | MI records contain the GNU gdb banner |
| `execute-rizin-command` | ③ dynamic | rizin | Evidence envelope |
| `debug-with-rizin` | ③ dynamic | rizin | Evidence envelope |
| `inspect-artifact` | ② offline binary | built-in | observations non-empty |
| `inspect-byte-entropy` | ② offline binary | built-in | file_entropy ∈ [0,8] |
| `inspect-elf-notes` | ② offline binary | built-in | machine=62 (EM_X86_64) |
| `capabilities` | ⑩ platform self-check | built-in | capabilities non-empty array |

## Mapping to the capability map

- The "Prerequisite" column above is the concrete profile behind the map's 🔧 (requires tool) label; installing the pinned tool on host/CI flips it from "not tested" to an automated PASS.
- 📱 needs-device (adb/frida/browser/live UI), 🍎 needs-macos, 💼 needs-jeb commands are **not** listed here and keep their "not tested" map labels.
- `list-architectures` is tagged linux-testable in the TSV but actually requires macOS Hopper native tools (unsupported_host on Linux), so it is intentionally excluded.

## Local run

```bash
export PATH=/opt/nodejs/22/bin:$PATH
bash scripts/build-fixtures.sh          # produces examples/fixtures/linux_x86_64
bash scripts/build-domain-fixtures.sh  # produces examples/domain-fixtures/
# Provide pinned profiles as needed (missing one -> its cases skip):
export REA_WABT_BIN_DIRECTORY=/path/to/wabt-1.0.42/bin
export REA_PWNTOOLS_PYTHON=/path/to/venv-with-pwntools4.15.0/bin/python
bash scripts/run-domain-cases.sh
```

## CI job design (domain-cases)

- Triggers: `schedule` / `workflow_dispatch` (same as fixture-multiarch).
- Runner: `ubuntu-latest` (24.04 ships Wireshark 4.x).
- Node **24** (sqlite provider); core apt packages binutils/gdb/tshark installed hard-fail (no masking); official **WABT 1.0.42** release unpacked to `~/.local/wabt-1.0.42` and its bin appended to `$GITHUB_PATH` (so later build/run steps find wat2wasm on PATH); pinned pwntools venv at `/opt/rea-pwntools-env`; rizin attempted separately with `|| true` from universe, else its two cases stay skipped.
- No Ghidra/JDK required (all commands are outside 1-core-native), lighter than e2e.
- Final assertion: `summary line 汇总：passed=N failed=0 skipped=M`.

## Real counts

- **Local (Linux x86_64, with wabt 1.0.42 + gdb + pinned pwntools venv)**：`passed=11 failed=0 skipped=5`.
  skips: sqlite (local Node 22; provider needs Node ≥24), pcap pair (local Wireshark 3.6.2; needs 4.x), rizin pair (not installed locally).
- **CI (Node 24 + ubuntu-24.04 Wireshark 4.x + wabt 1.0.42 + pinned pwntools)**：expected `passed=14 failed=0 skipped=2`——
  sqlite / pcap×2 / wasm×2 / gdb all flip to PASS in CI; the 2 skips are rizin (`execute-rizin-command` / `debug-with-rizin`).
  If CI's universe resolves rizin, it becomes `passed=16 failed=0 skipped=0`. **When rizin cannot be installed on the runner, those two cases stay skipped and are never written as tested.**

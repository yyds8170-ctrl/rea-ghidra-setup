[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/exit-codes/) | English

# Exit codes and machine-readable error output

The bash scripts in this project (`install.sh` / `install-macos.sh` /
`scripts/ghidra-export.sh` / `scripts/batch-analyze.sh` / `scripts/doctor.sh`, etc.)
share a unified set of named exit codes. Errors appear in two forms: the human-readable
`[ERR]` line still goes to stderr; and when stderr is not a TTY (CI / pipe / redirect),
an extra single-line JSON envelope is appended for scripts and CI to parse.

## Exit code table

| Code | Constant | Meaning | Typical triggers |
| --- | --- | --- | --- |
| `0` | `RC_OK` | Success | Normal run, `--help` / `--dry-run`, diagnostics all pass |
| `1` | (unclassified) | Legacy compatibility | Old code paths; `die <msg>` is `fatal 1`. Use named codes in new code |
| `2` | `RC_USAGE` | Usage / argument error | Unknown flag, missing/extra targets, missing value for `--out` / `--kind` |
| `10` | `RC_DEPENDENCY` | Missing local dependency | curl/unzip/tar missing; JDK21 / Ghidra / qualifying Node not found; versions file missing |
| `11` | `RC_CHECKSUM` | Checksum verification failed | Downloaded artifact SHA-256 mismatches upstream/offline manifest; file deleted, abort |
| `12` | `RC_UPSTREAM` | Upstream/unavailable resource, or environment mismatch | Download failed, URL unreachable, target binary missing, unsupported CPU arch, running install-macos.sh on Linux |
| `13` | `RC_DISK` | Insufficient disk space | Install dir or temp dir below the required free-space threshold |

## JSON envelope example

```json
{"error": {"code": 10, "name": "RC_DEPENDENCY", "message": "Ghidra not found (set GHIDRA_INSTALL_DIR or run install.sh first)", "tool": "ghidra-export.sh"}}
```

`code` equals the process exit code; `message` may contain non-ASCII/quotes and is
escaped by `python3 json.dumps`; `tool` is the basename of the failing script.
No JSON line is emitted on a TTY, keeping the terminal clean.

## Consuming from CI / wrapper scripts

```bash
bash install.sh --no-such-flag >/dev/null 2>/tmp/e.txt; rc=$?
[ "$rc" -eq 2 ] || exit 1
python3 - /tmp/e.txt <<'PY'
import json, sys
lines = [l for l in open(sys.argv[1], encoding='utf-8') if l.strip().startswith('{')]
env = json.loads(lines[-1])
assert env['error']['code'] == 2 and env['error']['name'] == 'RC_USAGE'
PY
```

## Per-script semantics

- `scripts/doctor.sh`: diagnostic semantics are preserved (0 = all pass / 1 = FAIL items) — do not treat its exit code as "command failure".
- `scripts/batch-analyze.sh`: the worker always exits 0 and records failures in `.results/*.json` (by design); only usage errors use `RC_USAGE=2`.
- `uninstall.sh` / `verify.sh` / `scripts/run-cases.sh`: only usage errors use 2; other legacy exit semantics are unchanged.

Full reference:
[docs/exit-codes.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/exit-codes.md).

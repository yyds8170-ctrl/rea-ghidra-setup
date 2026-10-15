[English](batch.en.md) | [简体中文](batch.md)

# Parallel batch analysis + snapshot cache (v2.8)

On top of v2.7 single-target export ([export.md](export.en.md)), orchestrates **a batch of binaries** in parallel: faster, resumable, failure-isolated, content-addressed cache. No REA / Node required.

## Quick usage

```bash
# positional args give multiple binaries
scripts/batch-analyze.sh a.elf b.elf c.elf --out ./batch-out --kind functions --jobs 3

# or collect by directory (--recurse recursive, --pattern glob filter)
scripts/batch-analyze.sh --dir ./bins --recurse --pattern '*.elf' --kind all \
  --jobs 4 --snapshot ./cache
```

Windows: `pwsh -File scripts/batch-analyze.ps1 -Bin a.elf,b.elf -Out .\batch-out -Kind functions -Jobs 3`.

## Options

| Option | Meaning |
|---|---|
| `--out DIR` | Output root (default `./batch-out`) |
| `--kind` | `functions\|strings\|symbols\|calls\|decompiled\|all` (forwarded to ghidra-export, default all) |
| `--jobs N` | Parallelism; default CPU count (Linux `nproc` / macOS `sysctl -n hw.ncpu`) capped at 4 and not above target count |
| `--retries M` | Retries per failed target (default 1, reruns only that target) |
| `--snapshot DIR` | Snapshot cache dir; omitted = no cache |
| `--continue` | Skip targets already fully produced |
| `--dir/--recurse/--pattern` | Directory collection |

## Parallelism model

- bash: `xargs -0 -P $JOBS -I{}`, each target is a subprocess calling `ghidra-export.sh`, writing its own `.results/<sha12>.json` (**never writes the same file in parallel**); the parent summarizes at the end.
- PS: `Start-Job` + throttled wait (one code path for PS5.1/7, no 7-only `ForEach-Object -Parallel`).
- Each target uses an isolated temp Ghidra project (ghidra-export `mktemp -d` + trap cleanup), isolated from others.

## Failure isolation and retries

A single target failing does not stop the others; `--retries` reruns only that target. After everything finishes, `--out/summary.json` is written; exit code: all success = 0, **any failure = 1** (never exits early).

## Snapshot cache

Cache key = `<binary sha256>_<kind>_v<EXPORT_SCHEMA_VERSION>`.
- Hit: skips analyzeHeadless and restores cached artifacts into that target's output dir; summary marks `cached:true`.
- Miss: analyzes normally and writes the cache.
- Invalidation: binary content change (sha), kind change, or bumping `EXPORT_SCHEMA_VERSION` (when v2.7 export scripts/schema change, bumping this constant auto-invalidates old cache).
- Measured: 3 small targets first run ~48s, second run with same snapshot **1s, 3/3 fully cached**.

## summary.json schema

```json
{
  "export_schema_version": 1,
  "total": 3, "success": 3, "failed": 0, "skipped": 0, "cached": 3,
  "total_elapsed_sec": 1,
  "targets": [
    {"input":"/path/a","sha256":"...","status":"success","cached":true,
     "elapsed_sec":0,"retries":0,"out_dir":".../targets/<sha12>","error":""}
  ]
}
```

## Performance tips

- Each `--jobs` worker is a JVM (default ~2G heap); memory is the bottleneck. Estimate by runner RAM (16G → 3~4 parallel).
- On CI use `--kind functions` (single kind, faster per target) to control time; full `all` stays local.
- Repeated runs on the same batch (regression, script tuning) should always use `--snapshot`; from the second run it is nearly free.

## Regression

```bash
bash scripts/selftest-batch.sh   # 3 targets first success → second fully cached → failure-isolation assertion
```

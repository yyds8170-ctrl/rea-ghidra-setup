[English](benchmark.en.md) | [简体中文](benchmark.md)

# Performance Benchmark (reproducible)

> Every number on this page was **measured on this machine** (not estimated), measured 2026-11-06.
> The subject is this repo's Ghidra-native `analyzeHeadless` headless pipeline behind
> `scripts/ghidra-report.sh` / `scripts/ghidra-export.sh` / `scripts/batch-analyze.sh`;
> it does **not** depend on the REA / Node runtime. Verbose logs live outside the worktree and are not committed.

## 1. Environment (fixed)

| Item | Value |
|---|---|
| OS | Ubuntu 22.04.5 LTS x86_64 (cloud VM; `uname -srm` = Linux 6.6 x86_64) |
| CPU | 4 vCPU (`nproc` = 4) |
| RAM | 8128 MB total, ~7.3 GB free at measure time, **swap = 0** |
| Ghidra | 12.1.4 (`ghidra_12.1.4_PUBLIC`, current-ghidra points here) |
| JDK | Temurin 21 (`jdk-21.0.12.1+1`, current-jdk) |
| Portable Node / REA | Node 24.22.2 / rea-agents 6.8.0 (not invoked by export/batch) |
| JVM heap | analyzeHeadless default `-Xmx` 2G (`GHIDRA_HEADLESS_MAXMEM` unset) |

> Versions come from `config/versions.env`; they are not hard-coded on this page.

## 2. Targets (deterministically built)

| Target | Size | Functions | How built |
|---|---:|---:|---|
| `examples/demo` | 17,928 B ELF (PIE, debug, not stripped) | 21 | `make -C examples` (gcc -O0 -g) |
| `t00` (single large sample) | 159,536 B ELF | 617 | gcc -O0 -g, 600 arithmetic functions + fn-pointer table |
| `t00`…`t07` (8 parallel samples) | 159,536 B ELF each | 617 each | same body, only `const char *TARGET` differs → distinct sha256, equal per-target cost |

## 3. Single-target repeats (`scripts/benchmark.sh`)

`examples/demo` run 3 times, each in a fresh temp project (`-deleteProject`, no cache reuse):

| Metric | min | median | max |
|---|---:|---:|---:|
| End-to-end wall (JVM start + import + analysis + JSON export) | 30.17 s | 30.50 s | 30.71 s |
| Ghidra auto-analysis phase (log `Total Time`) | 5 s | 5 s | 5 s |

- **Spread**: wall range 0.54 s (~±0.9% around median); analysis stable at 5 s.
- The bulk is cold JVM start + import + decompile/export (~25 s); Ghidra auto-analysis itself is only ~5 s.

Large-sample single-target comparison (`ghidra-export.sh --kind all`, one shot):

| Target | Wall | Ghidra `Total Time` |
|---|---:|---:|
| `examples/demo` (18 KB / 21 funcs) | 33.9 s | 5 s |
| `t00` (159 KB / 617 funcs) | 39.9 s | 9 s |

→ Functions 21 → 617 (~29×) moves analysis 5 s → 9 s; the added wall is dominated by fixed JVM startup.

## 4. Parallel `--jobs` sweep (8 equal-cost targets, cold, no snapshot)

`batch-analyze.sh --kind functions`, N=8 targets, fresh out dir each run (no cache):

| `--jobs` | Total wall | Per-target range | Speedup vs jobs=1 |
|---:|---:|---|---:|
| 1 | 282 s | 32 – 42 s | 1.00× |
| 2 | 233 s | 47 – 76 s | 1.21× |
| 4 | 214 s | 96 – 117 s | 1.32× |

**Finding (this 8 GB box)**: parallelism is **not near-linear**. jobs 1→2 helps (−49 s), 2→4 barely
helps (−19 s), and per-target wall grows sharply (~37 s → ~105 s). Each concurrent `analyzeHeadless`
is a JVM with ~2 G heap; 4 workers ≈ 8 G heap + RSS approach the 8 GB physical limit with no swap,
so memory contention dominates. This matches `docs/batch.md` ("run 3–4 on 16 G; memory is the bottleneck") —
**on an 8 GB box, prefer `--jobs 2`**.

## 5. Snapshot cache: cold vs warm (8 targets, `--jobs 4`, `--kind functions`)

| Phase | Total wall | Cache hits | Notes |
|---|---:|---:|---|
| Cold (populate `--snapshot`) | 219 s | 0 / 8 | real analyzeHeadless analysis, results written to cache |
| Warm (same snapshot, fresh out dir) | **1 s (measured wall 0.56 s)** | **8 / 8** | analysis skipped, cached JSON copied back |

→ Re-running against the same snapshot is ~**219×** faster, 8/8 hits. Consistent with `docs/batch.md`
("second run ~1 s, all hits"). Cache key = `<binary sha256>_<kind>_v1`; any change to content/kind/schema invalidates it.

## 6. Reproducible commands

```bash
# Prereqs: JDK21 + Ghidra installed (./rea-ghidra current should point at ghidra_12.1.4_PUBLIC)
cd <repo>

# (a) Single-target repeats (section 3): ~30s × 3 ≈ 90s
bash scripts/benchmark.sh examples/demo --runs 3 --out /tmp/bench-demo

# (b) Deterministically build 8 equal-cost targets (gcc -O0 -g; pick your own dirs)
mkdir -p /tmp/bt/src /tmp/bt/targets
for k in 0 1 2 3 4 5 6 7; do
  { echo '#include <stdio.h>'; echo "const char *TARGET=\"t0$k\";"
    for i in $(seq 1 600); do
      echo "static int fn_$i(int x){ int r=x*$i+($i%97); r=(r^(r>>3))*($i|1); return r&0xffff; }"
    done
    echo "static int (*const tbl[])(int)={"
    for i in $(seq 1 600); do echo "fn_$i,"; done
    echo "}; int (*f)(int); int main(void){ long s=0;"
    echo "  for(int i=0;i<600;i++){ f=tbl[i]; s+=f(i); }"
    echo '  printf("%s %ld\n", TARGET, s); return (int)(s&0xff); }'
  } > /tmp/bt/src/t0$k.c
  gcc -O0 -g -o /tmp/bt/targets/t0$k /tmp/bt/src/t0$k.c
done

# (c) Parallel jobs sweep (cold; time each; use a fresh out dir per run)
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/j1 --kind functions --jobs 1
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/j2 --kind functions --jobs 2
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/j4 --kind functions --jobs 4
# Total wall per run: the "[batch] done ... total Ns" line, or total_elapsed_sec in out/summary.json

# (d) Cache cold vs warm
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/cold --kind functions --jobs 4 --snapshot /tmp/bt/snap
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/warm --kind functions --jobs 4 --snapshot /tmp/bt/snap
# summary.json for the warm run should report cached = 8

# Link self-check
bash scripts/check-docs-links.sh
```

## 7. Caveats and spread

- **Run sequentially, avoid contention**: run one measurement batch at a time; inside a parallel batch the
  script manages the JVMs via `xargs -P`. Sharing the box with other heavy processes inflates wall time.
- **Machine-dependent conclusions**: the non-linear scaling in §4 is observed on 8 GB / swap=0; on 16 GB+
  `--jobs 4` scales more linearly. Re-measure on a different box — do not extrapolate.
- **Spread**: single-target wall ±~1–2 s; parallel totals ~±10% with system load. The headline results
  (1.32×, 219× cache) reproduce steadily here and do not depend on a lucky run.
- **Not measured here**: macOS/Windows, multi-arch cross fixtures, and needs-device / needs-macos /
  needs-jeb scenarios are excluded (see `docs/release-validation.md`).

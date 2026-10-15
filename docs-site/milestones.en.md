# Milestone status

This page tracks the release state of each version in this iteration: version / tag / commit / CI / Release assets / validation summary. All numbers come from real runs.

## Release table

| Version | tag | commit | CI (full 9 jobs) | Release assets (tar.gz / checksums / spdx) | Theme |
| --- | --- | --- | --- | --- | --- |
| v4.1.0 | `v4.1.0` | `b35e433` | 9/9 green | 408828 / 97 / 27642 bytes | Named exit codes + machine-readable JSON error envelope |
| v4.2.0 | `v4.2.0` | `34ff293` | 9/9 green | 414275 / 97 / 27642 bytes | Atomic install lock + half-install self-heal + CI cache fallback |
| v4.3.0 | `v4.3.0` | `9465577` | 9/9 green | 417267 / 97 / 27642 bytes | NUL-safe collection + WSL /mnt warning + upstream drift report |
| v5.0.0 | `v5.0.0` | see commit log | 9/9 green | see Release | Final: full sync + final health check |

## Per-version validation summary

- **v4.1.0**: verify 9/9; run-cases 10 binaries, 55 assertions, 0 failures; dead links 0; mkdocs strict; exit-code manual checks 2/10/11/12 + JSON envelope correct.
- **v4.2.0**: real install.sh lock acquired → components idempotent → done exit 0 → lock cleaned; selftest-install-lock 7/7; shellcheck -x 0; bash3.2 adjacency clean.
- **v4.3.0**: selftest-batch 4/4; newline filename counts as 1 target; selftest-install-lock 7/7; check-versions green (Ghidra 12.1.4 / rea-agents 6.5.0 / Node 24.22.0 match upstream).

## Known limitations / not run on real hardware / not authorized (risk list)

- **Real Windows box**: local machine is Linux only; Windows behavior is verified on GitHub `windows-latest` runners (e2e-windows / verify.ps1).
- **Real macOS box**: verified on `macos-latest` runners (Apple Silicon arm64, incl. native build).
- **Real large-file corruption / filling the disk**: RC_CHECKSUM=11 is validated via a tampered offline-package unit test; RC_DISK=13 goes through the fatal common path but the disk was not actually filled.
- **Dockerfile real build**: no local docker; covered by CI `docker` / `docker-arm64` jobs (build then run verify.sh in-container).
- **GHA action upgrades**: the drift report shows local pins (checkout@v4 etc.) lag upstream majors; per "no blind upgrades" they are left as WARN.
- **GHCR image / external registries**: not published per constraints; images are only built and `docker run`-verified inside CI, never pushed.

[简体中文](release-validation.md) | English

# v6.0.0 Release Validation Report

> This document is the **final release-validation basis** before tagging `v6.0.0` and
> cutting the GitHub Release. Every count and conclusion is grounded in real files in this
> repo and real CI re-runs. Prerequisites this environment cannot reproduce
> (a physical Android device / macOS / JEB / docker) are explicitly marked
> **"documented only, not tested here"** — never presented as already tested.

## 1. Validation overview

| Check | Result | Environment / evidence |
|---|---|---|
| Local `bash verify.sh` | **9 / 9 passed** | Local Linux x86_64: JDK21 + Ghidra 12.1.4; `analyze` recognizes ELF / x86_64, procs=28, strings=83 |
| Full CI (`.github/workflows/ci.yml`) | **9 / 9 green** | Real GitHub Actions runners, full regression (list below) |
| CI `domain-cases` job | **16 passed / 0 failed / 0 skipped** | ubuntu-24.04 + Node 24 + Wireshark 4.x + WABT 1.0.42 + pinned pwntools + rizin 0.9.1 |
| CI `fixture-multiarch` job | **Three-arch import assertions all pass** | Ghidra imports ELF32→`x86:LE:32`, AArch64→`AARCH64:LE:64`, PE32 export non-empty |
| MCP stdio handshake | **Pass** | `bash scripts/mcp-setup.sh --check`: `initialize` returns `server=rea 6.8.0`, `doctor --provider ghidra` reports available / providerVersion=12.1.4 |

**Full CI: all 9 legs green** — `lint-build`, `lint-ps`, `e2e` (linux / macos / windows
matrix), `docker`, `docker-arm64`, `checksum`, `fixture-multiarch`, `domain-cases`.
`e2e` / `docker*` / `checksum` / `fixture-multiarch` / `domain-cases` are gated behind
`schedule` / `workflow_dispatch` and all fire on a full regression run.

## 2. Coverage-matrix summary

Command baseline: **175 real commands** (not 176); command names match the committed
baseline [`config/command-baseline/rea-6.8.0.txt`](../config/command-baseline/rea-6.8.0.txt)
line for line. The `completions` and `mcp` integration entry points are **not counted in
the 175**. Per-command detail:
[`docs/capability-map/coverage-matrix.md`](capability-map/coverage-matrix.md).

### 2.1 Counts by 10 domains (total 175)

| Domain | Commands |
|---|---:|
| ① Core / native Ghidra | 20 |
| ② Offline binary | 20 |
| ③ Dynamic debugging | 15 |
| ④ Web / JS / Electron | 28 |
| ⑤ Android / ADB | 33 |
| ⑥ Apple | 9 |
| ⑦ Multi-format | 15 |
| ⑧ Firmware / embedded | 9 |
| ⑨ Evidence / engineering | 16 |
| ⑩ JEB / platform | 10 |
| **Total** | **175** |

### 2.2 Counts by 5 testability classes (total 175)

| Testability | Count | How this release treats it |
|---|---:|---|
| ✅ linux-testable (built-in pure parse, no extra prereq) | **78** | Runs directly on local / Linux runners |
| 🔧 needs-tool (external toolchain required) | **35** | Prereqs installed, really run and asserted in CI (see §2.3) |
| 📱 needs-device (live process / UI / connected device) | **50** | No physical Android device / live debug target here — **documented only, not tested** |
| 🍎 needs-macos (macOS host + LLDB / Apple artifact) | **8** | This environment is Linux — **documented only, not tested** (macOS install/verify regressed by the `e2e` macos runner) |
| 💼 needs-jeb (commercial JEB running / licensed) | **4** | No JEB license here — **documented only, not tested** |

> 78 + 35 + 50 + 8 + 4 = 175, matching the command total.

### 2.3 What really ran vs. what is documented only

- **Really run and asserted (CI `domain-cases`, 16 passed)**: offline binary
  (`inspect-with-objdump`, `list-objdump-architectures`, `inspect-binary-layout`),
  multi-format (`inspect-python-pyc`, `inspect-sqlite-database`, `inspect-wasm-artifact`,
  `compare-wasm-interfaces`, `inspect-pcap-client`, `inspect-pcap-capture`),
  dynamic (`debug-with-gdb`, `execute-rizin-command`, `debug-with-rizin`),
  Evidence / platform self-checks (`inspect-artifact`, `inspect-byte-entropy`,
  `inspect-elf-notes`, `capabilities`). See [`docs/domain-cases.md`](domain-cases.md).
- **Really run (local `verify.sh`)**: the native Ghidra core chain `analyze` / `decompile` /
  `search` (procs=28, strings=83, segments=39; `decompile secret_check` hits 0x539 and
  `calc_discount` hits 0x32, both confidence=observed).
- **Documentated only / not tested here**: 50 needs-device commands (adb / frida / browser
  CDP / live UI), 8 needs-macos (Apple-only), 4 needs-jeb (commercial JEB). These keep the
  "untested / requires X" note in the capability map and are not claimed as tested.

## 3. What changed per version (v5.2.0 → v5.6.0)

| Version | Theme | Highlights |
|---|---|---|
| **v5.2.0** | Adapt to REA 6.8.0 | Upstream rea-agents 6.5.0→6.8.0, portable Node→24.22.2; Node engines gate tightened to the patch segment; the Windows installer **repairs/rebuilds symlinks by link type** (a v2 cache key invalidates the bad-junction cache); old 6.5 snapshots are incompatible and must be rebuilt; zero regression in `analyze/decompile/search` |
| **v5.3.0** | Full 175-command capability map | Added `docs/capability-map/` (10 domain files + 175-row coverage matrix + integrations appendix, 7 fields per command, bilingual); committed baseline `config/command-baseline/rea-6.8.0.txt`; testability labeled per command across 5 classes |
| **v5.4.0** | Unified command wrapper + exit codes | `rea-ghidra` / `rea-ghidra.ps1` add a `run` / `domains` / `d1..d10` wrapper layer with stable exit codes **0 success / 2 usage error / 3 missing prereq / 4 runtime failure** (bash + PowerShell). See [`docs/command-wrapper.md`](command-wrapper.md). |
| **v5.5.0** | Weekly auto-audit + upgrade pipeline | Added `weekly-audit.yml`: weekly read-only probe of rea / Ghidra / JDK21 / Node upstream drift; patch-level auto-opens a PR, dispatches CI as the gate, squash-merges when green; minor/major and any command removal wait for human review, red CI opens a "blocked" issue. See [`docs/weekly-audit.md`](weekly-audit.md). |
| **v5.6.0** | Linux CI domain-case assertions | Added a multi-format fixture generator + `run-domain-cases.sh` assertion runner + `domain-cases` job, upgrading "testable on Linux / needs-tool" commands from doc annotations to real CI-run assertions; missing prereqs are explicitly skipped. See [`docs/domain-cases.md`](domain-cases.md). |

## 4. Risks and known limitations

1. **weekly-audit write path is not end-to-end tested**: the read-only
   `detect → report` path is verified on a real runner (dry-run succeeds, artifact flattened
   to workspace-relative paths). But the side-effecting write path —
   `open PR → dispatch ci.yml gate → poll → squash merge → blocked issue` — was **not run
   end-to-end** because there is currently no real upstream drift and drift must not be
   manufactured; only static checks + script-level / throwaway-clone verification were done.
2. **needs-device (50) / needs-macos (8) / needs-jeb (4) cannot be verified here**:
   respectively no physical Android device / live debug target, no macOS host, no commercial
   JEB license. macOS install/verify is covered by the CI `e2e` macos runner; the rest keep
   the "untested" note in the capability map.
3. **Release is still a manual step**: merging a patch upgrade into main does **not**
   auto-tag / auto-release; a human must tag `v*` to trigger `release.yml`.
4. **Node does not auto-follow across majors**: the audit follows Node LTS only within a
   major (e.g. within v24.x); a cross-major jump (v24→v26) needs human review of the engines
   gate and is only flagged in the drift report.
5. **Prebuilt offline bundles not re-shipped this release**: the tgz files under `offline/`
   are refreshed separately by the existing flow, not in this release.
6. **The two rizin cases are sensitive to runner network**: Ubuntu noble has no apt package,
   so an official self-contained static build is fetched; if download/extract fails
   sporadically, those two cases stay skipped (whole block `|| true`, non-blocking) and are
   not claimed as tested.

## 5. Release assets

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](../.github/workflows/release.yml).
After a full shellcheck pass it produces **3 assets**
(prefix `rea-ghidra-setup-<tag>/`):

| Asset | How produced | Notes |
|---|---|---|
| `rea-ghidra-setup-<tag>.tar.gz` | `git archive` source snapshot | Excludes `offline/`, `.git` and other untracked content |
| `rea-ghidra-setup-<tag>.checksums.txt` | `sha256sum` | SHA-256 checksum of the tarball above |
| `rea-ghidra-setup-<tag>.spdx.json` | Syft SBOM (falls back to a minimal SPDX 2.3) | SPDX JSON software bill of materials; Syft failure does not block release |

> Multi-arch Docker images are not published in the official Release: build them per
> environment with buildx and push to your own registry. This project is a scripts /
> skill set with no compiled artifacts.

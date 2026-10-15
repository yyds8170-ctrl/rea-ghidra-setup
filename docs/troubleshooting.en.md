[English](troubleshooting.en.md) | [简体中文](troubleshooting.md)

# Troubleshooting (cross-platform)

> The first step is always the read-only diagnostics: `bash scripts/doctor.sh` (Windows: `.\scripts\doctor.ps1`), then `rea doctor`. Below are grouped by platform and symptom (all real issues and fixes).

## General

### 1. Wrong JDK version (unsupported_version / requires JDK 21)
Ghidra 12.x requires **exactly JDK 21**; the common error is system/CI default JDK 17.
- Check: `java -version`; `echo $JAVA_HOME` (Windows: `$env:JAVA_HOME`).
- Fix: use the installer's `tools/jdk-21*`, ensure it is first on PATH and `JAVA_HOME` points to it.
- **CI/managed environments inject `JAVA_HOME=JDK17` per step** (overriding user values); `doctor.ps1`/`verify.ps1` now prefer `tools\jdk-21*` and rewrite `$env:JAVA_HOME`.
- Too-new JDK (e.g. 25) may also be unsupported; use Temurin 21.

### 2. Node version not satisfied (^22.19 || ^24.11 || >=26)
- REA rejects Node 23/25 and older 22/24. The installer ships portable Node 24.22.0; with `SKIP_NODE=1` switch yourself.
- With fnm/nvm, watch the injected `NODE_VERSION`; this project names its var `REA_NODE_VERSION`.
- Verify: `node --version` must be ≥ v24.11 (or v22.19 / v26+).

### 3. Slow analysis / timeout / out-of-memory
- Raise startup timeout: `REA_GHIDRA_STARTUP_TIMEOUT_MS=600000` (default 330000).
- Low-RAM machines (cloud desktop/Crostini): `GHIDRA_HEADLESS_MAXMEM=512M` (default 2G).
- The MCP client itself has a request timeout that may fire earlier than Ghidra.

### 4. Download checksum mismatch
- The installer strongly SHA-256 verifies JDK/Node/Ghidra; mismatch deletes and aborts (corrupted/tampered download).
- Retry; if the corporate gateway does TLS interception, use a mirror or offline package ([offline.md](offline.md), Chinese).
- If the checksum source is unreachable (offline/rate-limited), it warns and allows; for Ghidra rate limits set `GH_TOKEN`.

## macOS

### 5. "Cannot be opened because the developer cannot be verified" (Gatekeeper)
REA does not change quarantine for you; the installer runs:
```bash
xattr -dr com.apple.quarantine "$GHIDRA_INSTALL_DIR"
```
If still blocked, run that manually; do not touch `spctl` (system-level, needs admin).

### 6. `unbound variable` / garbled after a variable name (CI or non-UTF-8 locale)
macOS ships `/bin/bash` **3.2.57**; in a non-UTF-8 locale it merges the first byte of a following CJK char into `$VAR`. Scripts uniformly: ① `lib/common.sh` `ensure_utf8_locale()` forces C/en_US.UTF-8; ② always brace variables `${VAR}`. Keep this style when editing.

### 7. Decompile fails / function not found; names have a leading underscore
Mach-O C symbols are prefixed (`_secret_check`). The verify scripts first resolve the real Ghidra name via `rea search --kind procedures --mode regex` before decompiling; do the same in your own commands.

### 8. Apple Silicon missing native decompiler (mac_arm_64)
The official zip lacks `mac_arm_64`. The installer auto-builds it (needs Xcode CLT, `xcode-select --install`). Apple Silicon VMs can only run an arm64 guest.

## Windows

### 9. `rea` not found after global install
Portable Node does not add the npm global dir to PATH automatically. The installer idempotently appends `%APPDATA%\npm` to the **user** PATH; **reopen the terminal**. Temp: `$env:Path="$env:APPDATA\npm;$env:Path"`.

### 10. REA fails in a few seconds with empty stderr
- Confirm it's the JDK 17 issue (#1): `verify.ps1` rewrites `$env:JAVA_HOME` to JDK21.
- REA's error envelope is **JSON (starting with `{`) on stdout**; scripts parse and print `error`/`message`/`rejections`. Manually run: `rea doctor --json`.

### 11. Path / network drive / reparse point unsupported
- Ghidra path must not contain `!` and `^`; use a pure ASCII path like `C:\tools\...`.
- REA Windows P0 supports only **fixed local NTFS**; no UNC/network drives/reparse points. The PE fixture is copied to `$env:TEMP` (local C:) before analysis.

### 12. Script will not run (execution policy)
Use a one-time, process-level bypass (no system policy change):
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### 13. Missing `VCRUNTIME140.dll` (rare)
The official zip ships `decompile.exe`; if VC++ runtime is missing, install Microsoft VC++ Redist x64 (needs admin).

## Linux / WSL / ChromeOS

### 14. arm64 missing `linux_arm_64` native decompiler
The installer auto-builds on aarch64; manually:
```bash
sudo apt install build-essential bison make
bash scripts/build-ghidra-native.sh
```

### 15. WSL2 / Crostini specifics
- In WSL2 put files to analyze inside the Linux filesystem (NTFS mounts are slow and have reparse-point issues).
- ChromeOS uses Crostini only; ARM Chromebooks need to build `linux_arm_64`, disk 15–20GB, stops on logout. See [platform-chromeos.md](platform-chromeos.md) (Chinese).

## Docker

### 16. arm64 build very slow / timeout
QEMU cross-building arm64 on x86 is slow. Use a **native arm64 machine/runner** (this repo CI uses `ubuntu-24.04-arm`) or buildx cache. See [platform-docker.md](platform-docker.md) (Chinese).

### 17. AppArmor / SELinux / permissions
- AppArmor (local test only): `docker run --security-opt apparmor=unconfined ...`.
- SELinux mounts: `-v "$PWD:/workspace:z"`.
- Rootless: headless analysis needs no privileges; troubleshoot device/network namespaces per rootless docs.

## Reporting issues
Attach: full `scripts/doctor.sh` (or `doctor.ps1`) output, `uname -a` (Windows: OS version and `$env:PROCESSOR_ARCHITECTURE`), `rea doctor --json`, the repro command and its `--format json` output. Do not paste tokens under `~/.config` or full env vars publicly.

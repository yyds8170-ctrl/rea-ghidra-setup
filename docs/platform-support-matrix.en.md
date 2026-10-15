[English](platform-support-matrix.en.md) | [简体中文](platform-support-matrix.md)

# Platform × runtime support matrix

> Status:
> - ✅ **supported**: script/image exists and passes in CI or locally.
> - 🟡 **partial**: works with prerequisites (x86_64 only, extra steps).
> - 🟠 **limited**: official component not prebuilt / self-build / no CI run, documented only.
> - ❌ **unsupported**: platform cannot run it, or upstream does not support.
> - ➖ **n/a**: combination does not exist.
>
> Install logic is organized by OS; physical / VM / cloud-desktop (VDI) reuse that OS's scripts. WSL is a Linux guest on a Windows host. Run `bash scripts/detect-env.sh` to auto-detect.

## 0. Locked versions and unified capability (v3.x)

- Locked versions (`config/versions.env`): **Ghidra 12.1.4 / JDK 21 / portable Node 24.22.0 / REA 6.5.0**.
- Unified entrypoint: `./rea-ghidra install|verify|doctor|mcp|export|batch|current|rollback|self-update` (Windows `.\rea-ghidra.ps1`).
- Capabilities: one-command MCP wiring, static export, parallel batch + snapshot cache, multi-arch fixture CI (`fixture-multiarch`: ELF32/AArch64/PE32), self-update ff-only / checksums verification, `current-ghidra`·`current-jdk` symlinks with rollback, Docker amd64+arm64, Release ships `checksums.txt` + SBOM.
- Discovery: explicit env (`JAVA_HOME`/`GHIDRA_INSTALL_DIR`) > `~/tools/current-*` symlinks > versioned-directory enumeration (legacy fallback).

## 1. OS × runtime table

| OS | Bare metal | VM | WSL | Docker | Cloud VDI |
| --- | --- | --- | --- | --- | --- |
| **Linux** | ✅ x86_64 / 🟠 arm64 | ✅ x86_64 / 🟠 arm64 | ✅ WSL2 (Linux flow) | ✅ amd64 / ✅ arm64 (auto native, CI native-tested) | ✅ x86_64 / 🟠 arm64 |
| **Windows** | ✅ 10/11 x64 | ✅ x64 (reuse scripts) | 🟡 Linux inside WSL2 | 🟡 Docker Desktop (Linux containers) | ✅ x64 VDI |
| **macOS** | ✅ Intel + Apple Silicon (arm64 auto native) | 🟡 Apple Silicon runs arm64 guest only | ➖ | 🟡 Docker Desktop (Linux containers) | 🟡 cloud Mac (arm64, auto native) |
| **ChromeOS** | 🟠 Crostini only (x86_64 full / arm64 needs build) | ❌ no generic nested virt | ➖ | 🠾 installable in Crostini (no KVM, slow build) | ➖ (thin client, treat as cloud OS) |

### Notes

- **Linux bare/VM/VDI (x86_64)**: `install.sh` + `verify.sh`, 9/9 locally and in GitHub Actions.
- **Linux arm64**: installer and Docker auto `make ghidra_opt` for `os/linux_arm_64` on aarch64; `docker-arm64` CI uses a native arm64 runner; bare-metal arm64 has no CI runner (documented only).
- **Windows 10/11 x64 bare/VM/VDI**: `install.ps1`/`verify.ps1`/`uninstall.ps1`, user-level no admin, windows-latest CI 9/9; REA Windows P0 supports only **fixed local NTFS**, no network/UNC/reparse paths.
- **Windows on ARM64**: no official `win_arm64` native; REA does not support this combo, ❌.
- **macOS**: `install-macos.sh` trio; Apple Silicon auto-builds `mac_arm_64` and clears Gatekeeper quarantine; macos-latest (arm64) CI 9/9; Intel (`macos-13`) has no CI runner, script-supported but documented only.
- **ChromeOS**: host ❌; only path is **Crostini (Linux dev env, Debian container)** reusing the Linux flow.

## 2. CPU arch and native decompiler

| Arch | Ghidra native dir | Upstream prebuilt | This project |
| --- | --- | --- | --- |
| Linux x86_64 | `os/linux_x86_64/decompile` | ✅ | verify existence |
| Linux arm64 | `os/linux_arm_64/decompile` | ❌ | installer / Dockerfile auto `make ghidra_opt` |
| Windows x86_64 | `os/win_x86_64/decompile.exe` | ✅ | verify existence |
| Windows ARM64 | — | ❌ upstream | ❌ |
| macOS Intel | `os/mac_x86_64/decompile` | 🟡 source-only some versions | auto-build if missing |
| macOS Apple Silicon | `os/mac_arm_64/decompile` | ❌ | installer auto `make ghidra_opt ARCH_TYPE="-arch arm64"` |

## 3. CI coverage (GitHub Actions)

| Job | runner | Content | Frequency |
| --- | --- | --- | --- |
| `lint-build` | ubuntu-latest | ShellCheck all `.sh` + version consistency + build demo + docs link check | every push/PR |
| `lint-ps` | ubuntu-latest (pwsh) | PowerShell parse + PSScriptAnalyzer (Error/Warning fail) | every push/PR |
| `e2e (linux)` | ubuntu-latest x64 | install.sh + verify.sh (ELF) 9/9 | weekly/manual |
| `e2e (macos)` | macos-latest **arm64** | install-macos.sh + build `mac_arm_64` + verify-macos.sh (Mach-O) 9/9 | weekly/manual |
| `e2e (windows)` | windows-latest **x64** | install.ps1 + verify.ps1 (PE fixture) 9/9 | weekly/manual |
| `fixture-multiarch` | ubuntu-latest | build cross toolchain, export ELF32/AArch64/PE32, assert arch | schedule/manual |
| `docker` / `docker-arm64` | ubuntu / ubuntu-24.04-arm | build image, run verify.sh in container | weekly/manual |

Combinations with no CI run (documented only): **ChromeOS (any form)**, **macOS Intel (macos-13)**, **bare-metal Linux arm64**, **cloud VDI of all kinds**.

## 4. Script quick reference

| System | Install | Verify | Uninstall | Doc |
| --- | --- | --- | --- | --- |
| Linux / WSL2 / Crostini / Linux VDI | `install.sh` | `verify.sh` | `uninstall.sh` | [platform-linux.md](platform-linux.md) (Chinese) |
| Windows x64 | `install.ps1` | `verify.ps1` | `uninstall.ps1` | [platform-windows.md](platform-windows.md) (Chinese) |
| macOS | `install-macos.sh` | `verify-macos.sh` | `uninstall-macos.sh` | [platform-macos.md](platform-macos.md) (Chinese) |
| ChromeOS (Crostini) | `install.sh` in container | `verify.sh` | `uninstall.sh` | [platform-chromeos.md](platform-chromeos.md) (Chinese) |
| Docker (any host) | `Dockerfile` / compose | `verify.sh` in container | remove image | [platform-docker.md](platform-docker.md) (Chinese) |

Shared: `config/versions.env` (single source of versions), `lib/common.sh`/`lib/common.ps1`, `scripts/detect-env.sh`, `scripts/build-ghidra-native.sh`, `scripts/verify-check.js`.

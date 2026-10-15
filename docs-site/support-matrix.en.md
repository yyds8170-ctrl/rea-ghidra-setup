[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/support-matrix/) | English

# Platform × environment support matrix

Summary below. The full "4 OSes × 5 runtimes" status (with known limits and CI matrix links) lives at
[docs/platform-support-matrix.en.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-support-matrix.en.md).

## Summary

| OS / runtime | x86_64 | arm64 / Apple Silicon | Notes |
|---|---|---|---|
| Linux bare metal / VM | ✅ full | ✅ native built on the fly | WSL2 == Linux |
| Windows 10/11 bare metal / VM / VDI | ✅ full | ⚠ via WSL2/CI | per-user, no admin |
| macOS Intel | ✅ full | — | — |
| macOS Apple Silicon | — | ✅ native built on the fly, quarantine stripped | |
| ChromeOS Crostini | ✅ full (x86_64) | ⚠ build native yourself | use the Linux flow inside the container |
| Docker any host | ✅ amd64 image | ✅ arm64 image | non-root, HEALTHCHECK is a file probe |

## Feature matrix (core subcommands)

| Feature | Linux | macOS | Windows | Docker | ChromeOS |
|---|---|---|---|---|---|
| `install` | ✅ | ✅ | ✅ | ✅ (at build) | ✅ (in container) |
| `doctor` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `verify` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mcp` | ✅ | ✅ | ✅ | ⚠ manual in container | ✅ |
| `export` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `batch` | ✅ | ✅ | ✅ (Start-Job) | ✅ | ✅ |
| `self-update` | ✅ | ✅ | ✅ | ⚠ not recommended in container | ✅ |
| `current` / `rollback` | ✅ | ✅ | ✅ (junction) | ⚠ single version | ✅ |
| `fixtures` (cross-compile) | ✅ | ✅ | ⚠ WSL/CI | ✅ | ⚠ needs cross toolchain |
| `walkthrough` | ✅ | ✅ | ⚠ WSL/CI | ✅ | ✅ |

Legend: ✅ first-class · ⚠ conditional / known limits · — N/A.

## References

- Platform-specific install: [install.en.md](install.en.md)
- Troubleshooting: [docs/troubleshooting.en.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/troubleshooting.en.md)
- The CI matrix that actually runs: see the CI badge at the top of the root README.

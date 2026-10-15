[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/faq/) | English

# FAQ

## Do I need admin rights on Windows?

No. The Windows installer extracts per-user into `%LOCALAPPDATA%\Programs`. It does **not** write to `C:\Program Files`, does **not** touch the system PATH, and does **not** add registry Run keys. The only scenario requiring elevation is installing a system-wide JDK to a custom directory; the script detects that, prints a warning, and exits — it never silently elevates.

## Downloads are slow / blocked. What do I do?

```bash
export REA_MIRROR=tsinghua     # or ustc / aliyun
./rea-ghidra install
```

Mirror logic and the source list: [docs/mirrors.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/mirrors.md).

## Fully air-gapped machine — how do I install?

On a connected box, run `bash scripts/prepare-offline.sh` to stage Ghidra/JDK/Node into `offline/`. Copy the whole repo (including `offline/`) onto the air-gapped machine, then `REA_OFFLINE=1 ./rea-ghidra install`. See [docs/offline.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/offline.md).

## Which JDK do I need?

The installer ships and uses **JDK 21** (portable, extracted into `~/tools`; on Windows into `%LOCALAPPDATA%\Programs`). **Do not** point it at a system JDK 17 or older — Ghidra 12.x requires JDK 21+. The installer uses its own extracted JDK and does not mutate `JAVA_HOME`.

## How do I uninstall?

```bash
# Linux / macOS
./uninstall.sh           # macOS: uninstall-macos.sh
# Windows
.\uninstall.ps1
```

Uninstallers only remove artifacts installed by this repo under `~/tools` / `%LOCALAPPDATA%\Programs`. They leave any system JDK or other tools alone.

## Is self-update safe? Will it overwrite my local edits?

- **git working copy**: runs only `git pull --ff-only`. **No merge, no force**. Uncommitted changes are surfaced first and **never auto-stashed/overwritten**.
- **release tarball**: downloads `<tag>.tar.gz` plus a matching `.checksums.txt`; refuses on any sha256 mismatch. Replaced files are backed up to `.self-update-backup-<timestamp>/` for full rollback.
- Local artifacts `offline/`, `examples/fixtures/`, `.git/` are **never touched**.

Always start with `./rea-ghidra self-update --check` to preview before writing.

## Are the three platforms at feature parity?

Core install / doctor / verify / export / batch / mcp behave identically on Linux, macOS and Windows. Differences:

- `fixtures` and `walkthrough` on Windows recommend WSL/CI (cross-arch fixture compilation is not supported natively on Windows);
- native libraries are built on the fly for arm64 Linux and Apple Silicon;
- the full matrix: [support-matrix.md](support-matrix.en.md) and [docs/platform-support-matrix.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-support-matrix.md).

## Compliance & attribution?

This project is licensed under **PolyForm Noncommercial 1.0.0**. Maintainer: 「洋洋」 ([yyds8170-ctrl](https://github.com/yyds8170-ctrl)). It is an **independent third-party** deployment tool — it does not redistribute Ghidra/REA binaries and has no affiliation with the NSA or morluto. Legal text:
[LICENSE](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/LICENSE),
[NOTICE](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/NOTICE),
[TRADEMARKS](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/TRADEMARKS.md).

## More questions?

- Root README FAQ: [README.en.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/README.en.md)
- Troubleshooting: [docs/troubleshooting.en.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/troubleshooting.en.md)
- File an issue: [GitHub Issues](https://github.com/yyds8170-ctrl/rea-ghidra-setup/issues)

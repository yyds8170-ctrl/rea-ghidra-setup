[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/) | English

# rea-ghidra-setup

On a cloud box / Linux server / Windows / macOS, install **REA (Reverse Engineer Anything) + Ghidra 12.1.4 + JDK 21 + portable Node 24** and pass 9 end-to-end checks **in one command**. This repo only ships install/orchestration scripts — it does **not** bundle, modify, or redistribute Ghidra or REA binaries; at runtime they are downloaded from official sources.

??? info "Independent third-party notice"
    This project is an independent third-party deployment/orchestration tool. It is **not affiliated with, endorsed by, sponsored by, or connected to** the NSA, Ghidra, morluto, REA, or their respective rights holders. "Ghidra", "REA" and other names belong to their respective owners and are used for identification only. Upstream copyrights and licenses are retained — see
    [NOTICE](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/NOTICE) and
    [TRADEMARKS](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/TRADEMARKS.md).
    Maintainer: **Yang Yang ([yyds8170-ctrl](https://github.com/yyds8170-ctrl))**.

## Install in 30 seconds

=== "Linux / macOS (bash)"
    ```bash
    git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
    cd rea-ghidra-setup
    ./rea-ghidra install && ./rea-ghidra verify
    ```

=== "Windows (PowerShell)"
    ```powershell
    git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
    cd rea-ghidra-setup
    .\rea-ghidra.ps1 install
    .\rea-ghidra.ps1 verify
    ```

=== "Docker (any host)"
    ```bash
    docker build -t rea-ghidra .
    docker run --rm --entrypoint bash rea-ghidra /opt/rea-ghidra-setup/verify.sh
    ```

## Features

- **Unified entrypoint**: `rea-ghidra` / `rea-ghidra.ps1` collapses install / doctor / verify / mcp / export / batch / self-update / current / rollback into one command.
- **First-class on three OSes**: Linux (x86_64/arm64), Windows 10/11 x64 (user-space, no admin), macOS (Intel / Apple Silicon, native auto-built).
- **Docker / ChromeOS**: multi-arch image build and Crostini walkthrough.
- **Offline fallback**: `prepare-offline` pre-stages Ghidra/JDK/Node into `offline/` for air-gapped installs.
- **Checksum enforcement**: every downloaded artifact is sha256-verified; self-update only accepts release tarballs with a matching `.checksums.txt`.
- **Cached batch**: `batch` analyzes many binaries in parallel, content-addressed snapshot cache, resumable.
- **Static export**: `export` uses Ghidra's native `analyzeHeadless` to emit functions/strings/symbols/calls/decompiled JSON — no REA/Node required.
- **Real case library**: 5 worked examples (crackme / license key / tiered pricing / switch dispatch / export pipeline) whose assertions rely on strings and constants, never on absolute addresses.
- **Structured report generator**: Markdown + inline-CSS HTML dual output with metadata / segments / security flags / imports-exports / strings / xrefs / decompiled summary.
- **China mirrors**: automatic detection and switching of Ghidra/JDK mirrors, lockable via env var.

## Next steps

- Platform-specific install details: [Installation](install.en.md)
- Full subcommand table: [Usage](usage.en.md)
- Case library: [Real cases](cases.en.md)
- Report generator: [Structured reports](report.en.md)
- FAQ: [FAQ](faq.en.md)
- Platform × environment matrix: [Support matrix](support-matrix.en.md)

Source and issue tracker: [GitHub repo](https://github.com/yyds8170-ctrl/rea-ghidra-setup). The full root README (with screenshots, changelog, tree) is at
[README.en.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/README.en.md).

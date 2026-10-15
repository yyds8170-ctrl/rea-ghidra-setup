[简体中文](https://yyds8170-ctrl.github.io/rea-ghidra-setup/install/) | English

# Installation guide

> Not sure about your environment? Run `bash scripts/detect-env.sh` first (on Windows: `pwsh scripts/detect-env.ps1`). It detects OS / arch / runtime and recommends the right command.

## Which one?

| Environment | Install | Verify | Detailed docs |
|---|---|---|---|
| Linux bare metal / VM / WSL2 / cloud box | `./rea-ghidra install` | `./rea-ghidra verify` | [platform-linux.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-linux.md) |
| macOS (Intel / Apple Silicon) | `./rea-ghidra install` | `./rea-ghidra verify` | [platform-macos.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-macos.md) |
| Windows 10/11 x64 | `.\rea-ghidra.ps1 install` | `.\rea-ghidra.ps1 verify` | [platform-windows.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-windows.md) |
| ChromeOS (Crostini) | Use the Linux flow inside the container | Same as Linux | [platform-chromeos.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-chromeos.md) |
| Docker (any host) | `docker build -t rea-ghidra .` | `verify.sh` inside the container | [platform-docker.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/platform-docker.md) |

## Most-used commands

```bash
# Linux / macOS: one-shot install + verify
./rea-ghidra install
./rea-ghidra verify
./rea-ghidra doctor        # read-only environment self-check
```

```powershell
# Windows: no admin required, extracts to %LOCALAPPDATA%
.\rea-ghidra.ps1 install
.\rea-ghidra.ps1 verify
```

```bash
# Docker: multi-arch build (amd64 / arm64)
docker build -t rea-ghidra .
docker run --rm --entrypoint bash rea-ghidra /opt/rea-ghidra-setup/verify.sh
# or via docker-compose
docker compose run --rm --entrypoint bash rea /opt/rea-ghidra-setup/verify.sh
```

## Offline / air-gapped

On a connected box, pre-stage the offline bundle:

```bash
bash scripts/prepare-offline.sh        # pulls Ghidra/JDK/Node into offline/
# copy the whole repo (with offline/) to the air-gapped machine, then:
REA_OFFLINE=1 ./rea-ghidra install
```

See [docs/offline.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/offline.md).

## China mirrors

If downloads are slow or blocked:

```bash
export REA_MIRROR=tsinghua     # or ustc / aliyun
./rea-ghidra install
```

Mirror logic and the list of available sources: [docs/mirrors.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/mirrors.md).

## Uninstall

```bash
# Linux / macOS
./uninstall.sh           # or uninstall-macos.sh
# Windows
.\uninstall.ps1
```

Uninstallers only remove artifacts installed by this repo under `~/tools` (Windows: `%LOCALAPPDATA%\Programs`). They never touch system JDKs.

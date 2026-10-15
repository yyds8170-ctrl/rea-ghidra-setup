[English](mirrors.en.md) | [简体中文](mirrors.md)

# China mirror acceleration (REA_MIRROR)

On mainland-China networks, nodejs.org, api.adoptium.net and GitHub Releases are often slow or unstable. Since v2.4 the `REA_MIRROR` switch accelerates downloads. It **only changes the source of downloads and npm packages, not the installed result** — files fetched from mirrors must still pass authoritative checksum verification before landing.

## One-liner

```bash
# Linux / macOS: mirrors first, official as fallback
REA_MIRROR=cn bash install.sh
```

```powershell
# Windows PowerShell
$env:REA_MIRROR='cn'; .\install.ps1
```

Default is `auto`: a ~5-second short probe to official nodejs.org; reachable → official order, timeout → mirrors. On GitHub Actions (overseas) auto picks official first, so it **does not degrade overseas/CI**.

## Modes

| `REA_MIRROR` | Behavior |
| --- | --- |
| `auto` (default) | short probe → official first on reach, mirrors on timeout |
| `cn` | mirrors first, official always kept as last resort |
| `global` | official sources only (v2.3 order, for overseas/CI) |

| Variable | Effect | Default |
| --- | --- | --- |
| `REA_MIRROR` | `auto` / `cn` / `global` | `auto` |
| `REA_GITHUB_PROXIES` | Ghidra etc. GitHub release proxy prefix list; `none` = official only | built-in `https://gh-proxy.com/` |
| `REA_DL_RETRIES` / `REA_DL_CONNECT_TIMEOUT` / `REA_DL_MAX_TIME` | download retry/timeout | `5` / `15` / `1800` |

## Safety: mirrors must still pass official checksums

A mirror is "a faster pipe", not "different trusted content". Files from any source (proxy/mirror included):

- **Node**: must match the corresponding entry in official `SHASUMS256.txt`;
- **JDK**: must match `package.checksum` in the Adoptium assets JSON;
- **Ghidra**: must match the `digest` from the GitHub release API.

Mismatch → delete and abort. If the authoritative checksum source itself is unreachable (offline/rate-limited), it keeps the v2.2 "warn-and-allow" semantics with a clear notice, and **never silently passes using a checksum that shares the mirror's origin**.

## Connectivity self-check

```bash
bash scripts/check-mirrors.sh           # see OK/FAIL per source in the current mode
REA_MIRROR=cn bash scripts/check-mirrors.sh
```

`doctor.sh` prints the current mirror mode (cn = WARN notice, non-blocking).

> Sources were measured on 2026-10-15 for locked Node v24.22.0: npmmirror and Huawei Cloud reachable; TUNA `nodejs-release` 404 for that version and is intentionally omitted. JDK uses Tsinghua TUNA (verified Range 206 / Content-Length). Details in [mirrors.md](mirrors.md) (Chinese).

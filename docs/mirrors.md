# 国内镜像加速（REA_MIRROR）

中国大陆网络访问 nodejs.org、api.adoptium.net、GitHub Release 往往慢或不稳。
v2.4 起提供镜像加速开关 `REA_MIRROR`，**只影响下载与 npm 包来源，不改变安装结果**——
镜像下载的文件仍必须通过权威校验和强校验后才落地。

## 一句话用法

```bash
# Linux / macOS：镜像优先，官方兜底
REA_MIRROR=cn bash install.sh
```

```powershell
# Windows PowerShell
$env:REA_MIRROR='cn'; .\install.ps1
```

默认值是 `auto`：对官方 nodejs.org 做一次约 5 秒的短连接探测，可达就按官方顺序，
超时才切镜像。GitHub Actions（海外）上 auto 会判定为官方优先，**不会劣化海外/CI**。

## 模式

| `REA_MIRROR` | 行为 |
| --- | --- |
| `auto`（默认） | 短探测官方可达→官方优先；超时→镜像优先 |
| `cn` | 镜像优先，官方源始终保留为最后兜底 |
| `global` | 仅官方源（保持 v2.3 顺序，海外/CI 用） |

## 接入的镜像（2026-10-15 实测）

### Node（便携运行时）
| 源 | 路径前缀 | 状态 |
| --- | --- | --- |
| npmmirror | `https://registry.npmmirror.com/-/binary/node/v<ver>/` | ✓ 可用，同目录带 `SHASUMS256.txt` |
| 华为云 | `https://repo.huaweicloud.com/nodejs/v<ver>/` | ✓ 可用 |
| nodejs.org | `https://nodejs.org/dist/v<ver>/` | 官方 |

> TUNA `nodejs-release` 当时未镜像 v22.19.0（目录 404），故未写入；以后版本若补齐可再加。

### JDK（Temurin 21）
| 源 | 路径 | 状态 |
| --- | --- | --- |
| 清华大学 TUNA | `https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/<arch>/<os>/<文件名>` | ✓ Range 206，Content-Length 与 Adoptium `package.size` 一致 |
| Adoptium/GitHub | `api.adoptium.net` → GitHub release | 官方 |

文件名与 checksum 来自 Adoptium v3 assets JSON（`package.link`/`package.name`/`package.checksum`/`package.size`）。
华为云 adoptium 路径当前不可用（错误页），故 JDK 镜像用 TUNA。

### npm 包（rea-agents）
cn 模式下 npx / 全局安装走 `https://registry.npmmirror.com`，
通过环境变量 `npm_config_registry` **仅本次安装/验证进程生效，不写入用户全局 .npmrc**。

### Ghidra
Ghidra 大文件仍走 v2.3 的「官方直连 + GitHub 代理池」（`REA_GITHUB_PROXIES`），
本版不额外加国内镜像。

## 安全：镜像也必须过官方校验和

镜像只是“换个更快的水管”，不是“换一份可信任的内容”。任何来源（含代理/镜像）拿到的文件：

- **Node**：必须与 nodejs.org 官方 `SHASUMS256.txt` 对应项一致；
- **JDK**：必须与 Adoptium assets JSON 的 `package.checksum` 一致；
- **Ghidra**：必须与 GitHub release API 的 `digest` 一致。

不匹配即删除并中止。若权威校验和源本身不可达（离线/限流），维持 v2.2 既有“警告放行”
语义并明确提示，**绝不把“与镜像同源的 checksum”当作可信而静默通过**。

## 连通性自检

```bash
bash scripts/check-mirrors.sh           # 看当前模式下各源 OK/FAIL
REA_MIRROR=cn bash scripts/check-mirrors.sh
```

`doctor.sh` 会打印当前镜像模式（cn 为 WARN 提示，不阻断）。

## 相关环境变量

| 变量 | 作用 | 默认 |
| --- | --- | --- |
| `REA_MIRROR` | `auto` / `cn` / `global` | `auto` |
| `REA_GITHUB_PROXIES` | Ghidra 等 GitHub release 代理前缀列表；`none` 只走官方 | 内置 `https://gh-proxy.com/` |
| `REA_DL_RETRIES` / `REA_DL_CONNECT_TIMEOUT` / `REA_DL_MAX_TIME` | 下载内核重试/超时 | `5` / `15` / `1800` |

# 更新日志

本项目格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

文档中文；未列出的内部整理不单独记录。

## [2.5.0] - 2026-10-15

### Added
- 三平台安装器统一非交互命令行参数（bash 新增共享解析器 `lib/args.sh`，由 `common.sh` 引入，install.sh/install-macos.sh 复用；PowerShell 在 install.ps1/uninstall.ps1 用 `param()` 等价实现）：
  `--help/-h`、`--dry-run`、`--yes/-y/--non-interactive`、`--prefix/--tools-dir`、`--mirror auto|cn|global`、`--skip-node`、`--no-native`、`--provider`、`--offline-dir`、`--ghidra-version/--node-version/--rea-version`。
- `--dry-run`：解析并打印「将要执行的安装计划」（平台/环境/架构、有效镜像模式、TOOLS_DIR、各组件版本、provider、是否离线、是否跳过 Node/native、预计磁盘、步骤预览），**不做任何下载/解压/写 rc/构建**，退出 0。
- 参数解析在 `load_versions` 与任何平台专属/下载动作之前：`--help/--dry-run` 在 CI 的 ubuntu 上跑 install-macos.sh、或在任意机器跑 install.ps1 都能提前退出，不触碰 Darwin/Windows 专属命令。
- 新增 `SKIP_NATIVE` 开关（`--no-native`），跳过 native decompiler 自动源码构建；install 结尾按平台给出「下一步」（source rc / verify / doctor / cn 镜像提示）。
- CI：lint-build 加 CLI 参数自检（help/dry-run 字段、未知参数退出 2、覆盖值出现在 dry-run）；lint-ps 加 pwsh `-DryRun/-Help/未知参数` 自检。

### Changed
- 默认（不带参数）行为与历史完全一致；环境变量覆盖（TOOLS_DIR/SKIP_NODE/GHIDRA_VERSION 等）仍优先、继续可用。
- 修复：`install.ps1 -DryRun`/`-Help` 在 CI 的 ubuntu pwsh 下因 `$env:PROCESSOR_ARCHITECTURE`/`$env:USERPROFILE` 为空而崩溃——`Get-WindowsArch` 回退 `RuntimeInformation.OSArchitecture`，默认 ToolsDir 回退 `$HOME`/`GetFolderPath('UserProfile')`，保证 DryRun 跨平台安全且真实 Windows 路径行为不变。
- `install.ps1`/`uninstall.ps1` 的 `param()` 加 `[CmdletBinding()]`：未知命令行参数（如 `-NoSuchFlag`）会被参数绑定**直接拒绝（退出 1）且不执行安装体**，而非被普通脚本静默吞进 `$args` 继续执行。
- 修复 macOS e2e 回归：安装器结尾的镜像提示行原为 `[ "$(rea_mode)" = "cn" ] && echo …`，在 `global` 模式下条件为假、`&&` 短路返回 1，而它恰是 `install-macos.sh` 的最后一条语句，导致整个安装脚本退出码为 1（安装其实已成功）。改为 `if …; then echo …; fi`（条件为假时 `if` 返回 0），`install.sh` 同步加固。

### 本机实测（2026-10-15，Ubuntu 22.04 x86_64）
- `shellcheck -x` 零告警；`bash -n` 全部通过；ci.yml 经 python yaml 解析；`scripts/check-versions.sh` 通过。
- `bash install.sh --help`/`--dry-run` 退出 0；`--dry-run --prefix /tmp/x --mirror cn --rea-version 9.9.9 --skip-node --no-native --provider ghidra` 正确打印覆盖值；`bash install.sh --no-such-flag` 退出 2；`bash install-macos.sh --dry-run` 在 ubuntu 上正常退出。
- `bash install.sh --yes` 幂等（本机已装组件全部「已存在/跳过」）；随后 verify.sh 仍 9/9。
- PS 路径在本机便携 pwsh 7.6 下实跑：`install.ps1 -Help/-DryRun` 退出 0、`uninstall.ps1 -Help` 退出 0、`-NoSuchFlag` 被参数绑定拒绝（退出 1）且不执行安装体；7 个 `.ps1` 语法解析通过、PSScriptAnalyzer 无 Error/Warning；并由 CI lint-ps 步骤再次把关。

## [2.4.0] - 2026-10-15

### Added
- 新增镜像模式开关 `REA_MIRROR=auto|cn|global`（bash `lib/mirrors.sh` + PowerShell `lib/common.ps1` 等价）：
  `global` 仅官方；`cn` 镜像优先、官方兜底；`auto`（默认）对官方 nodejs.org 做约 5s 短连接探测，
  可达→官方优先，超时→镜像，保证 GitHub Actions 海外不劣化。
- Node 镜像（cn 模式）：npmmirror（`registry.npmmirror.com/-/binary/node/v<ver>/`，同目录带 SHASUMS256.txt）
  + 华为云（`repo.huaweicloud.com/nodejs/v<ver>/`），接入 v2.3 多源 `download`/`Save-RemoteFile` 候选列表。
- JDK（Temurin）镜像：先从 Adoptium assets JSON 取 `package.link/name/checksum/size`，
  TUNA（`mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/<arch>/<os>/<文件名>`）在前、GitHub release 官方兜底；
  PS 等价 `Get-JdkAssetInfo`/`Get-JdkMirrorUrls`。
- npm 镜像：cn 模式下 npx/全局安装经 `npm_config_registry=https://registry.npmmirror.com` 拉取 rea-agents，
  仅本次进程生效，不改用户全局 `.npmrc`；install/verify 共用统一逻辑。
- 新增 `scripts/check-mirrors.sh`（各源 Range 探测 OK/FAIL，镜像可选源不可达不阻断）；
  `doctor.sh` 增加镜像模式提示（cn 为 WARN，不阻断）；新增 `docs/mirrors.md`。

### Changed
- `fetch_artifact`（bash）与 `Get-VerifiedArtifact`（PS）对 node/jdk 按镜像模式排候选 URL；
  **校验和逻辑不变，仍在多源下载之后强校验**（Node 官方 SHASUMS256 / Adoptium JSON / GitHub digest）。
- 镜像只是候选，官方源始终保留为最终回退；不硬编码代理。

### 本机实测（2026-10-15，Ubuntu 22.04 x86_64）
- `shellcheck -x` 零告警；`bash -n` 全部通过；`scripts/check-versions.sh` 通过。
- cn 模式经 npmmirror 真实下载 Node 22.19.0 并对官方 SHASUMS256 校验一致（tarball 可解包）；
  JDK TUNA Range 206 且 Content-Length（207473347）== Adoptium `package.size`。
- `scripts/check-mirrors.sh` 全源 OK；`REA_MIRROR=cn verify.sh` 与 `REA_MIRROR=global verify.sh` 均 9/9。
- 残留：TUNA nodejs-release 未镜像 v22.19.0（404，未写入）；华为云 adoptium JDK 路径当前不可用（JDK 镜像用 TUNA）。

## [2.3.0] - 2026-10-15

### Added
- 新增统一、健壮的「下载」内核：bash `lib/download.sh`（`download` / `github_proxy_urls`）与 PowerShell `lib/common.ps1`（`Save-RemoteFile` / `Get-GithubProxyUrls`）等价实现：
  - 指数退避重试（默认 5 次，`REA_DL_RETRIES` 可配）；连接超时（`REA_DL_CONNECT_TIMEOUT`，默认 15s）与总超时（`REA_DL_MAX_TIME`，默认 1800s，大文件可放宽）。
  - 断点续传：bash 优先 `curl -fL -C -`，无 curl 回退 `wget -c`；PowerShell 优先显式 `curl.exe -fL -C -`（PS 5.1 中 `curl` 是 `Invoke-WebRequest` 别名，必须写 `curl.exe`），回退 `Start-BitsTransfer`（自带续传/后台重试），再回退 `Invoke-WebRequest`。对「本地临时文件其实已下完」触发的 HTTP 416（`--fail` 下 curl 退出码 22）通过 Range 探测比对远端字节数判定为成功。
  - 先下载到 `<目标>.part`，完成后原子 `mv` 到目标，避免半截文件被当成成功；多源 failover，前一个源连接失败/非 2xx 才换下一个。
  - bash 兼容 macOS 自带 bash 3.2（仅普通索引数组，无关联数组/mapfile/`|&`）；`--retry-connrefused`（curl 7.52+）、`--retry-all-errors`（7.71+）先用 `curl --help all` 探测，老 curl 不支持就不加。
  - 规范透传代理：不硬编码；自动把大写 `HTTP_PROXY/HTTPS_PROXY/NO_PROXY` 补成小写 `http_proxy/https_proxy/no_proxy`（curl 默认只认小写）。
- Ghidra 大文件（约 400MB）走「GitHub 官方直连 + 代理池」多源回退：内置 `https://gh-proxy.com/` 前缀形式 `<代理><原始 github url>`；可用环境变量 `REA_GITHUB_PROXIES` 追加/覆盖（逗号/分号/空格分隔），设为 `none` 或空则只走官方。代理只用于公开 release，且产物仍必须通过来自 GitHub API 的 SHA-256 digest 强校验。
- 新增 `scripts/selftest-download.sh`：本地 Range 感知 http 服务，离线验证下载内核三场景（主源坏→第二源成功且哈希正确；全坏源→非零退出且无半截文件；预置等大 `.part`→416 当成功落地）。

### Changed
- 所有交付物下载改用新内核：`lib/checksums.sh` 的 `fetch_artifact`、`lib/common.sh` 的 `install_node_portable`、`scripts/prepare-offline.sh`、以及 PowerShell `lib/checksums.ps1` 的 `Get-VerifiedArtifact`、`scripts/prepare-offline.ps1`，替换原先的裸 `curl`。
- **校验和逻辑保持不变，且在多源下载之后强校验**：任何来源（含代理）拿到的文件都要过 SHA-256（Node 官方 SHASUMS256 / Adoptium `package.checksum` / GitHub release digest），不匹配即删除并失败。
- Node / JDK 本版仍只走官方源（国内镜像在后续版本，本版不提前做）。

### Fixed
- 避免下载中断时在目标路径留下半截文件被当作成功安装。

### 本机实测（2026-10-15，Ubuntu 22.04 x86_64）
- `shellcheck -x *.sh lib/*.sh scripts/*.sh` 零告警；全部 bash `bash -n` 通过；`scripts/check-versions.sh` 通过。
- `scripts/selftest-download.sh` 三场景全部 PASS。
- 真实下载 Node 22.19.0 tarball 并通过官方 SHASUMS256 强校验；`scripts/selfcheck-checksums.sh` 通过。
- Ghidra 候选 URL 生成正确；官方直连 Range 探测返回 206，代理前缀不可达时优雅回退官方。
- `verify.sh` 仍 **9/9**（断言强度未改）。

## [2.2.0] - 2026-10-14
- **Added** 下载物 SHA-256 校验：`lib/checksums.sh` / `lib/checksums.ps1`，三平台对 JDK（Adoptium JSON）、Node（SHASUMS256）、Ghidra（GitHub release digest）逐一强校验，不匹配即删除中止。
- **Added** 离线安装：`scripts/prepare-offline.sh` / `.ps1` 在有网机器生成已校验离线包（JDK+Node+Ghidra+rea-agents.tgz+`SHA256SUMS.txt`），目标机 `OFFLINE_DIR=` 离线安装。
- **Added** `docs/offline.md`、`docs/troubleshooting.md`；`.github/workflows/release.yml` 标签发版。

## [2.1.0] - 2026-10-14
- **Added** 跨平台只读诊断 `scripts/doctor.sh` / `doctor.ps1`（Node 门禁、JDK21、analyzeHeadless、对应架构 native、macOS Gatekeeper、`!`/`^` 路径禁忌、磁盘/堆内存）。
- **Added** `docs/configuration.md`（环境变量、MCP 接入、代理与镜像）；CI 新增 doctor 步骤。

## [2.0.0] - 2026-10-14
- **Changed** `docs/platform-support-matrix.md` 由「规划」定稿为实测状态；Docker arm64 由受限升级为支持（原生 arm runner 构建 native 并容器内 verify 9/9）。
- **Added** README「我该用哪个？」快速选择决策表 + `scripts/detect-env.sh`。

## [1.9.0] - 2026-10-14
- **Added** Docker 多架构（buildx `TARGETARCH` 选 JDK/Node，arm64 镜像内自动 `make ghidra_opt` 构建 `linux_arm_64` native）；`docker-compose.yml`；`docs/platform-docker.md`；CI `docker-arm64` 作业。

## [1.8.0] - 2026-10-14
- **Changed** 跨平台 CI 合并为 matrix（linux/macos/windows，`fail-fast:false`）；抽出 `scripts/verify-check.js` 统一三端 analyze/decompile/count 断言；三端反编译前用 `rea search --kind procedures` 解析真实函数名。三端 verify 均 9/9。

## [1.7.0] - 2026-10-14
- **Added** ChromeOS 文档化支持（仅 Crostini）；`scripts/detect-env.sh`；`lib/common.sh` 运行环境识别（`is_docker`/`env_token`/`env_label`）。

## [1.6.0] - 2026-10-14
- **Added** Windows 支持（PowerShell）：`install.ps1`/`verify.ps1`/`uninstall.ps1` + `lib/common.ps1`，全程用户态免管理员；仓库自带预编译 PE fixture；CI `lint-ps`（PSScriptAnalyzer）与 `e2e-windows`。
- **Fixed** macOS bash 3.2 多字节 unbound：变量后紧跟中文一律加花括号。

## [1.5.0] - 2026-10-14
- **Added** macOS 支持：`install-macos.sh`/`verify-macos.sh`/`uninstall-macos.sh`（Intel + Apple Silicon）；适配 Temurin JDK 布局、`xattr` 解除 Gatekeeper、自动构建缺失 native；CI `e2e-macos`。

## [1.4.0] - 2026-10-14
- **Added** Linux 安装加固：启动识别 OS/运行环境/架构；支持 arm64（自动构建 `linux_arm_64` native）；便携 Node 22（版本门禁 `^22.19||^24.11||>=26`，`SKIP_NODE=1` 跳过）；`docs/platform-linux.md`。

## [1.3.0] - 2026-10-14
- **Added** 版本号单一事实源 `config/versions.env`；`lib/common.sh` 共用函数；`scripts/check-versions.sh`；`Dockerfile` 改读 versions.env；`docs/` 文档目录与 `VERSION` 文件。

## [1.2.0] - 2026-10-14
- **Added** Docker 支持（`Dockerfile` + `.dockerignore`）；原生 Ghidra 批量反编译 `scripts/DecompileAll.java` + `ghidra-decompile.sh`；`verify.sh` 增加 `calc_discount` 断言；`CONTRIBUTING.md`/`SECURITY.md`；Dependabot。

## [1.1.0] - 2026-10-14
- **Added** `verify.sh` 端到端自检；`uninstall.sh`；`examples/Makefile`；GitHub Actions CI（ShellCheck+编译每次，完整 e2e 每周/手动）；安装磁盘空间检查与 GITHUB_ENV/PATH 适配。

## [1.0.0] - 2026-10
- 首次发布：云电脑一键部署 Temurin JDK21 + Ghidra 12.1.4，含逆向工程技能与实测。

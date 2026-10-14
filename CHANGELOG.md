# 更新日志

本项目格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

文档中文；未列出的内部整理不单独记录。

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

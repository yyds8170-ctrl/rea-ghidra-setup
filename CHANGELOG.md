# 更新日志

本项目格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

文档中文；未列出的内部整理不单独记录。

## [4.0.1] - 2026-10-15（首个全绿收官补丁）

### Fixed（全量 CI 真实跑通后修复）
- `scripts/run-cases.ps1`：两处 PowerShell 解析错误（`$stem:` 被当成作用域分隔符，改为 `${stem}:`）；此前该文件未经 pwsh 解析验证。
- `scripts/run-cases.sh` / `run-cases.ps1`：案例 05 的 libc 导入断言改为**跨平台**——Mach-O（macOS）给 C 符号加前导下划线（`_printf`），归一化（去命名空间末段 + 去前导下划线）后比较。修复 macOS e2e 案例 05 断言失败。
- `.github/workflows/pages.yml`：移除 `setup-python` 的 `cache: pip`（无 requirements/lockfile，缓存找不到文件会失败）。
- GitHub Pages 已通过 API 启用（build_type=workflow），无需手动在 Settings 切换。

### Verified（本机 + CI）
- 本机装便携 pwsh 7.5.2：12 个 .ps1 全部解析通过、PSScriptAnalyzer 0 Error（Warning 为既有样式、非阻塞）；bash 版 run-cases 复跑 10/10 通过。
- 全量 CI（workflow_dispatch）：lint-build、e2e linux/windows、docker、docker-arm64、fixture-multiarch、checksum 均通过；v4.0.0 上失败的 lint-ps 与 e2e macos 由本补丁修复。

### Notes
- PowerShell 脚本仅支持 Windows（JDK 检测按 `bin\java.exe`）；Linux/macOS 用 bash 脚本，不在 Linux 上跑 ps1。

## [4.0.0] - 2026-10-15（收官版本 / first complete release）

> 里程碑：在 v3.2 基础上，经多轮全球检索与真实端到端验证，补齐合规署名、报告生成、案例库、
> 容器加固、双语文档站与分发渠道，达到"当前无明确优化空间"的完整形态。

### Added（分发渠道）
- `packaging/`：Homebrew 个人 tap formula（`packaging/homebrew/rea-ghidra.rb`）、Scoop 个人 bucket manifest（`packaging/scoop/rea-ghidra.json`），以及中英 `packaging/README.md`（含发布步骤、sha256 计算命令、"需新建独立 tap/bucket 仓库、未擅自创建"的诚实说明，以及不做 npm 包装器的理由）。
- README（中英）顶部 30 秒快速开始新增单行命令：`curl -fsSL .../install.sh | bash` 与 `irm .../install.ps1 | iex`，并附审阅提示与 packaging 链接。

### Changed（支持矩阵）
- `docs/platform-support-matrix.md`：零节新增 v3.4–v4.0 能力清单（报告/案例/benchmark/非 root/自愈/文档站/分发）；CI 覆盖表补全 lint-build 案例编译、lint-ps 仅 Error 判失败、e2e 加 run-cases/report，并新增 checksum / fixture-multiarch / pages 三行。

### 收官全链路检查（本机实测）
- ShellCheck 全量、bash3.2 非 ASCII 紧邻、`mkdocs build --strict`（0 警告）、文档死链（48 md / 292 相对链接 + 48 个绝对 blob 链接全有效）、workflow YAML 解析、版本一致性、旧版本残留 grep 均通过。
- CLI 自检：`version`/`help` 正常、未知子命令退出码 2；报告管线在 `examples/demo` 复跑成功（12 产物，captures secret_check 1337/0x539、9000/0x2328、calc_discount 50/0x32）。
- 真实案例 10/10 二进制（5 案例 × 带符号/strip）断言全过。

### 仍做不到 / 需维护者操作（诚实列出）
- 发布 Homebrew tap / Scoop bucket 需在主仓库外新建两个独立仓库，受"未授权不动其他仓库"约束未创建，资产已就绪。
- 首次 GitHub Pages 需在 Settings → Pages → Source 选 GitHub Actions。
- Windows/macOS/Docker e2e 仅 GitHub Actions 可跑（本机无 docker/pwsh）；Ghidra headless 不解析 GNU_STACK/RELRO，报告已注明需 readelf 复核。

## [3.6.0] - 2026-10-15

### Added（双语文档站）
- `docs-site/`：基于 mkdocs-material 的双语（中/英）文档站，7 个内容页 ×2 语言 = 14 页 + 404，含开始/安装/使用/案例/报告/支持矩阵/FAQ；带导航 tabs、明暗主题、语言切换、代码复制、搜索（中英）。
- `mkdocs.yml`：独立 `docs_dir: docs-site`（与仓库原有 `docs/` 隔离）；用 `mkdocs-static-i18n` 1.3.x 的 `docs_structure: suffix` + `reconfigure_material/search` 配置（本机构建按真实插件版本校准，非旧键）；页脚 `copyright` 含署名与 NOTICE/TRADEMARKS 链接及无隶属声明。
- `.github/workflows/pages.yml`：用官方 Pages 动作（configure-pages@v5 / upload-pages-artifact@v4 / deploy-pages@v4）部署，仅 main / v* tag / 手动触发，PR 不部署；构建走 `mkdocs build --strict`。

### Fixed（文档站内容对齐）
- 修正 Docker 快捷命令（镜像 ENTRYPOINT 为 `rea`，须 `--entrypoint bash .../verify.sh`）：docs-site 首页/安装页中英共 4 处；compose 改为 `run` 而非 `up`。
- 案例页与报告页对齐真实脚本：`run-cases.sh`、`ghidra-report.sh <bin> --out --format`，并补齐 5 个案例的真实常量与断言原理；校验全部 48 个 `blob/main` 绝对链接均指向现有文件。

### 前置条件（需手动）
- 首次部署需在仓库 Settings → Pages → Source 选择 **GitHub Actions**；之后推 main 即自动发布到 `https://yyds8170-ctrl.github.io/rea-ghidra-setup/`。

### 本机实测
- `mkdocs build --strict` 干净（0 WARNING/ERROR，MkDocs 2.0 横幅为上游预告非错误）；首页经无头浏览器截图检查；docs-site 未引入新的相对死链（外链为绝对 GitHub URL）。

## [3.5.0] - 2026-10-15

### Security（容器加固）
- `Dockerfile` 改为以**非 root 用户**运行（固定 uid/gid 1001，可写 HOME=/home/rea、工作目录 /workspace）；仓库副本 `/opt/rea-ghidra-setup` chown 给 1001，使容器内自检可在其中编译 examples。
- 新增关键文件存在性 `HEALTHCHECK`（命令行工具、无端口，故不伪装 HTTP 探针）；新增 OCI 标准标签（title/description/url/source/licenses=PolyForm-Noncommercial-1.0.0/vendor）。
- 构建期自检确认 analyzeHeadless、rea 与对应架构 native decompiler 就位。

### Added（路径健壮性 / 自愈）
- `ghidra-report.sh`：实测发现 Ghidra headless `checkValidFilename` 拒绝**非 ASCII 文件名**（空格与非 ASCII 目录均正常）。新增自愈——文件名含非 ASCII 时自动复制为 ASCII 临时名导入，报告仍记录原始路径；分别用「纯空格路径 / 非 ASCII 目录 / 非 ASCII 文件名」三类真实路径验证。

### Added（性能基准）
- `scripts/benchmark.sh`：对同一目标重复运行报告管线（默认 3 次），测量墙钟耗时并解析 Ghidra 分析阶段 `Total Time`，输出 min/median/max 到 `benchmark.md`/`benchmark.json`。本机实测 examples/demo：墙钟 min/median/max=24.99/25.23/25.43s，分析阶段稳定 4s。

### Changed（文档）
- `docs/platform-docker.md`：新增「非 root 安全加固与挂载卷权限」（`--user $(id -u):$(id -g)` 解决挂载目录写权限、只读 rootfs 处理、HEALTHCHECK 说明）；`docker-compose.yml` 补充 PUID/PGID 映射的可选配置。

### 核实与说明
- 核对 Ghidra 12.1.4 的 `analyzeHeadless`/`launch.sh`：`GHIDRA_HEADLESS_MAXMEM` 为脚本原生支持的堆变量（默认 2G），无需额外映射。
- 容器非 root 行为需在 docker CI（`docker`/`docker-arm64` 作业）真实跑 `verify.sh` 确认；本机无 docker，依赖 GitHub Actions。

### 本机实测
- shellcheck -x 0（含 benchmark）、bash -n；三类特殊路径报告/导出真实跑通；benchmark 3 次数据一致；Dockerfile 语法与变量经逐行审查（镜像构建在 GHA 验证）。

## [3.4.0] - 2026-10-15

### Added（结构化逆向报告生成器）
- `scripts/ghidra/ExportReport.java`：单次 headless 自动分析后，一次性产出 `meta/functions/strings/symbols/calls/decompiled` + `imports/exports/constants/xrefs` 共 10 类 JSON，并汇总 `report.md`（10 节）与自包含 `report.html`（内联 CSS、无 CDN/JS，可离线分发）。
- `scripts/ghidra-report.sh`：定位 Ghidra/JDK（可用 `GHIDRA_INSTALL_DIR`/`JAVA_HOME` 覆盖），传 outDir/目标路径，不依赖 REA/Node；支持 `--format md|html|both|json`，结束前校验报告完整性。

### Added（端到端真实案例库）
- `examples/cases/`：5 个难度递进的真实案例，每个含 C 源码、Makefile 与中英 README（业务背景、预期常量、断言原理）：
  - 01-crackme-password（strcmp 口令 `S3cr3t-2026`、`ACCESS GRANTED`）
  - 02-license-key（异或 `0x5A`、求和目标 `0x1B7`=439，正确 key `A6868`）
  - 03-tiered-pricing（阈值 100/10、满减常量 `0x32`=50）
  - 04-switch-dispatch（jumptable，do_login/do_buy/do_about/do_exit）
  - 05-export-flow（完整导出管线，libc 导入 printf/strlen/strcmp/snprintf）
- `scripts/run-cases.sh` / `scripts/run-cases.ps1`：编译 5 案例（带符号 + stripped 共 10 二进制），对每个跑真实 Ghidra 导出并用 python 逐项断言【字符串/函数名/调用边/反编译常量】，任一失败退出非 0。

### Changed（CI）
- `lint-build`：新增「编译端到端案例库」；`e2e` Linux 新增 `run-cases.sh` 全量断言与 `ghidra-report.sh` 报告断言（校验 md/html/JSON 齐全且关键字符串命中）；`e2e` macOS 同样真实跑 `run-cases.sh`，验证跨平台 Ghidra 行为。

### Fixed（真实编译驱动，未凭记忆）
- 首次真实编译抓到并修复 3 处 API 误用：`getExternalLocations(lib)` 返回 `ExternalLocationIterator`（改为 hasNext/next 循环）；`ExternalLocation` 无 `getOrdinal()`（移除该字段，地址列替代）；`Instruction` 无 `getScalarLengths()`（改用 `getNumOperands/getOperandType + OperandType.isScalar + getScalar()`）。

### 本机实测
- 报告生成器在 `examples/demo` 真跑通：constants 捕获 secret_check 1337/0x539、9000/0x2328，calc_discount 50/0x32；HTML 经无头浏览器截图检查、标签平衡、无外链。案例库独立干净重跑 10/10 二进制全部 PASS、exit 0。shellcheck -x 0、bash -n、bash3.2 非 ASCII 红线 0；全部 workflow YAML 解析过。

## [3.3.0] - 2026-10-15

### Fixed（合规）
- 修复 `LICENSE` 中 PolyForm Noncommercial 的模板占位符「Copyright Yoyodyne, Inc. (http://example.com)」，替换为本项目真实版权人；文末新增 Licensor 节与规范 Required Notice：`Copyright (c) 2026 洋洋 (https://github.com/yyds8170-ctrl/rea-ghidra-setup)`。已全文检索确认无 Yoyodyne / example.com 等占位残留。

### Added（归属与商标）
- `NOTICE`：声明本项目为独立第三方部署/编排工具，**不分发、不内嵌、不修改** Ghidra/REA，仅运行时下载；完整保留 Ghidra（NSA，Apache-2.0）、rea-agents（morluto，MIT）、JDK、Node 的版权与许可；附中文说明。
- `TRADEMARKS.md`：中英商标声明（no affiliation / no endorsement / names belong to owners），名称使用为指示性合理使用（nominative use）。
- `CITATION.cff`：CFF 1.2.0，authors=洋洋（family-names），license=PolyForm-Noncommercial-1.0.0，含 repository-code。

### Added（社区健康）
- `CODE_OF_CONDUCT.md`：Contributor Covenant 2.1（联系方式改为维护者 GitHub）。
- `.github/ISSUE_TEMPLATE/`：bug_report / feature_request / config.yml（讨论与私密安全报告入口）。
- `.github/pull_request_template.md`、`.github/CODEOWNERS`（`* @yyds8170-ctrl`）、`.github/FUNDING.yml`（暂注释）。
- `README.md` / `README.en.md`：新增 Maintainer: 洋洋（yyds8170-ctrl）与独立第三方声明；目录树补全新文件；版本历史补 v3.3。

### 法律结论
- 作者在自己原创脚本/文档上署笔名「洋洋」，系行使《著作权法》第十条署名权，**不侵权**；同时保留全部第三方版权与许可，不将 Ghidra/REA 据为己有。本项目不随仓库分发第三方二进制，故无 Apache-2.0 第 4(d) 条 NOTICE 强制义务；现以 NOTICE/TRADEMARKS 做善意归属与无隶属声明。

### 本机实测
- shellcheck 0、bash -n 过、bash3.2 红线 0；全部 ps1 PSSA Error 0；`check-docs-links.sh` 0 死链（新 md 已计入）；`check-versions.sh` 过；CI lint 静态自检通过。版本号一致性 VERSION/CHANGELOG/CI 断言/CFF。

## [3.2.0] - 2026-10-15

### Added（国际化，纯文档）
- 完整英文 `README.en.md`（徽章/TOC/Quick Start/mermaid 决策树与架构图/真实数字/FAQ/版本历史 v1.0→v3.2）。
- 英文文档索引 `docs/README.en.md`（按 Getting started/Platforms/Usage/Configuration & supply chain/Operations 分组）。
- 8 篇关键文档英译对照：entry/mcp/export/batch/mirrors/configuration/troubleshooting/platform-support-matrix（`docs/*.en.md`）；每篇顶部中英互链；无英文版的 platform/offline 页在英文索引标注 (Chinese only)。
- 中英 README 与 docs 顶部语言切换行；支持矩阵新增“锁定版本与统一能力”节。

### Changed
- 刷新文档与脚本注释里的旧版本表述（安装器实际便携 Node 统一为 24.22.0、实测能力 rea-agents 6.5.0），覆盖 README、平台/故障文档、install*.sh/.ps1、doctor、prepare-offline、SKILL、Dockerfile 注释、mcp-setup 与 verify 示例；版本门禁 `^22.19 || ^24.11 || >=26` 与 CHANGELOG/版本历史中的历史快照保持不变。`check-docs-links.sh` 增加剔除行内 code span 以正确处理文档示例语法。

### 本机实测
- `bash scripts/check-docs-links.sh`：30 个 md、190 个相对链接、0 死链；临时死链负向测试正确非 0。
- shellcheck 0、bash -n 过、bash3.2 红线 0、全部 ps1 PSSA Error 0、ci.yml/release.yml yaml 过；`./rea-ghidra verify` 仍 9/9。

## [3.1.0] - 2026-10-15

### Changed（文档美化，不改功能）
- README 重构：顶部 8 个 shields 徽章（CI/release/license/platform/Ghidra 12.1.4/JDK 21/rea 6.5.0/Node 24.22.0）、目录 TOC、30 秒快速开始（统一入口三平台）、mermaid 环境决策树（flowchart TD）与架构示意图（flowchart LR）、常见问题 FAQ 8 条；目录树校正（Docker 注释 Node22→便携 Node 24.22.0）。
- docs/README.md 索引补全：按快速开始/使用/配置与供应链/运维分组，补全 entry/mcp/export/batch/mirrors/offline 链接。

### Added
- `scripts/check-docs-links.sh`：文档相对链接死链检查器（bash3.2 兼容，解析 `[文本](相对路径[#锚点])`，跳过外部/锚点/占位，断言目标存在）；接入 CI lint-build。本机实测 20 个 md、120 个相对链接、0 死链；临时死链负向测试正确以非 1 退出。

### 本机实测
- shellcheck 0、bash -n 过、bash3.2 红线 0、全部 ps1 PSSA Error 0、ci.yml/release.yml yaml 过；`./rea-ghidra verify` 仍 9/9。

## [3.0.0] - 2026-10-15

### Added（一体化体验，major）
- 统一入口：仓库根 `rea-ghidra`（bash）与 `rea-ghidra.ps1`（PS5.1/7 兼容）。极薄分发层，子命令 `install/doctor/verify/mcp/export/batch/fixtures/walkthrough/version/self-update/current/rollback/help`，全部透传参数到既有脚本并保留退出码，不复制逻辑。
- `version [--check]`：打印 VERSION，可选联网查 GitHub 最新 release（离线/失败优雅降级）。
- 多版本 `current`：安装器在 `~/tools` 原子维护 `current-ghidra`/`current-jdk` 软链；发现逻辑优先读 current 再回退版本化目录枚举（ghidra-export.sh 已接入）。`rea-ghidra current` 列出版本与链接；`rea-ghidra rollback` 在并存多版本时切回上一个，单版本时明确告知无可回滚。

### Changed
- install.sh 安装后 `ln -sfn` 原子刷新 current 软链；rc 环境块仍写版本化目录路径（向后兼容）。

### Security
- self-update 安全校验：git 副本只 `git pull --ff-only`（拒绝 merge/force；工作区有未提交改动先提示、不 stash/覆盖）；非 git（tarball）副本下载最新 tar.gz **与同名 checksums.txt 强校验 sha256**，不一致/取不到 checksums 即拒绝退出。`--check`/`--dry-run` 只报告不写盘。CI 只允许跑 `self-update --check`。

### 本机实测（2026-10-15，Ghidra 12.1.4/JDK21）
- `./rea-ghidra version`→3.0.0；`--help` 中文用法；`doctor` 0 失败；`verify` 9/9；`mcp --check` `server=rea 6.5.0`；`current` 正确显示软链；`rollback` 单版本提示无可回滚、双版本（伪造第二目录）双向切换正确；self-update git 分支 `--check` 落后 0 不写盘；tarball 分支坏 sha256 负向测试被拒绝。

## [2.9.0] - 2026-10-15

### Changed（上游跟进，先验证后改锁）
- 便携 Node 锁 `22.19.0 → 24.22.0`（LTS Krypton），REA 锁 `6.4.0 → 6.5.0`；Ghidra 12.1.4 / JDK21 不变。REA 引擎范围 `^22.19||^24.11||>=26` 仍适用，未改。
- 改锁前本机全链路验证：node v24.22.0 linux-x64 真实下载并通过官方 SHASUMS256（`28ea0a43…4228c`）；`rea-agents@6.5.0 --version=6.5.0`、`doctor --provider ghidra --format json` 报 `available=true providerVersion=12.1.4`；MCP stdio 握手 `server=rea 6.5.0`；`REA_VERSION=6.5.0 REA_NODE_VERSION=24.22.0 bash verify.sh` 9/9。

### Security / 供应链
- Release 新增 `checksums.txt`（对源码 tar.gz 计算 sha256）与 SBOM（`anchore/sbom-action@v0.17.4` 固定 tag，spdx-json，空组件不阻断；失败时兜底手写最小 SPDX 2.3）。
- 镜像复核：node v24.22.0 上 npmmirror（302→CDN）、华为云（200, Content-Length 与官方一致）可达；TUNA nodejs-release 对该版本 404，继续排除。

### Added
- 多架构 fixture 回归：`examples/fixtures_src/fixture.c` + `scripts/build-fixtures.sh`（`i686-linux-gnu` 交叉 ELF32、aarch64-linux-gnu AArch64 ELF、mingw i686 PE32；产物 gitignore）；CI 新增 `fixture-multiarch` 作业，Ghidra 跨架构导入并断言 `x86:LE:32` / `AARCH64:LE:64`。
- `examples/walkthrough.sh`：端到端中文引导（doctor→verify 9/9→ghidra-export→batch+快照缓存→mcp --list/--dry-run），幂等只读、不写用户 MCP 配置。

### Fixed（发布前复核）
- `release.yml`：移除 checksums 步骤里一行无效的 `cd <tar.gz 文件>`（报错被 `|| true` 吞掉，靠工作目录侥幸正确）；修正 SBOM 兜底 JSON 里重复的 `SPDXID` 键，改为字段完整、命名空间指向真实仓库的最小 SPDX 2.3 文档（已用等价脚本在本机生成并通过 JSON/字段校验）。
- `release.yml`（v2.9 首次真实发布后核验发现）：anchore/sbom-action 的 `upload-artifact`/`upload-release-assets` **默认都是 true**，会忽略 `output-file` 把 SBOM 写到临时目录，softprops 因而找不到 spdx.json（仅传了 tar.gz/checksums）。显式置 `false` 并用绝对 `output-file` 落到工作区，兜底步骤改为“文件缺失/为空才写最小 SPDX 且校验 JSON”，softprops 加 `overwrite_files: true`；确保 Release 必含 tar.gz + checksums.txt + spdx.json 三件资产。
- `examples/walkthrough.sh`：批量步骤里 `$B2` 在赋值前被引用（`set -u` 报 unbound），并改用两个 sha256 不同的目标（demo / demo_stripped）避免相同 sha 去重；shellcheck 不报（同脚本后文有赋值），靠实跑发现。
- `fixture-multiarch` 在 Ubuntu 24.04（ubuntu-latest）上装 `gcc-multilib` 报 “held broken packages”（与原生 gcc 版本冲突）。ELF32 改用跨目标 `gcc-i686-linux-gnu`（与 aarch64/mingw 交叉编译器共存、不触碰原生工具链），CI 与 `build-fixtures.sh` 同步去掉 gcc-multilib；`build-fixtures.sh` 保留 `gcc -m32` 作为缺交叉编译器时的回退。

### 本机实测（2026-10-15）
- build-fixtures 三类产物：ELF 32-bit x86、ELF 64-bit ARM aarch64、PE32（Intel 80386）；Ghidra 导入日志 `x86:LE:32:default:gcc`（23 funcs）、`AARCH64:LE:64:v8A:default`（24 funcs）。
- `check-versions`：rea-agents 最新=6.5.0 与锁定一致；`mcp-setup --check` 握手 `server=rea 6.5.0`。

## [2.8.0] - 2026-10-15

### Added
- 批量并行分析编排（在 v2.7 单目标导出之上，不依赖 REA/Node）：
  - `scripts/batch-analyze.sh` 与 `scripts/batch-analyze.ps1`（PS5.1/7 兼容）：一个或多个二进制/`--dir`（`--recurse`/`--pattern`）；`--jobs N`（默认 `nproc`/`sysctl hw.ncpu`，封顶 4）；`--retries M`；`--snapshot DIR` 快照缓存；`--continue` 断点续跑。
  - 并行：bash `xargs -0 -P $JOBS`（不依赖 GNU parallel），每个目标子进程调 `ghidra-export.sh`、结果写各自 `.results/<sha12>.json`（不并行写同一文件）；PS 用 `Start-Job` + 节流（一个代码路径通吃 5.1/7）。
  - 失败隔离：单目标失败不影响其它，按 retries 只重跑该目标；全部跑完才写 `summary.json`（每目标 input/sha256/status/elapsed/retries/out_dir/error/cached）；全成功退出 0、有失败退出 1。
  - 快照缓存：键 = `sha256_kind_v<EXPORT_SCHEMA_VERSION>`；命中跳过 analyzeHeadless 还原缓存产物并标记 `cached:true`；内容/kind/schema 变化自动失效。
  - `scripts/selftest-batch.sh`；e2e Linux 接入；新增 [docs/batch.md](docs/batch.md)。

### Fixed
- 修复 v2.7 遗留：`ghidra-export.sh` 末尾产物打印 `[ -f "$p" ] && printf ...` 在 `--kind` 单类（非 all）导出时，缺失产物使整条 `&&` 返回非 0，`set -e` 下脚本误退出 1（v2.7 selftest 跑 all 未暴露，批量单类时才触发）。改为 `if [ -f ... ]; then ...; fi`。

### 本机实测（2026-10-15，Ghidra 12.1.4 / JDK21）
- 3 个小目标 `--jobs 3 --kind functions --snapshot`：首次全部 success、约 48s、退出 0；第二次同 snapshot **1s、cached 3/3**。
- 失败隔离：worker 在无效 Ghidra 环境下正确写 `status=failed` 且 worker 退出 0（不传染主进程）。
- shellcheck 零告警；bash -n 全过；bash3.2 `$var紧跟中文` grep 零命中；ci.yml 经 python yaml 解析；PS parse + PSScriptAnalyzer 无 Error；`verify.sh` 仍 9/9。

## [2.7.0] - 2026-10-15

### Added
- 新增 Ghidra 静态分析导出能力（纯 analyzeHeadless，不依赖 REA/Node）：
  - `scripts/ghidra/` 6 个原创 GhidraScript：`ExportFunctions`（函数清单）、`ExportStrings`（字符串）、`ExportSymbols`（符号/导入导出）、`ExportCalls`（caller→callee 调用边）、`ExportDecompiled`（逐函数伪代码）、`ExportAll`（一次导出全部）。JSON 手写转义，产物可被 python3 `json.load` 解析。
  - 包装器 `scripts/ghidra-export.sh` 与 `scripts/ghidra-export.ps1`（PS 5.1/7 兼容）：参数 `<二进制> --out DIR --kind functions|strings|symbols|calls|decompiled|all`，自动定位 GHIDRA_INSTALL_DIR/JAVA_HOME，独立临时工程 + trap 清理，跨平台超时（timeout/gtimeout/裸跑，`REA_EXPORT_TIMEOUT` 可覆盖）。
  - `scripts/selftest-export.sh`：对 `examples/demo` 跑 `--kind all` 并断言 JSON 合法、函数≥1、main 存在、字符串/符号/调用边/伪代码非空。
  - e2e 三平台接入导出回归（Windows 对 `examples/bin/windows-x64/demo.exe` 跑 functions）；新增 [docs/export.md](docs/export.md)。

### Changed
- 旧 `scripts/DecompileAll.java` + `scripts/ghidra-decompile.sh`（v2.2）保留为向后兼容入口，新 `--kind decompiled` 是其超集，未静默删除。
- 修复 CI lint-ps 的 PSScriptAnalyzer 步骤空跑：原 `Invoke-ScriptAnalyzer -IncludeRule *.ps1` 把文件通配符误当规则名（`-IncludeRule` 是按规则名过滤），导致永不命中。改为 `-Recurse` 后按 `Severity -eq Error` 判失败（Warning 仅计数不阻断，仓库既有 best-effort 空 catch/命名风格属 Warning 基线）。

### 本机实测（2026-10-15，Ghidra 12.1.4 / JDK21）
- 对 `examples/demo` 一次 `--kind all`：functions=21（含 main）、strings=83、symbols=102、calls=14、decompiled=18（含 main 伪代码），全部 JSON 解析通过；selftest 6 项断言全 PASS。
- 踩坑修正：Ghidra headless 对带 Ghidra 依赖的兄弟辅助类运行时类加载不稳定（`runScript`/辅助类 `NoClassDefFoundError`），最终改为每个脚本自包含、ExportAll 内联全部 5 类逻辑；`SymbolType` 无 `name()/getName()`，用 `toString()`。
- shellcheck 零告警；bash -n 全过；ci.yml 经 python yaml 解析；PS parse + PSScriptAnalyzer 零告警；`verify.sh` 仍 9/9。
- **Windows JDK17 注入修复**：GitHub Windows runner 默认注入 `JAVA_HOME=JDK17`，`analyzeHeadless.bat` 报 `unsupported java version / Failed to find a supported JDK` 拒绝启动。`ghidra-export.ps1` 改为 dot-source `lib/common.ps1` 复用 `Get-JdkMajor`：现有 `JAVA_HOME` major<21 时从 `$ToolsDir`（`TOOLS_DIR` 优先，否则 `%USERPROFILE%\tools`）找 `jdk-21*` 并**强制**写回本进程；Ghidra 发现同步改用 `$ToolsDir`；调用 analyzeHeadless 前 PS7 临时关 `PSNativeCommandUseErrorActionPreference`（stderr WARNING 不被 EAP=Stop 当终止错误）。bash 端 `ghidra-export.sh` 同步加 `jdk_major` 校验：现有 `JAVA_HOME` major<21/为空时回退 `$TOOLS_DIR/jdk-21*`。本机实测 `JAVA_HOME=/tmp/fakejdk` 跑 functions 自动回退 tools JDK21 并成功导出 21 函数。

## [2.6.0] - 2026-10-15

### Added
- 新增 `scripts/mcp-setup.sh` 与 `scripts/mcp-setup.ps1`（PS 5.1/7 兼容）：把 rea-agents MCP server 一键注册进主流客户端并做连接自检。
  - `--list`：检测 Claude Desktop / Cursor / VS Code / Claude Code 配置是否存在与目标路径，不改。
  - `--dry-run`：渲染将写入的标准 stdio JSON（`command` 为 npx 绝对路径，args 含 `--mcp`，env 带 JAVA_HOME/GHIDRA_INSTALL_DIR/REA_MIRROR），不写盘。
  - `--client <名> --yes`：写盘前备份 `.bak`，只合并/更新 `mcpServers.rea`，不删其它条目，幂等；默认不加 `--yes` 不写。
  - `--check`：① 原生 MCP stdio（实测为换行分隔 JSONL）发 JSON-RPC `initialize` 握手，读到合法 `result` 即过；② 有 Ghidra/JDK 时跑 `rea doctor --provider ghidra --json` 断言 `providerInspections[].ghidra.available`，无 Ghidra 优雅跳过②。
- 安装器结尾只**打印** MCP 注册提示命令（不在安装时静默改客户端配置）。
- CI：lint-build 加 mcp-setup `--list/--dry-run/--check`；lint-ps 加 `mcp-setup.ps1 -List/-DryRun`；e2e 三平台跑 `--check` 并用临时 HOME 真实注册一个客户端、断言注册 JSON 含 `--mcp`（不污染 runner 默认配置）。
- 新增 [docs/mcp.md](docs/mcp.md)。

### Changed
- 基于实测的 rea-agents@6.4.0 能力：`rea setup --client/--yes/--dry-run`、`rea mcp add --agent`、`rea mcp doctor --json`；本脚本自己写最小 stdio JSON（比 `rea setup` 更少副作用、便于自动化），官方向导仍可手动用。
- 修复 `mcp-setup.sh` 在 `set -u` 下未设置 `JAVA_HOME/GHIDRA_INSTALL_DIR`（如 CI lint 无 Ghidra 环境）时 dry-run 直接崩溃：env 构建改用 `${VAR:-}`，无环境时输出 `"env": {}`，`--check` 仅跑握手并优雅跳过 Ghidra 体检。
- 修复 macOS 兼容：macOS（BSD）默认无 GNU `timeout` 命令（握手步骤直接报 `command not found` 127）。新增跨平台 `timeout_run`（`timeout`→`gtimeout`→`perl alarm/exec`→直跑），握手与 doctor 体检均走它，Linux/macOS 均可用。
- 修复 macOS 自带 bash 3.2 的变量名解析：`set -u` 下 `"$ver）"`（`$变量` 紧跟全角中文标点）会把多字节字符的首字节误并入变量名，导致 `unbound variable`。已把 `mcp-setup.sh`/`args.sh`/`download.sh`/`selftest-download.sh` 中所有 `$变量<非 ASCII>` 改为 `${变量}`；CI lint-build 新增 bash3.2 非 ASCII 紧邻检查（Linux 即可拦截，无需等 macOS e2e）。

### 本机实测（2026-10-15，Ubuntu 22.04 x86_64，pwsh 7.6.7）
- `shellcheck -x` 零告警；`bash -n` 全过；ci.yml 经 python yaml 解析；`scripts/check-versions.sh` 通过；PS 7 文件 parse + PSScriptAnalyzer 无 Error/Warning。
- `mcp-setup.sh --list/--dry-run` 正常；`--check` 握手 `server=rea 6.4.0`、Ghidra provider `12.1.4` 可用；临时 HOME 注册后 JSON 含 rea 绝对命令、`other-server` 保留、二次幂等、`.bak` 存在。
- PS：`mcp-setup.ps1 -List/-DryRun/-Check` 均通过（修了两个坑：common.ps1 的 `$OutputEncoding=UTF8 带BOM` 会让 stdin 多 BOM、EAP=Stop 下 npx stderr 触发终止错误——握手块内临时重置）。

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

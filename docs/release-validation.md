[English](release-validation.en.md) | 简体中文

# v6.0.0 发布验证报告 / Release Validation Report

> 本文件是打 `v6.0.0` 标签、创建 GitHub Release 之前的**最终发布验证依据**。
> 所有计数与结论均以仓库内真实文件与 CI 真实回跑为准；凡本环境无法复现的前置
> （Android 真机 / macOS / JEB / docker）一律标注为「仅文档化、未在本环境实测」，
> **绝不把未测写成已测**。

## 1. 验证总览

| 验证项 | 结果 | 环境 / 依据 |
|---|---|---|
| 本机 `bash verify.sh` | **9 / 9 通过** | 本机 Linux x86_64：JDK21 + Ghidra 12.1.4；`analyze` 识别 ELF / x86_64，procs=28、strings=83 |
| 完整 CI（`.github/workflows/ci.yml`） | **9 / 9 全绿** | GitHub Actions 真实 runner 全量回归（见下方清单） |
| CI `domain-cases` 作业 | **16 passed / 0 failed / 0 skipped** | ubuntu-24.04 + Node 24 + Wireshark 4.x + WABT 1.0.42 + 钉死 pwntools + rizin 0.9.1 |
| CI `fixture-multiarch` 作业 | **三架构导入断言全过** | Ghidra 导入 ELF32→`x86:LE:32`、AArch64→`AARCH64:LE:64`、PE32 导出非空 |
| MCP stdio 握手 | **通过** | `bash scripts/mcp-setup.sh --check`：`initialize` 返回 `server=rea 6.8.0`，`doctor --provider ghidra` 报 available / providerVersion=12.1.4 |

**完整 CI 9 条腿全绿**：`lint-build`、`lint-ps`、`e2e`（linux / macos / windows 三平台矩阵）、
`docker`、`docker-arm64`、`checksum`、`fixture-multiarch`、`domain-cases`。
其中 `e2e` / `docker*` / `checksum` / `fixture-multiarch` / `domain-cases` 由
`schedule` / `workflow_dispatch` 守卫，完整回归时一并触发。

## 2. 覆盖矩阵摘要

命令基线：**175 个真实命令**（不是 176），命令名与入库基线
[`config/command-baseline/rea-6.8.0.txt`](../config/command-baseline/rea-6.8.0.txt) 逐行一致；
另有 `completions`、`mcp` 两个集成入口，**不计入 175**。逐命令明细见
[`docs/capability-map/coverage-matrix.md`](capability-map/coverage-matrix.md)。

### 2.1 按 10 领域计数（合计 175）

| 领域 | 命令数 |
|---|---:|
| ① 核心 / Ghidra 原生 | 20 |
| ② 离线二进制 | 20 |
| ③ 动态调试 | 15 |
| ④ Web / JS / Electron | 28 |
| ⑤ Android / ADB | 33 |
| ⑥ Apple | 9 |
| ⑦ 多格式 | 15 |
| ⑧ 固件 / 嵌入式 | 9 |
| ⑨ Evidence / 工程化 | 16 |
| ⑩ JEB / 平台 | 10 |
| **合计** | **175** |

### 2.2 按 5 类可测性计数（合计 175）

| 可测性 | 数量 | 本发布如何对待 |
|---|---:|---|
| ✅ linux-testable（内置纯解析，无额外前置） | **78** | 本机 / Linux runner 可直接跑 |
| 🔧 needs-tool（需安装对应工具链） | **35** | 前置装齐后在 CI 真实跑通并断言（见 §2.3） |
| 📱 needs-device（需存活进程 / UI / 连接设备） | **50** | 本环境无 Android 真机 / 存活调试目标，**仅文档化，未实测** |
| 🍎 needs-macos（需 macOS 宿主 + LLDB / Apple 产物） | **8** | 本环境为 Linux，**仅文档化，未实测**（macOS 装机/验证靠 `e2e` macos runner 回归） |
| 💼 needs-jeb（需商用 JEB 运行 / 授权） | **4** | 本环境无 JEB 授权，**仅文档化，未实测** |

> 78 + 35 + 50 + 8 + 4 = 175，与命令总数一致。

### 2.3 哪些真实跑通、哪些仅文档化

- **真实跑通并断言（CI `domain-cases`，16 passed）**：离线二进制
  （`inspect-with-objdump`、`list-objdump-architectures`、`inspect-binary-layout`）、
  多格式（`inspect-python-pyc`、`inspect-sqlite-database`、`inspect-wasm-artifact`、
  `compare-wasm-interfaces`、`inspect-pcap-client`、`inspect-pcap-capture`）、
  动态（`debug-with-gdb`、`execute-rizin-command`、`debug-with-rizin`）、
  Evidence / 平台自检（`inspect-artifact`、`inspect-byte-entropy`、`inspect-elf-notes`、
  `capabilities`）。详见 [`docs/domain-cases.md`](domain-cases.md)。
- **真实跑通（本机 `verify.sh`）**：Ghidra 原生核心链 `analyze` / `decompile` / `search`
  （procs=28、strings=83、segments=39；`decompile secret_check` 命中 0x539、
  `calc_discount` 命中 0x32，均 confidence=observed）。
- **仅文档化 / 本环境未实测**：50 条 needs-device（adb / frida / 浏览器 CDP / 存活 UI）、
  8 条 needs-macos（Apple 专用）、4 条 needs-jeb（商用 JEB）。这些命令在能力地图中
  保留「未实测 / 需对应前置」标注，不冒充实测。

## 3. 各版本改动摘要（v5.2.0 → v5.6.0）

| 版本 | 主题 | 要点 |
|---|---|---|
| **v5.2.0** | 适配 REA 6.8.0 | 上游 rea-agents 6.5.0→6.8.0、便携 Node→24.22.2；Node engines 门禁收紧到 patch 段；Windows 安装器按链接类型**修复/重建符号链接**（v2 缓存键使坏 junction 缓存整体失效）；旧 6.5 快照不兼容需重建；`analyze/decompile/search` 零回退 |
| **v5.3.0** | 175 命令全量能力地图 | 新增 `docs/capability-map/`（10 领域文件 + 175 行覆盖矩阵 + 集成入口附录，逐条 7 字段、中英双语）；命令基线 `config/command-baseline/rea-6.8.0.txt` 入库；可测性按 5 类逐条标注 |
| **v5.4.0** | 统一命令包装器 + 退出码 | `rea-ghidra` / `rea-ghidra.ps1` 新增 `run` / `domains` / `d1..d10` 统一包装层，叠加稳定退出码 **0 成功 / 2 用法错误 / 3 前置缺失 / 4 运行时失败**（bash + PowerShell 双端）。详见 [`docs/command-wrapper.md`](command-wrapper.md) |
| **v5.5.0** | 每周自动巡检 + 升级流水线 | 新增 `weekly-audit.yml`：每周只读探测 rea / Ghidra / JDK21 / Node 上游漂移；patch 级自动开 PR、显式派 CI 当门禁、CI 绿后直接 squash 合并；minor/major 与命令删改等人审，CI 红开「受阻」issue。详见 [`docs/weekly-audit.md`](weekly-audit.md) |
| **v5.6.0** | Linux CI 领域案例断言 | 新增多格式样本生成器 + `run-domain-cases.sh` 断言运行器 + `domain-cases` 作业，把「本机可测 / 需工具」命令从文档标注升级为 CI 真实跑通断言；前置缺失显式 skip。详见 [`docs/domain-cases.md`](domain-cases.md) |

## 4. 风险与已知限制

1. **weekly-audit 写路径未端到端实测**：只读 `detect → report` 路径已在真实 runner 验证
   （dry-run 成功、artifact 扁平落到工作区相对路径）。但「开 PR → 派 ci.yml 门禁 →
   轮询 → squash 合并 → 受阻 issue」这条**有副作用的写路径**，因当前无真实上游漂移、
   且不得人为制造漂移，**未做端到端**；仅完成静态校验 + 脚本级 / 临时 clone 验证。
2. **needs-device（50 条）/ needs-macos（8 条）/ needs-jeb（4 条）无法在本环境验证**：
   分别缺 Android 真机 / 存活调试目标、macOS 宿主、商用 JEB 授权。其中 macOS 装机与
   verify 由 CI `e2e` macos runner 回归覆盖；其余保持能力地图「未实测」标注。
3. **Release 仍为手动确认**：合并 patch 升级进 main **不会自动打 tag / 发版**；需人工
   确认后手动打 `v*` 标签才触发 `release.yml`。
4. **Node 不跨 major 自动跟**：巡检只在同 major 内跟 Node LTS patch（如 v24.x 内）；
   跨 major（v24→v26）需人工评估 engines 门禁，只在漂移报告里提示。
5. **离线预置包未随本版重打**：`offline/` 内预置 tgz 仍按既有流程单独刷新，不在本发布内。
6. **rizin 两条案例对 runner 网络敏感**：Ubuntu noble 无 apt 包，靠官方静态自包含 build；
   下载/解压偶发失败时该两条保持 skip（已整块 `|| true` 兜底，不阻断作业），不写成已测。

## 5. Release 资产说明

打 `v*` 标签触发 [`.github/workflows/release.yml`](../.github/workflows/release.yml)，
在 shellcheck 全量通过后产出 **3 个资产**（命名前缀 `rea-ghidra-setup-<tag>/`）：

| 资产 | 生成方式 | 说明 |
|---|---|---|
| `rea-ghidra-setup-<tag>.tar.gz` | `git archive` 源码快照 | 自动排除 `offline/`、`.git` 等未跟踪内容 |
| `rea-ghidra-setup-<tag>.checksums.txt` | `sha256sum` | 对上面 tar.gz 的 SHA-256 校验和 |
| `rea-ghidra-setup-<tag>.spdx.json` | Syft SBOM（失败兜底最小 SPDX 2.3） | SPDX JSON 软件物料清单；Syft 失败不阻断发布 |

> 多架构 Docker 镜像不在官方 Release 发布：需各自环境用 buildx 构建后推到自行管理的
> registry。本项目是脚本 / 技能集合，无编译产物。

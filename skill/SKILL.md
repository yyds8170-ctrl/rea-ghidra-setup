---
name: reverse-engineering
description: 当需要在没有源码的情况下分析一个已编译/已打包的软件时使用，包括原生二进制（exe/so/dll）、Android APK、Electron/JavaScript 桌面应用、.NET 程序集、网站前端、HAR/SAZ 抓包文件、固件、WASM、EVM 字节码、SQLite 数据库、pcap 网络包等；典型诉求如"分析这个竞品 App 的某个功能怎么做的""看懂这个小程序/客户端的交互和接口""帮我逆向/反编译这个软件""对比两个版本的差异""为了兼容/学习研究拆开看看"。普通源码仓库的架构分析不要用本技能。
---

# Reverse Engineering（基于 REA 的证据驱动逆向）

> **快照基线**：本技能是面向豆包 Agent 环境的**静态快照**，基于 `rea-agents@6.5.0` + Ghidra `12.1.4` 验证。
> 上游 REA 会持续演进（官方 skill 也有自己的版本号），本快照可能随升级过期——升级 REA 后若发现
> 命令、参数或输出格式不匹配，请以官方为准：运行 `rea setup`（或 `npx rea-agents@<新版本> setup`）
> 按官方流程安装/更新 skill，并对照官方文档（github.com/morluto/rea）修正用法。本快照仅保证
> 在其标注的版本基线上可用。

## 概述

把"没有源码也能看懂软件"这件事交给标准化流程。本技能桥接开源项目 **REA（Reverse Engineer Anything，github.com/morluto/rea）**：它把 Ghidra / Hopper / IDA / JADX / 浏览器等专业工具封装成统一工作流，所有分析在**本机**执行，每个结论都附带**证据（Evidence）和局限**。

在豆包环境中，REA 的 MCP server 不直接注册，因此**通过 Bash 调用其 CLI（与 MCP 共享同一套工作流）即可获得几乎全部能力**。

## 何时使用

- 分析竞品 / 他人软件中某个功能的实现方式（转场、缓存、剪贴板、搜索、播放器、滤镜、登录流程等）
- 只有安装包 / 可执行文件 / 抓包文件，没有源码，需要反编译、看调用关系、找接口
- 互操作研究（对接某客户端、解析其私有文件格式）
- 自有软件的调试、崩溃分析、安全审计、恶意样本分析
- 对比两个版本 / 两个产物的差异，梳理 Electron 主进程/渲染进程/IPC 边界
- 学习研究软件内含的设计思想与原理

## 何时**不**使用（红线）

- 手头**有完整源码仓库**：直接用普通读文件/代码分析工具，不要运行 REA。
- 以下诉求**拒绝**，REA 官方免责声明同样禁止：
  - 绕过 DRM、授权校验、反作弊、技术保护措施；开发游戏外挂
  - 绕过自己未授权系统的认证、风控、访问控制；入侵/抓取他人服务器
  - 直接复制、改名、发布、商用他人受版权保护的代码与素材（图片、音乐、美术资产）
  - 规避 AI 模型厂商的使用策略、转卖共享账号/API
- 拿不准授权范围时，先向用户说明法律边界，再决定是否继续。

## 工作原理

1. Agent 选定目标并提出问题 →
2. REA 在本机调用对应分析工具（静态分析不运行目标；运行时采集才会启动目标）→
3. 返回带 `evidence_id` 的结论，区分**观察 / 推断 / 未知** →
4. Agent 顺着证据追问，最后用大白话解释，或在**合规前提下**指导重建。

## 一键部署（本仓库，跨平台）

如果环境尚未就绪，使用 `rea-ghidra-setup` 仓库的安装脚本，按系统选择（先 `bash scripts/detect-env.sh` 自动识别）：

| 系统 / 环境 | 安装 | 自检 |
| --- | --- | --- |
| Linux / WSL2 / Crostini / Linux 云电脑 | `bash install.sh` | `bash verify.sh` |
| Windows 10/11 x64（物理机/虚拟机/VDI） | `.\install.ps1` | `.\verify.ps1` |
| macOS（Intel / Apple Silicon） | `bash install-macos.sh` | `bash verify-macos.sh` |
| Docker（任意宿主，amd64/arm64） | `docker build -t rea-ghidra .` 或 `docker compose build` | 容器内 `verify.sh` |

安装脚本会自动装 JDK 21 + Node 24.22.0（满足 REA 版本门禁）、下载 Ghidra 并在 arm64/macOS 上源码构建
缺失的 native decompiler。安装后/排障前先跑只读诊断：`bash scripts/doctor.sh`（Windows 用 `.\scripts\doctor.ps1`），
它检查 Node 版本、JDK 21、`analyzeHeadless`、native decompiler 是否就位；再跑 `rea doctor` 验证 provider 连接。

## 第一步：就绪检查

Node 要求：22.x（≥22.19）、24.x（≥24.11）或 26+。先体检（只读、不改配置）：

```bash
npx -y rea-agents@latest doctor --json
```

- 静态 JavaScript/Electron、.NET 分析**无需**反编译引擎，开箱即用。
- 原生二进制深度分析需要本机装有 Hopper / Ghidra / IDA（三选一）；APK 需无头 JADX + JDK；WASM 需 WABT；固件需 Binwalk/Unblob；pcap 需 tshark。
- 缺失某引擎只影响对应能力，不要为了修一个问题去安装无关软件。
- 优先使用已全局安装的 `rea` 命令；没有再用 `npx -y rea-agents@latest`。

## 目标路由表（目标类型 → 首个命令）

| 目标 | 命令 |
| --- | --- |
| 任意 App / 程序，先看整体 | `npx -y rea-agents@latest analyze <路径> --json` |
| 带证据的概览 | `npx -y rea-agents@latest inspect <路径> --json` |
| 反编译某个函数/过程 | `npx -y rea-agents@latest decompile <路径> [地址或函数名] --json` |
| Electron / JS 应用目录或 ASAR | `npx -y rea-agents@latest analyze-javascript-application <路径> --json` |
| Android APK（声明/类/方法） | `npx -y rea-agents@latest inspect-android-package <路径> --json` |
| APK 中某个类 | `npx -y rea-agents@latest inspect-android-class <路径> --json` |
| APK 中某个方法 | `npx -y rea-agents@latest inspect-android-method <路径> --json` |
| .NET 程序集 | `npx -y rea-agents@latest inspect-managed-artifact <路径> --json` |
| 网站页面（结构/脚本/截图） | `npx -y rea-agents@latest inspect-web-page <URL> --json` |
| 网站实测（点击/输入/导航） | `npx -y rea-agents@latest capture-browser-scenario ... --json` |
| HAR / SAZ 抓包 | `npx -y rea-agents@latest inspect-web-network-capture <路径> --json` |
| 固件镜像 | `npx -y rea-agents@latest inspect-firmware-regions <路径> --json` |
| WASM | `npx -y rea-agents@latest inspect-wasm-artifact <路径> --json` |
| EVM 字节码 | `npx -y rea-agents@latest inspect-evm-interface <路径> --json` |
| Go / Rust 二进制元信息 | `npx -y rea-agents@latest inspect-go-binary <路径>` / `inspect-rust-binary <路径>` |
| SQLite 数据库 | `npx -y rea-agents@latest inspect-sqlite-database <路径> --json` |
| pcap 网络包 | `npx -y rea-agents@latest inspect-pcap-capture <路径> --json` |
| 压缩包/安装包清单（ZIP/APK/IPA/MSIX/DMG） | `npx -y rea-agents@latest inspect-artifact <路径> --json` |

> 完整命令清单：`npx -y rea-agents@latest --help`；某个命令的参数：`rea <命令> --help`、机器可读契约 `rea <命令> --schema`。

## 标准工作流（务必遵守）

1. **先路由，再取证**：用户只说"我的 App"而没给名字/路径时，先问清楚，绝不替用户选一个示例目标。
2. **Summary-first**：对体积未知或很大的目标，先以 `--format json` 拿概览（JS 应用/ELF 可先用最小输出），再按需 `--filter-output` 或 `--token-limit` 收敛，不要一上来要完整结果。
3. **聚焦追问**：只有当返回结果留下某个具体疑问时才做后续调用；输入没变、阻塞没解除，不要重复同一分析。
4. **引用证据**：每个结论标注对应的 `evidence_id`，保留局限和覆盖范围；需要完整会话时导出证据包，而不是反复请求超大响应。
5. **静态 vs 运行时分开表述**：静态分析没有运行程序，绝不能声称"观察到了执行"；运行时采集会真实启动/操作目标，需明确告知影响。
6. **收尾**：原生分析会话结束后关闭会话；用大白话解释发现，并把"观察到的行为"与"重建时的设计选择"分开。

## 证据契约：观察 / 推断 / 未知 三分

- **观察（Observation）**：工具直接读到的事实（伪代码、汇编、字符串、清单、请求记录）。
- **推断（Inference）**：基于观察推出的候选结论（如函数签名、selector、参数、可变性），必须标注为"推断"。
- **未知（Unknown）**：拿不到、被截断、未覆盖的部分，明确列出，不用猜测填充。
- 反编译产物（伪代码/WAT）不是原始源码；选择器/参数字符串是推断候选；覆盖不全不代表接口完整。
- 安全线索同理：REA 能提出"可疑点"，但不能保证"可利用"，高价值结论仍需人判断，且验证漏洞必须在授权范围内。

## 重建 / 复刻：合规流程（关键）

版权保护代码的**表达**，不保护**功能、思想、处理过程、操作方法**；但"怎么得到新代码"决定法律风险。

- **净室隔离（Clean Room）**：一组人只做逆向、产出**功能说明书（不含对方代码）**；另一组**从未看过对方代码**的人照说明书独立实现。两者之间的"墙"是日后证明独立创作的证据。
- REA 让"读反编译结果"和"写新代码"的是同一个智能体，等于**拆了这道墙**——直接让同一 Agent 边看反编译边生成可商用代码，侵权风险高，应避免。
- 合规做法：让 REA 只产出**功能级规格文档**；实现阶段另起会话/由未接触反编译结果的一方完成，并保留净室记录。
- 法律口径（中国大陆，仅供理解，具体以律师意见为准）：
  - 《著作权法》第五十条第（五）项：为"计算机软件反向工程研究"可避开技术措施，但**不得向他人提供**避开技术措施的技术/装置/部件。
  - 《计算机软件保护条例》第十七条：为学习研究软件内含的设计思想和原理而使用软件，可不经许可、不付报酬。
  - 《计算机软件保护条例》第六条：保护不延及思想、处理过程、操作方法、数学概念。
  - 多数商业软件用户协议含"禁止反编译"条款；**"研究/分析"通常有豁免，"重建/复刻"无明确豁免**。
  - 数据层面：分析虽在本机，但结论会进入 Agent 上下文并发送给模型服务商；拆客户交付或保密协议下的软件前，先过这道合规账。

## 能力边界（管理预期，不夸大）

- **服务端逻辑拿不到**：能拆本机客户端，拆不到对方机房里的一半。SaaS 的核心业务逻辑（风控、计价、推荐、校验）多在服务端，逆向只能看到客户端与服务器间的请求/响应，看不到内部实现。
- **加固/混淆/加壳/反调试**会提高成本：无壳/轻度混淆较易；VMP 等高强度虚拟化保护目前啃不动，且会让伪代码残缺、容易误判。
- **护城河无法复制**：网络效应、牌照与商户网络、内容生态、数据与品牌，不是反编译能得到的。
- 工具多不等于效果好：超长工具说明可能挤占上下文，优先用最小必要命令；部分版本/宿主组合能力不同（例如较低版本 Ubuntu 上原生引擎链路可能不受官方支持，但静态 JS/.NET 分析不受影响）。

## 高频场景速查（电商 / 竞品）

- 分析竞品电商 App / 小程序的前端交互、转场、本地缓存策略、商品详情结构 → `inspect-android-package` / `analyze-javascript-application` / `inspect-web-page`。
- 拆解某 Electron 电商工具（如批量上架、修图客户端）调了哪些接口、IPC 怎么通信 → `analyze-javascript-application`。
- 分析一份抓包，看清客户端与服务器之间的请求顺序、参数、载荷 → `inspect-web-network-capture <HAR>`。
- 复刻老游戏/小工具中的**某个计算**（而非整盘复制）：先反编译拿到功能规格，再走净室流程独立实现。
- 对比自家应用新旧版本差异、确认改动点 → `compare-application-versions` / `compare-artifacts`。

## 交付要求

- 用大白话解释功能如何实现，每条结论附 `evidence_id` 与证据类型（观察/推断），明确列出未知与局限。
- 涉及重建时，提供功能规格并提示净室隔离与法律边界，不直接产出"边看反编译边照抄"的商用代码。
- 说明本次验证方式、覆盖范围、所用环境与仍存在的缺口。

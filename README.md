# REA + Ghidra 云电脑一键部署

[![CI](https://github.com/yyds8170-ctrl/rea-ghidra-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/yyds8170-ctrl/rea-ghidra-setup/actions/workflows/ci.yml)

在云电脑 / Linux 服务器上一键部署 **REA（Reverse Engineer Anything）+ Ghidra**，让 AI 智能体在没有源码的情况下分析二进制、App、抓包，产出带证据的结论。

- **REA**：`github.com/morluto/rea`，开源逆向编排框架（MCP server + CLI），MIT 协议
- **Ghidra**：`github.com/NationalSecurityAgency/ghidra`，NSA 开源反编译引擎，Apache-2.0
- 本仓库仅包含**安装/卸载/验证脚本、技能文件与使用文档**（不内置上述第三方二进制）

## 实测结果（2026-10，Ubuntu 22.04 x86_64 云电脑）

- JDK 21 + Ghidra 12.1.4 安装并通过 `rea doctor --provider ghidra` 全部检查（含 native decompiler）
- 对含校验/折扣逻辑的 ELF 程序反编译成功，`confidence: observed`，核心逻辑被完整还原。以下为真实输出：

```c
// rea decompile ./demo secret_check 的输出（Ghidra 12.1.4）
int secret_check(int code)
{
  int iVar1;
  int code_local;
  if (code == 0x539) {            // 0x539 = 1337（正确密码）
    iVar1 = 1;
  } else if (code < 0x2329) {     // 0x2329 = 9001
    iVar1 = 0;
  } else {
    iVar1 = 2;
  }
  return iVar1;
}
```

## 一键安装

```bash
bash install.sh
source ~/.bashrc
```

- 无需 root，JDK 与 Ghidra 装在 `~/tools`，脚本幂等可重复运行
- 安装前自动检查磁盘空间（`~/tools` 约 2.6GB、临时目录约 0.8GB）
- 环境要求：Linux x86_64、`curl`、`unzip`；REA 需 Node 22.19+ / 24.11+ / 26+
- 可选自定义版本：`GHIDRA_VERSION=12.1.4 GHIDRA_BUILD=Ghidra_12.1.4_build GHIDRA_DATE=20260921 bash install.sh`

## 端到端验证

```bash
bash verify.sh
```

脚本会真实编译 `examples/demo` 并调用 Ghidra provider，自动校验：

1. 前置依赖（node / gcc / analyzeHeadless）
2. demo 与 demo_stripped 编译无警告
3. `analyze` 识别 ELF / 架构 / 函数数 / 字符串
4. `decompile secret_check` 置信度 `observed`，且常量 `0x539`（1337）可见
5. 剥离符号的 `demo_stripped` 仍可被导入分析

全部通过退出码 0，可直接作为 CI 步骤。可覆盖：`REA_VERSION=6.4.0 ./verify.sh`。

## 使用方法

```bash
# 整体分析（ELF 段结构、函数、字符串等）
npx -y rea-agents@latest analyze ./demo --provider ghidra --format json

# 反编译指定函数
npx -y rea-agents@latest decompile ./demo secret_check --provider ghidra --format json

# 用 snapshot 缓存分析结果，多个命令复用、显著加速
npx -y rea-agents@latest analyze ./demo --provider ghidra --snapshot ./demo.snap --format json

# 静态分析 Electron / JavaScript 应用（无需 Ghidra）
npx -y rea-agents@latest analyze-javascript-application /path/to/app --json

# 就绪检查
npx -y rea-agents@latest doctor --provider ghidra
```

全局安装：`npm install --global rea-agents`，之后用 `rea` 命令。`verify.sh` 会优先使用全局 `rea`。

### 环境变量调优

| 变量 | 作用 | 默认 |
| --- | --- | --- |
| `GHIDRA_INSTALL_DIR` | Ghidra 安装目录（REA 据此定位） | 由安装脚本写入 |
| `JAVA_HOME` | JDK 21 目录 | 由安装脚本写入 |
| `GHIDRA_HEADLESS_MAXMEM` / `GHIDRA_MAXMEM` | Ghidra JVM 堆上限（如 `512M`、`2G`） | `2G` |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | 导入/分析/桥接启动超时（毫秒），大二进制可调大 | `330000` |
| `REA_ANALYSIS_PROVIDER` | 多个引擎时强制指定（如 `ghidra`） | 自动选择 |
| `REA_GHIDRA_LANGUAGE_ID` / `REA_GHIDRA_COMPILER_SPEC_ID` | 强制处理器语言/编译器规格（如 Borland PE） | 自动识别 |
| `REA_GHIDRA_DISABLED_ANALYZERS` | 关闭指定自动分析器（逗号分隔） | 默认全开 |

## 卸载

```bash
bash uninstall.sh        # 交互确认，仅删除本项目安装的 JDK/Ghidra 与 .bashrc 环境块
bash uninstall.sh --yes  # 跳过确认
```

全局安装的 REA 用 `npm uninstall --global rea-agents`；清理 REA 缓存（可选）：`rm -rf ~/.rea`。

## 故障排查

- **`doctor` 报 unsupported host（如 Ubuntu 22.04）**：REA 的 Hopper 原生基线是 Ubuntu 24.04+，但 **Ghidra provider 有独立要求**，在 22.04 实测可正常分析。以 `verify.sh` 的实际结果为准。
- **启动超时 / 大二进制卡住**：调大 `REA_GHIDRA_STARTUP_TIMEOUT_MS`（如 `600000`），并确认 MCP 客户端自身的超时也足够长。
- **内存不足 / Java 启动失败**：用 `GHIDRA_HEADLESS_MAXMEM` 调整堆；小目标可设 `512M`，大目标需要更大。
- **native decompiler 缺失**：`doctor` 会点名。x86_64 官方包自带；macOS 与 Linux ARM64 官方归档有时需按官方文档用源码构建（`make ghidra_opt`）。
- **容器内 AppArmor 报错**：Docker 场景用 `--security-opt apparmor:unconfined`（仅本地测试）。
- **按名反编译失败**：剥离符号（strip）后的二进制函数名变为 `FUN_xxxx`，请改用地址，或先 `analyze` 定位。

## 能力覆盖

| 目标 | 依赖 |
| --- | --- |
| 原生二进制（exe/so/dll）：伪代码、汇编、字符串、调用图 | Ghidra / Hopper / IDA |
| Android APK（方法级反编译） | JADX + JDK；真机操作需 adb |
| JavaScript / Electron 应用、.NET 程序集 | 开箱即用（静态分析） |
| 网站实测、HAR/SAZ 抓包、固件、WASM、EVM、SQLite、pcap | 各专项工具，按需配置 |

## 能力边界（请理性看待）

- **服务端逻辑拿不到**：能拆本机客户端，拆不到对方机房；推荐/风控/计价等核心通常在服务端
- **强加固 / 混淆 / 加壳**：VMP 等高强度虚拟化保护当前难以还原，且可能产生误判
- **护城河无法复制**：网络效应、牌照、生态、品牌不是反编译能得到的

## 合规红线（务必阅读）

本工具仅限**合法的安全研究、学习、互操作、软件保藏，以及对你拥有或获授权的软件进行分析**。

- 中国《著作权法》第五十条第（五）项：为"计算机软件反向工程研究"可避开技术措施，但**不得向他人提供**避开技术措施的技术/装置
- 《计算机软件保护条例》第十七条：为学习研究设计思想与原理可使用软件；第六条：保护不延及思想、处理过程、操作方法
- **"研究/分析"通常有豁免，"重建/复刻/商用"无明确豁免**；多数商业软件用户协议含禁止反编译条款
- 商用复刻请采用**净室隔离**：逆向组只产出功能说明书，实现组另起会话、不看反编译代码
- 分析结论会进入 Agent 上下文并发送给模型服务商，涉密/客户交付件请先评估

禁止：绕过 DRM / 授权 / 反作弊、开发外挂、未授权入侵或抓取线上系统、复制发布他人受版权保护的代码与素材。

## 目录

```
.
├── install.sh                # 一键安装 JDK21 + Ghidra + 环境变量
├── uninstall.sh              # 卸载脚本（仅删本项目安装内容）
├── verify.sh                 # 端到端自检（编译 + 真实分析 + 断言）
├── skill/SKILL.md            # 逆向工程智能体技能（可装入 Agent）
├── examples/
│   ├── demo.c                # 反编译测试程序（secret_check / calc_discount / main）
│   └── Makefile              # 编译 demo（含符号）与 demo_stripped（剥离）
├── .github/workflows/ci.yml  # CI：ShellCheck + 编译；每周/手动端到端回归
├── LICENSE                   # PolyForm Noncommercial 1.0.0
└── .gitignore
```

## 版本历史

- **v1.1（2026-10-14）**
  - 新增 `verify.sh` 端到端自检（编译 + analyze/decompile + 断言，8 项检查）
  - 新增 `uninstall.sh` 卸载脚本
  - 新增 `examples/Makefile`，并修复 `demo.c` 缺失的 `#include <stdlib.h>`
  - 新增 GitHub Actions CI：ShellCheck + 编译（每次），完整端到端（每周/手动）
  - `install.sh` 增加磁盘空间检查；环境变量块改为始终同步最新路径（支持升级版本）
  - CI 适配：`install.sh` 检测到 GitHub Actions 时写 `GITHUB_ENV`/`GITHUB_PATH`；
    `verify.sh` 校验 JDK 版本，预置 JDK 低于 21 时自动改用 `~/tools/jdk-21`
  - 核对上游：REA 6.4.0、Ghidra 12.1.4；补充故障排查、环境变量调优文档
  - 已在 CI 干净 runner 实测：lint-build 与完整 e2e 均 success，8/8 检查通过
- **v1.0（2026-10）**：首次发布，云电脑一键部署 JDK21 + Ghidra 12.1.4，含逆向技能与实测

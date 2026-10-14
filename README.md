# REA + Ghidra 云电脑一键部署

在云电脑 / Linux 服务器上一键部署 **REA（Reverse Engineer Anything）+ Ghidra**，让 AI 智能体在没有源码的情况下分析二进制、App、抓包，产出带证据的结论。

- **REA**：`github.com/morluto/rea`，开源逆向编排框架（MCP server + CLI），MIT 协议
- **Ghidra**：`github.com/NationalSecurityAgency/ghidra`，NSA 开源反编译引擎，Apache-2.0
- 本仓库仅包含**安装脚本、技能文件与使用文档**（不内置上述第三方二进制）

## 实测结果（2026-10，Ubuntu 22.04 x86_64 云电脑）

- JDK 21 + Ghidra 12.1.4 安装并通过 `rea doctor` 全部检查
- 对含校验/折扣逻辑的 ELF 程序反编译成功，`confidence: observed`，核心逻辑被完整还原，例如：

```c
// 反编译输出（原函数 secret_check，关键常量 1337 / 9000 以十六进制出现）
undefined8 secret_check(int param_1) {
  undefined8 uVar1;
  if (param_1 == 0x539)      uVar1 = 1;      // 0x539 = 1337
  else if (param_1 < 0x2329) uVar1 = 0;      // 0x2329 = 9000
  else                       uVar1 = 2;
  return uVar1;
}
```

## 一键安装

```bash
bash install.sh
source ~/.bashrc
```

- 无需 root，JDK 与 Ghidra 装在 `~/tools`，脚本幂等可重复运行
- 环境要求：Linux x86_64、`curl`、`unzip`；REA 需 Node 22.19+ / 24.11+ / 26+
- 可选自定义版本：`GHIDRA_VERSION=12.1.4 GHIDRA_BUILD=Ghidra_12.1.4_build bash install.sh`

## 使用方法

```bash
# 整体分析（ELF 段结构、函数、字符串等）
npx -y rea-agents@latest analyze ./demo --provider ghidra --format json

# 反编译指定函数
npx -y rea-agents@latest decompile ./demo --procedure secret_check --provider ghidra

# 静态分析 Electron / JavaScript 应用（无需 Ghidra）
npx -y rea-agents@latest analyze-javascript-application /path/to/app --json

# 就绪检查
npx -y rea-agents@latest doctor --provider ghidra
```

全局安装：`npm install --global rea-agents`，之后用 `rea` 命令。

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
├── install.sh        # 一键安装 JDK21 + Ghidra + REA 环境
├── skill/SKILL.md    # 逆向工程智能体技能（可装入 Agent）
├── examples/demo.c   # 反编译测试程序
└── LICENSE           # PolyForm Noncommercial 1.0.0
```

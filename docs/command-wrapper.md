# REA 命令包装器 / REA Command Wrapper

[English](command-wrapper.en.md) | 简体中文

> 自 v5.4.0 起，`rea-ghidra` / `rea-ghidra.ps1` 在原有安装/验证子命令之外，新增一组**统一 REA 命令包装器**：
> 在校验基线、解析环境之后再调用 `rea`（或锁定版本的 `npx -y rea-agents@<版本>`），并在 REA 之上叠加稳定的退出码分类。
>
> 这一层不重复实现 REA 的能力，只做三件事：**命令合法性校验 → 环境解析 → 统一调用与退出码映射**。

## 子命令

| 子命令 | 作用 |
| --- | --- |
| `run <命令> [开关] [-- 透传...]` | 通用入口：先校验命令在基线内，解析 JDK/Ghidra 环境，再调用 REA。 |
| `domains` | 列出 10 个 REA 领域及各自命令数。 |
| `d1` … `d10 <命令> [开关] [-- 透传...]` | 领域入口：先用 `command-domain.tsv` 校验该命令**确属**该领域，否则退出码 2；通过后等价于 `run`。 |

bash 示例：

```bash
./rea-ghidra run providers --json
./rea-ghidra domains
./rea-ghidra d1 analyze --json --out /tmp/analyze.json -- examples/demo --provider ghidra --snapshot /tmp/demo.snap
```

PowerShell 示例：

```powershell
.\rea-ghidra.ps1 run providers --json
.\rea-ghidra.ps1 domains
.\rea-ghidra.ps1 d1 analyze --json --out C:\tmp\analyze.json -- .\examples\demo --provider ghidra
```

## 包装器开关

这些开关由**包装器在透传前解析**；遇到 `--` 后，其后所有参数原样透传给 REA。

| 开关 | 作用 |
| --- | --- |
| `--json` | 强制追加 `--format json`（包装器放在透传参数之后，对 REA 具权威性）。 |
| `--schema` | 透传 REA 的 `--schema`，打印该命令的 JSON Schema。 |
| `--out <文件>` | 把 REA 的 **stdout** 落盘到 `<文件>`（自动 `mkdir -p` 父目录）；不给则 stdout 原样透出。 |
| `--quiet` | 压制 REA 的 stderr（包装器自身的错误分类信息仍走 stderr）。 |
| `--` | 其后所有参数原样透传给 REA（例如 `--provider ghidra --snapshot snap`）。 |

> 包装器开关必须出现在 REA 参数之前；要透传给 REA 的 flag 一律放在 `--` 之后。
> 未知开关、`--out` 缺值都会在调用 npx **之前**被判为用法错误（退出码 2）。

## 退出码

| 退出码 | 含义 | 何时产生 |
| --- | --- | --- |
| `0` | 成功 | REA 执行成功（REA 原生退出 0）。 |
| `2` | 用法错误 | 命令不在 175 命令基线内、包装器开关错误、`--out` 缺值、或 `dN` 入口校验命令不属于该领域——**调用 npx 之前**由包装器判定。 |
| `3` | 前置缺失 | `1-core-native`（Ghidra 原生）命令解析不到可用的 JDK 21 或 Ghidra——**不调用 npx**，直接返回。 |
| `4` | 运行时失败 | REA 已被执行但返回非 0（分析失败、文件不存在、坏 flag 等）。 |

> **重要**：REA 自身的退出码只有 `0`（成功 / `--help` / `--schema` / `--llms*`）与 `1`（未知命令、坏 flag、缺参数、文件不存在、分析失败等所有错误）。
> 上表的 `2 / 3 / 4` 是**本包装器根据预检查与 REA 退出码映射产生的分类，并非 REA 原生返回码**。上层脚本应按本表消费，而不是假设 REA 会直接返回这些码。

## 领域路由

运行时领域归属来自入库文件 [`config/command-baseline/command-domain.tsv`](../config/command-baseline/command-domain.tsv)（175 行，`命令名<TAB>domain<TAB>testability`，与 `rea-6.8.0.txt` 基线逐字一致）。

| 入口 | 领域 | 命令数 | 说明 |
| --- | --- | ---: | --- |
| `d1` | `1-core-native` | 20 | Ghidra 原生分析（analyze/decompile/search/…），**需要 JDK21 + Ghidra**，缺失时退出码 3。 |
| `d2` | `2-offline-binary` | 20 | ELF/PE/Mach-O/Go/Rust 离线静态解析。 |
| `d3` | `3-dynamic-debug` | 15 | 动态调试 / 运行时 / UI 抓取。 |
| `d4` | `4-web-js-electron` | 28 | Web / JS / Electron。 |
| `d5` | `5-android-adb` | 33 | Android / APK / ADB。 |
| `d6` | `6-apple` | 9 | Apple / macOS / iOS。 |
| `d7` | `7-multiformat` | 15 | WASM/EVM/pyc/BEAM/SQLite/pcap 等多格式。 |
| `d8` | `8-firmware-embedded` | 9 | 固件 / 嵌入式 / Flutter·Dart / HarmonyOS。 |
| `d9` | `9-evidence-engineering` | 16 | Evidence 与工程化。 |
| `d10` | `10-platform-jeb` | 10 | 平台自身命令（doctor/providers/capabilities/…）+ JEB。 |

> `d1..d10` 只做**领域归属校验**，不做能力门禁：一个命令归错入口会被退回（退出码 2），但它需要的其它工具（adb/frida/JEB 等）是否就绪仍由 REA 自行判断，失败时归为退出码 4。

## 可直接复制的示例

```bash
# 1) 平台自检，强制 JSON，退出码 0
./rea-ghidra run providers --json

# 2) 把 JSON 落盘到深层目录（自动建父目录），静默
./rea-ghidra run providers --json --out /tmp/rea-out/providers.json --quiet

# 3) 真实跑一次 Ghidra 分析（d1 领域，自动解析 JDK/Ghidra 并 export）
export PATH=/opt/nodejs/22/bin:$PATH
./rea-ghidra d1 analyze --json --out /tmp/analyze.json -- \
    examples/demo --provider ghidra --snapshot /tmp/demo.snap

# 4) 错误路径：未知命令（退出码 2）
./rea-ghidra run not-a-command            # → 2

# 5) 错误路径：领域归属不符（doctor 属于 d10，不是 d2）
./rea-ghidra d2 doctor                    # → 2
```

## 实现位置

| 端 | 库 | 入口 |
| --- | --- | --- |
| bash | `lib/rea-wrap.sh`（`rea_wrap_exec` / `rea_domain_dispatch` / `rea_tsv_lookup` / `rea_domains_table`） | `rea-ghidra` |
| PowerShell | `lib/rea-wrap.ps1`（`Invoke-ReaCommand` / `Get-ReaDomainsTable` / `Get-ReaCommandRecord`） | `rea-ghidra.ps1` |

内部复用 `lib/common.sh` / `lib/common.ps1` 的 `resolve_jdk_home` / `resolve_ghidra_dir` / `rea_mode`，并按 `verify.sh` 的方式构建 REA 调用：优先全局 `rea`，否则 `npx -y rea-agents@<REA_VERSION>`；cn 模式经 npmmirror registry 拉取（仅本进程）。

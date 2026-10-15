[English](export.en.md) | 简体中文

# Ghidra 静态分析导出（无需 REA）

`ghidra-export` 用 Ghidra 原生 `analyzeHeadless` 把一个二进制分析后导出成机器可读产物（JSON / 伪代码），**不依赖 rea-agents / Node / npm**，是纯 Ghidra 能力。适合：批量逆向、导出函数清单/调用图给下游工具、CI 中做二进制回归。

## 快速用法

```bash
# Linux / macOS
scripts/ghidra-export.sh <二进制> --out <目录> --kind all
scripts/ghidra-export.sh ./examples/demo --out /tmp/out --kind functions
scripts/ghidra-export.sh --help

# Windows（PowerShell）
pwsh -File scripts/ghidra-export.ps1 -Bin .\examples\bin\windows-x64\demo.exe -Out .\out -Kind all
```

- 自动定位 `GHIDRA_INSTALL_DIR`（环境变量优先，其次 `~/tools/ghidra_*_PUBLIC`）与 `JAVA_HOME`。
- 每次用独立临时 Ghidra 工程目录（`mktemp -d`），结束自动清理，不污染工程库。
- 跨平台超时：优先 GNU `timeout`，其次 `gtimeout`（macOS coreutils），都没有则裸跑；可用环境变量 `REA_EXPORT_TIMEOUT`（秒，默认 1800）覆盖。

## --kind 与产物字段

`--kind` 取值 `functions|strings|symbols|calls|decompiled|all`（默认 `all`）。`all` 一次导出全部 5 类。

| 产物 | 脚本 | 字段 |
|---|---|---|
| `functions.json` | ExportFunctions | `address`、`name`、`signature`、`thunk` |
| `strings.json` | ExportStrings | `address`、`value`、`length` |
| `symbols.json` | ExportSymbols | `address`、`name`、`type`、`namespace` |
| `calls.json` | ExportCalls | `caller_address`、`caller`、`callee_address`、`callee` |
| `decompiled.json` | ExportDecompiled | 对象：`"函数名": "C 伪代码文本"` |

脚本都在 `scripts/ghidra/`，经 `-postScript` 调用，每个脚本参数 1 = 输出目录。analyzeHeadless 直接调用示例：

```bash
"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" <projDir> Proj \
  -import <二进制> -scriptPath scripts/ghidra \
  -postScript ExportAll.java <outDir> -deleteProject
```

JSON 由脚本手写转义（classpath 不保证有 gson），产物可直接 `python3 -c "import json;json.load(open('functions.json'))"` 解析。

## 回归自测

```bash
bash scripts/selftest-export.sh
```

对 `examples/demo` 跑一次 `--kind all`，断言：JSON 全部合法、函数 ≥1、`main` 存在、字符串/符号/调用边/伪代码非空。e2e 三平台均接入此回归（Windows 对 `examples/bin/windows-x64/demo.exe` 跑 `functions`）。

## 与旧脚本的关系

- `scripts/DecompileAll.java` + `scripts/ghidra-decompile.sh`（v2.2 起）保留为向后兼容薄入口；新能力是其超集，`--kind decompiled` 即对应其反编译产物。
- 全部新脚本归本仓库 PolyForm Noncommercial 1.0.0 许可（原创代码，未照搬 MIT 项目）。

## 输出示例（examples/demo）

```
functions.json: 21 个函数（含 main、_init、printf 等）
strings.json:   83 个字符串
symbols.json:    102 个符号（Function / Label）
calls.json:      14 条调用边
decompiled.json: 18 个函数的伪代码
```

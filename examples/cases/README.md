# 端到端逆向案例库 / End-to-End Reverse-Engineering Case Library

本目录是 `rea-ghidra-setup` 的**可自动断言、可在 CI 与本机重复跑通**的逆向工程教学/回归案例库。
每个案例都是一个带源码的小程序，用 Ghidra `analyzeHeadless` 导出 `functions/strings/symbols/calls/decompiled` 五类 JSON，
再由 `scripts/run-cases.sh`（或 `.ps1`）逐项断言关键证据。

This directory holds an **auto-asserting, CI-repeatable** reverse-engineering case library.
Each case is a small C program; Ghidra headless exports five JSON kinds, and `scripts/run-cases.sh` asserts the key evidence.

## 案例清单 / Cases

| 目录 | 主题 | 关键证据（断言锚点） |
|---|---|---|
| [`01-crackme-password`](01-crackme-password/) | 口令 crackme（strcmp） | 字符串 `S3cr3t-2026` / `ACCESS GRANTED`；函数 `check_password`；调用边 `strcmp` |
| [`02-license-key`](02-license-key/) | 序列号异或求和校验 | 反编译含 `0x5a`(90) 与 `0x1b7`(439)；字符串 `LICENSE OK`；函数 `verify_key` |
| [`03-tiered-pricing`](03-tiered-pricing/) | 阶梯计价 | 反编译含满减 `0x32`(50) 与高阈值 `100`(0x64)；函数 `compute_price` |
| [`04-switch-dispatch`](04-switch-dispatch/) | switch 命令分派 | 字符串 `login/buy/about/exit-menu`；调用边 `do_login/do_buy/do_exit` |
| [`05-export-flow`](05-export-flow/) | 四类导出齐全演示 | functions/strings/calls/symbols 均非空；符号表识别 `printf/strlen/strcmp` |

## 编译 / Build

统一在本目录执行（产物全部输出到 `build/`，不污染 `examples/` 根）：

```bash
make            # 编译 5 个案例的带符号版 + strip 版
make clean      # 清空 build/
```

确定性编译参数：`gcc -O0 -g -fno-builtin -Wall -Wextra`；每个案例再 `cp + strip` 出 `*-stripped` 版本，
用于验证「无符号时关键常量/字符串仍可被 Ghidra 识别」。

## 运行断言 / Run assertions

```bash
# 本机（自动发现 Ghidra/JDK，可经环境变量覆盖）
bash scripts/run-cases.sh

# 可选环境覆盖
GHIDRA_INSTALL_DIR=~/tools/ghidra_12.1.4_PUBLIC \
JAVA_HOME=~/tools/current-jdk \
  bash scripts/run-cases.sh
```

Windows PowerShell：`pwsh -File scripts/run-cases.ps1`（需先有 `build/` 产物或安装 make/gcc）。

脚本会：`make` 编译 → 对每个二进制（含 stripped）跑 `scripts/ghidra-export.sh --kind all` →
用内嵌 python3 读取 JSON 逐项断言 → 打印 `[PASS]/[FAIL]` 与汇总，任一失败退出码非 0。

## 断言设计原则 / Assertion principles

- 只依赖**字符串、反编译常量、函数名、调用边**，**不依赖绝对地址**。
- 带符号版断言函数名/内部调用边；strip 版只断言**字符串 + 反编译常量**（内部函数名已变 `FUN_xxx`）。
- 反编译常量同时接受**十六进制**（如 `0x1b7`）与**十进制**（如 `439`）两种渲染。
- 已知反编译规整：`qty >= 10` 在伪代码里显示为 `9 < qty`、`total >= 1000` 显示为 `999 < total`、
  `total*20/100` 被化简为 `total/5`。这些已在对应案例 README 中说明，断言据实锚定可见形态。

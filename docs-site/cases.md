[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/cases/) | 简体中文

# 案例库导览

案例库位于 [`examples/cases/`](https://github.com/yyds8170-ctrl/rea-ghidra-setup/tree/main/examples/cases)，一键断言脚本是 `scripts/run-cases.sh`（Windows 为 `scripts/run-cases.ps1`）。每个案例都遵循同一条设计原则：

- 用 `gcc -O0 -g -fno-builtin` 编译，函数名清晰可读；
- 另存一份 stripped 版本，验证“不依赖符号名也能认出关键常量/字符串”；
- 断言只依赖**字符串、常量、函数名、调用边**，**绝不依赖绝对地址**（地址会随编译/链接漂移）；
- Ghidra 反编译中常量可能显示为十进制或 `0x` 形式，断言两种形态都搜。

下面 5 个主题按难度递进。

## 1. crackme 密码校验 — `01-crackme-password`

- **关键常量/字符串**：硬编码口令 `"S3cr3t-2026"`、成功提示 `"ACCESS GRANTED"`；函数 `check_password`；调用 `strcmp`。
- **断言**：strings 含两串；带符号版 functions 含 `check_password`；calls 含 `strcmp`（strip 后 PLT 调用仍在）。

## 2. license key 校验 — `02-license-key`

- **关键常量/字符串**：逐字节异或 `0x5A`(90)，求和目标 `0x1B7`(439)；正确 key 为 `"A6868"`；成功串 `"LICENSE OK"`；函数 `verify_key`。
- **断言**：反编译同时出现 `0x5a`/`90` 与 `0x1b7`/`439`；strings 含 `LICENSE OK`；带符号版含 `verify_key`。

## 3. 阶梯计价 — `03-tiered-pricing`

- **关键常量/字符串**：高数量阈值 `100`、低阈值 `10`；满减常量 `50`（`0x32`）；门槛 `1000`；函数 `compute_price`。
- **断言**：反编译含 `0x32`/`50` 与高阈值 `100`。
- **注意**：Ghidra 会把 `qty>=10` 规整为 `9 < qty`、`*20/100` 化简为 `/5`，因此不搜字面 `10`，原因见该案例 README。

## 4. switch 分派 — `04-switch-dispatch`

- **关键常量/字符串**：提示串 `"login-menu"`/`"buy-menu"`/`"about-menu"`/`"exit-menu"`；分派函数 `dispatch`；子函数 `do_login`/`do_buy`/`do_about`/`do_exit`。
- **断言**：strings 含四串；带符号版 calls 含 `do_login`/`do_buy`/`do_exit` 且 functions 含 `dispatch`；strip 版只断言字符串。

## 5. 导出流程 — `05-export-flow`

- **关键产物**：libc 导入 `printf` / `strlen` / `strcmp` / `snprintf`；验证完整 JSON 管线。
- **断言**：functions/strings/calls/symbols 均非空；symbols 识别 `printf`、`strlen`、`strcmp`。

## 跑一遍

```bash
# 编译全部案例（build/ 下生成带符号版与 stripped 版）
make -C examples/cases all

# 全量断言：5 案例 × 带符号/strip = 10 个二进制，任一失败退出非 0
bash scripts/run-cases.sh

# 对其中一个案例生成结构化报告（md + html + JSON）
bash scripts/ghidra-report.sh examples/cases/build/01-crackme-password --out /tmp/report
```

> 每个案例目录下都有一份中英 README 说明业务背景、预期结果与为何这样断言；总索引见
> [examples/cases/README.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/tree/main/examples/cases)。

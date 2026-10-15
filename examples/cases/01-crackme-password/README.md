# 01-crackme-password

## 目标 / Goal
经典口令校验 crackme：输入口令与硬编码串比较，正确打印 `ACCESS GRANTED`。
用于验证 Ghidra 能从二进制中恢复**字符串、函数名、外部库调用边**。

## 源码讲解
- `check_password(const char *input)`：用 `strcmp(input, "S3cr3t-2026")` 比较，相等返回 1。
- `main`：取 `argv[1]`，调用 `check_password`，成功 `printf("ACCESS GRANTED\n")`，否则 `ACCESS DENIED`。
- 编译加 `-fno-builtin`，保证 `strcmp` 不被内联/常量折叠掉，保留为真实 PLT 调用边。

## 编译
```bash
make                       # 在 examples/cases/ 下
# 产物：build/01-crackme-password（带符号）与 build/01-crackme-password-stripped
```

## 关键常量推导
| 项 | 值 | 说明 |
|---|---|---|
| 硬编码口令 | `S3cr3t-2026` | 直接出现在字符串表 |
| 成功提示 | `ACCESS GRANTED` | 直接出现在字符串表 |
| 校验函数 | `check_password` | 带符号版函数表可见 |
| 外部调用 | `strcmp` | 调用边 caller=main/check_password → callee=strcmp |

## 预期结果 / 如何断言
- `strings.json` 含 `S3cr3t-2026` 与 `ACCESS GRANTED`。
- `functions.json` 含 `check_password`（strip 版不检查函数名）。
- `calls.json` 中 callee 集合含 `strcmp`（PLT 导入在 strip 后仍在）。

## English summary
A textbook password crackme: the password `S3cr3t-2026` is checked with `strcmp`.
Asserts that Ghidra recovers the hardcoded strings, the `check_password` function name,
and the `strcmp` call edge — even after `strip`.

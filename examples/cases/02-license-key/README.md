# 02-license-key

## 目标 / Goal
序列号校验：对输入 key 逐字节与 `0x5A` 异或后求和，和等于魔数 `439`（`0x1B7`）即合法。
用于验证 Ghidra 反编译能恢复**算术常量**（异或 key 与魔数），即使 strip 后依然可见。

## 源码讲解
- `verify_key(const char *key)`：遍历每个字节 `sum += (key[i] ^ 0x5A)`，返回 `sum == 439`。
- `main`：合法打印 `LICENSE OK`，否则 `LICENSE INVALID`。

## 关键常量推导（已真实核算）
正确 key 取 **`A6868`**，逐字节异或 `0x5A`：

| 字符 | ASCII | ^ 0x5A | 十进制 |
|---|---|---|---|
| A | 0x41 | 0x1B | 27 |
| 6 | 0x36 | 0x6C | 108 |
| 8 | 0x38 | 0x62 | 98 |
| 6 | 0x36 | 0x6C | 108 |
| 8 | 0x38 | 0x62 | 98 |

求和 = 27 + 108 + 98 + 108 + 98 = **439 = 0x1B7**。
异或常量 `0x5A` = 十进制 **90**。

实测反编译（Ghidra 12.1.4）中呈现为：
```c
sum = sum + (char)(key[i] ^ 0x5a);
uVar1 = (uint)(sum == 0x1b7);
```

## 编译
```bash
make   # 产物 build/02-license-key 与 build/02-license-key-stripped
```

## 预期结果 / 如何断言
- `decompiled.json` 全文同时含 `0x5a`（或十进制 `90`）与 `0x1b7`（或十进制 `439`）。
- `strings.json` 含 `LICENSE OK`。
- 带符号版 `functions.json` 含 `verify_key`；strip 版只查常量与字符串。

## English summary
A license-key check: each key byte is XORed with `0x5A` and summed; the valid sum is `439`
(`0x1B7`) for the correct key `A6868`. Asserts the decompiler recovers both the XOR key
(`0x5a`/90) and the magic (`0x1b7`/439), in either hex or decimal rendering, after strip.

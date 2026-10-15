# 03-tiered-pricing

## 目标 / Goal
阶梯计价（比 `examples/demo.c` 更完整）：按数量分两档折扣，再叠加满减。
用于验证 Ghidra 反编译能恢复**阈值与折扣常量**。

## 源码讲解
```c
long compute_price(long total, long qty) {
  long discount = 0;
  if (qty >= 100)        discount = total * 20 / 100;  // 0x64 -> 20%
  else if (qty >= 10)    discount = total * 10 / 100;  // 0xa  -> 10%
  if (total >= 1000)     discount += 50;               // 0x3E8 满减 50(0x32)
  long payable = total - discount;
  return payable < 0 ? 0 : payable;
}
```

## 关键常量推导
| 源码常量 | 十六进制 | 含义 |
|---|---|---|
| 100 | `0x64` | 高数量阈值（八折） |
| 10  | `0xa`  | 中数量阈值（九折） |
| 20 / 100、10 / 100 | `0x14`/`0xa` | 折扣率 |
| 1000 | `0x3E8` | 满减门槛 |
| 50   | `0x32` | 满减金额 |

真实核算样例：`total=1200, qty=7` → 不足 10 件折扣 0，但 `total>=1000` 减 50 → 应付 **1150**；
`total=1200, qty=150` → 八折 240 + 满减 50 = 290 → 应付 **910**。

### ⚠ 反编译规整（据实调整断言的原因）
Ghidra 反编译该函数时把不等式与算术做了化简，实测伪代码：
```c
if (qty < 100) { if (9 < qty) { discount = total / 10; } }
else { discount = total / 5; }
if (999 < total) { discount = discount + 0x32; }
```
- `qty >= 10` → `9 < qty`（阈值 10 被改写为 9）；
- `total >= 1000` → `999 < total`；
- `total*20/100` → `total/5`，`total*10/100` → `total/10`；
- 满减 `+50` 保留为 `+ 0x32`。

因此断言**不搜字面 `10`**，而锚定稳定可见的 `0x32`(=50) 与高阈值 `100`。

## 编译
```bash
make   # 产物 build/03-tiered-pricing 与 build/03-tiered-pricing-stripped
```

## 预期结果 / 如何断言
- `decompiled.json` 含 `0x32`（或十进制 `50`）与高阈值 `100`。
- 带符号版 `functions.json` 含 `compute_price`。

## English summary
Tiered pricing with quantity thresholds (10/100), discount rates, and a flat rebate.
The decompiler normalizes inequalities (`qty>=10`→`9<qty`, `total>=1000`→`999<total`) and
folds `total*20/100`→`total/5`; assertions therefore anchor on the visible `0x32` rebate and
the `100` threshold, which survive stripping.

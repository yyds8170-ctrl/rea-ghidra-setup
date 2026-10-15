# 04-switch-dispatch

## 目标 / Goal
命令分派：`dispatch(cmd)` 用 `switch(cmd){ case 1..4 }` 跳转到四个子命令函数。
用于验证 Ghidra 能恢复**函数间调用边**与各分支的**特征字符串**。

## 源码讲解
```c
int do_login(void)  { printf("login-menu\n");  return 0; }
int do_buy(void)    { printf("buy-menu\n");    return 0; }
int do_about(void)  { printf("about-menu\n");  return 0; }
int do_exit(void)   { printf("exit-menu\n");   return 0; }

int dispatch(int cmd) {
  switch (cmd) {
    case 1: return do_login();
    case 2: return do_buy();
    case 3: return do_about();
    case 4: return do_exit();
    default: printf("unknown-cmd\n"); return -1;
  }
}
```

## 关键常量 / 特征
| 项 | 值 | 说明 |
|---|---|---|
| 特征字符串 | `login-menu` / `buy-menu` / `about-menu` / `exit-menu` | 字符串表 |
| 调用边 | `dispatch → do_login / do_buy / do_about / do_exit` | calls.json |
| 分派函数 | `dispatch` | 函数表（带符号版） |

> 说明：`-O0` 下 switch 可能被编译为 if-else 链或跳转表；本案例只断言**调用边**，
> 不强求反编译文本里一定出现 `switch` 关键字。

## 编译
```bash
make   # 产物 build/04-switch-dispatch 与 build/04-switch-dispatch-stripped
```

## 预期结果 / 如何断言
- `strings.json` 含四个 `-menu` 特征串。
- 带符号版 `calls.json` 的 callee 集合含 `do_login`/`do_buy`/`do_exit`，`functions.json` 含 `dispatch`。
- strip 版只断言特征字符串（内部 `do_*` 函数名已丢失）。

## English summary
A `switch` dispatcher routing `cmd` 1–4 to `do_login/do_buy/do_about/do_exit`.
Asserts the four feature strings are recovered and that the call edges from `dispatch` to the
sub-commands are present (symbol build only); stripped build still shows the strings.

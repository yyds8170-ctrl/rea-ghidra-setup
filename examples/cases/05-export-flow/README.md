# 05-export-flow

## 目标 / Goal
演示 `ghidra-export --kind all` 的四类导出（functions / strings / symbols / calls）**齐全且可用**。
这是一个含多个 libc 导入（`printf`/`strlen`/`strcmp`/`snprintf`）的最小程序，
用来回归导出管线本身：确保 JSON 非空、且符号表能识别出 libc 导入名。

## 源码讲解
```c
int greet(const char *name) {
  size_t n = strlen(name);
  snprintf(buf, sizeof(buf), "hello:%s", name);
  if (strcmp(name, "admin") == 0) printf("admin-greet len=%zu\n", n);
  else printf("greet: %s\n", buf);
  return 0;
}
```

## 关键证据
| 产物 | 断言 |
|---|---|
| `functions.json` | 非空（实测 ~26） |
| `strings.json` | 非空（实测 ~91，含 `hello:`、`admin-greet`） |
| `calls.json` | 非空（实测 ~19 条边） |
| `symbols.json` | 非空（实测 ~113），且含导入名 `printf`/`strlen`/`strcmp` |

## 编译
```bash
make   # 产物 build/05-export-flow 与 build/05-export-flow-stripped
```

## 预期结果 / 如何断言
- 四个 JSON 均存在且数组长度 ≥ 1。
- `symbols.json` 的 name 集合中能找到 `printf`、`strlen`、`strcmp`（PLT/外部符号在 strip 后仍在）。

## English summary
A minimal program exercising `printf/strlen/strcmp/snprintf`, used to regression-test the
export pipeline itself: all four JSON kinds must be non-empty and the symbol table must
recognize the libc imports.

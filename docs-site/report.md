[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/report/) | 简体中文

# 结构化逆向报告生成器

报告生成器把一个二进制的 Ghidra 分析结果汇成一份**人可读的 Markdown** 和一份**自包含 HTML**（内联极简 CSS、无 CDN、无 JS），便于归档、发给同事或贴进 issue。

## 命令

```bash
# Linux / macOS：单次 headless 同时产出全部 JSON + report.md + report.html
bash scripts/ghidra-report.sh ./examples/demo --out /tmp/report --format both

# 只要 Markdown 或只要数据：
bash scripts/ghidra-report.sh ./examples/demo --out /tmp/report --format md
bash scripts/ghidra-report.sh ./examples/demo --out /tmp/report --format json
```

> 不依赖 REA / Node / npm；脚本会自动定位 Ghidra 与 JDK（可用 `GHIDRA_INSTALL_DIR` / `JAVA_HOME` 覆盖）。

报告产物：

```
/tmp/report/
├── meta.json functions.json strings.json symbols.json calls.json
├── imports.json exports.json constants.json xrefs.json decompiled.json
├── report.md        # 人可读 Markdown
└── report.html      # 自包含 HTML（内联 CSS，无 CDN/JS，离线可开）
```

## 报告包含哪些节

| 节 | 内容 | 数据来源 |
|---|---|---|
| 1. 元信息 | 路径、大小、格式（ELF/PE）、语言 ID、编译器、镜像基址、入口、md5、sha256 | shell 计算 md5/sha256；`getExecutableFormat()` / `getLanguageID()` / `getImageBase()` |
| 2. 段表 | 段名、起止地址、大小、R/W/X 权限位 | `Memory.getBlocks()` |
| 3. 安全特征 | Canary / PIE / stripped 启发式判定 | 段权限 + 导入名（`__stack_chk_fail` 等）；NX/RELRO 提示用 `readelf` 复核 |
| 4. 导入函数 | 外部库与导入函数名、地址 | `ExternalManager.getExternalLocations()` |
| 5. 导出函数 | 全局非外部函数（普通可执行文件常为空，会给出说明） | `FunctionManager` |
| 6. 字符串 | 可打印串（地址 + 内容） | DataIterator 遍历 |
| 7. 关键常量 | 每个函数反编译/指令中的标量（十进制 + 十六进制） | `OperandType.isScalar` / `getScalar()` |
| 8. 交叉引用 | 代码→字符串/导入的引用（`call`/`data`） | `ReferenceManager.getReferencesTo(Address)` |
| 9. 调用关系 | caller → callee 边 | `ReferenceManager` + `getFunctionContaining()` |
| 10. 反编译摘要 | 关键函数的 C 伪代码 | `DecompInterface`（每函数 30s 超时） |

## 示例片段（Markdown）

```markdown
# Reverse Engineering Report — demo

## 1. Metadata
| Field | Value |
|---|---|
| Format | ELF : x86-64 (shared object) |
| Compiler | gcc 13.2 (DWARF: -O0 -g) |
| MD5 | 3f2a…c91b |
| SHA-256 | 9b7e…04d2 |
| Entry | 0x00001060 |

## 3. Security
- NX: enabled (stack segment is RW, not RWE)
- Canary: present (imports __stack_chk_fail)
- PIE: enabled (ET_DYN)
- Stripped: no (symbols present)

## 6. Strings
| Address | Value |
|---|---|
| 0x00002004 | "Usage: %s <password>\n" |
| 0x0000201c | "Access granted\n" |
| 0x0000202c | "Wrong password\n" |
```

## 设计原则

- **零第三方依赖**：报告生成器只依赖 JDK 与 Ghidra 自带类；手写 JSON 转义，不引入 gson。
- **离线友好**：HTML 内联 CSS，不引用任何 CDN 字体/JS/图标；拷贝到内网也能开。
- **CI 可控**：`-analysisTimeoutPerFile 300`、独立临时工程目录、`-deleteProject`，跑完不残留。
- **断言与地址解耦**：报告里同时给出十进制与 `0x` 形式的地址/常量，便于后续断言脚本两种形态都搜。

> 报告生成器由 `scripts/ghidra-report.sh`（配合 Ghidra 脚本 `scripts/ghidra/ExportReport.java`）实现：
> [scripts/ tree](https://github.com/yyds8170-ctrl/rea-ghidra-setup/tree/main/scripts)。

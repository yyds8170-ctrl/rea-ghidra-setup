[English](batch.en.md) | 简体中文

# 批量并行分析 + 快照缓存（v2.8）

在 v2.7「单目标导出」（[export.md](export.md)）之上，对**一批二进制**做并行编排：更快、可断点续跑、失败隔离、按内容缓存。不依赖 REA / Node。

## 快速用法

```bash
# 位置参数给多个二进制
scripts/batch-analyze.sh a.elf b.elf c.elf --out ./batch-out --kind functions --jobs 3

# 或按目录收集（--recurse 递归，--pattern glob 过滤）
scripts/batch-analyze.sh --dir ./bins --recurse --pattern '*.elf' --kind all \
  --jobs 4 --snapshot ./cache
```

Windows：`pwsh -File scripts/batch-analyze.ps1 -Bin a.elf,b.elf -Out .\batch-out -Kind functions -Jobs 3`。

## 参数

| 参数 | 说明 |
|---|---|
| `--out DIR` | 输出根目录（默认 `./batch-out`） |
| `--kind` | `functions\|strings\|symbols\|calls\|decompiled\|all`（透传给 ghidra-export，默认 all） |
| `--jobs N` | 并行数；默认 CPU 数（Linux `nproc`/macOS `sysctl -n hw.ncpu`）封顶 4，且不超过目标数 |
| `--retries M` | 单目标失败重试次数（默认 1，只重跑该目标） |
| `--snapshot DIR` | 快照缓存目录；不传则不缓存 |
| `--continue` | 已有完整产物的目标跳过 |
| `--dir/--recurse/--pattern` | 目录收集 |

## 并行模型

- bash：`xargs -0 -P $JOBS -I{}`，每个目标作为子进程调 `ghidra-export.sh`，结果写各自的 `.results/<sha12>.json`（**绝不并行写同一文件**），主进程最后汇总。
- PS：`Start-Job` + 节流等待（一个代码路径通吃 PS5.1/7，不用 7 专属的 `ForEach-Object -Parallel`）。
- 每个目标用独立临时 Ghidra 工程（ghidra-export 内 `mktemp -d` + trap 清理），互不干扰。

## 失败隔离与重试

单个目标失败不影响其它目标继续；按 `--retries` 只重跑该目标。全部跑完后才在 `--out/summary.json` 汇总；退出码：全部成功=0，**有失败=1**（不提前退出）。

## 快照缓存

缓存键 = `<二进制 sha256>_<kind>_v<EXPORT_SCHEMA_VERSION>`。
- 命中：跳过 analyzeHeadless，直接把缓存产物还原到该目标输出目录，summary 标记 `cached:true`。
- 未命中：正常分析并写缓存。
- 失效条件：二进制内容变化（sha 变）、kind 变化、或 bump `EXPORT_SCHEMA_VERSION`（v2.7 导出脚本/schema 变化时改这个常量即可让旧缓存自动失效）。
- 实测：3 个小目标首次 ~48s，二次同 snapshot **1s、3/3 全命中**。

## summary.json schema

```json
{
  "export_schema_version": 1,
  "total": 3, "success": 3, "failed": 0, "skipped": 0, "cached": 3,
  "total_elapsed_sec": 1,
  "targets": [
    {"input":"/path/a","sha256":"...","status":"success","cached":true,
     "elapsed_sec":0,"retries":0,"out_dir":".../targets/<sha12>","error":""}
  ]
}
```

## 性能建议

- `--jobs` 每个并发 analyzeHeadless 是一个 JVM（默认约 2G 堆），内存是瓶颈；按 runner 内存估（16G 跑 3~4 路）。
- CI 上用 `--kind functions`（单类，analyzeHeadless 单目标更快）控时；全量 `all` 留给本机。
- 重复跑同一批（回归、调脚本）务必带 `--snapshot`，二次起几乎零成本。

## 回归

```bash
bash scripts/selftest-batch.sh   # 3 目标首次成功 → 二次全命中缓存 → 失败隔离断言
```

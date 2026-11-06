[English](benchmark.en.md) | 简体中文

# 性能基准（可复现）

> 本页所有数字均为**本机真实实测**（非估算），测量时间 2026-11-06。
> 测量对象是本仓库自带的 `scripts/ghidra-report.sh` / `scripts/ghidra-export.sh` /
> `scripts/batch-analyze.sh` 走的 Ghidra 原生 `analyzeHeadless` headless 管线；
> 不依赖 REA / Node 运行时。重日志存放在 worktree 外的临时目录，不提交。

## 1. 测量环境（固定）

| 项 | 值 |
|---|---|
| 操作系统 | Ubuntu 22.04.5 LTS x86_64（云主机 / VM，`uname -srm` = Linux 6.6 x86_64） |
| CPU | 4 vCPU（`nproc` = 4） |
| 内存 | 总 8128 MB，测量时可用约 7.3 GB，**swap = 0** |
| Ghidra | 12.1.4（`ghidra_12.1.4_PUBLIC`，current-ghidra 软链指向） |
| JDK | Temurin 21（`jdk-21.0.12.1+1`，current-jdk） |
| 便携 Node / REA | Node 24.22.2 / rea-agents 6.8.0（批量/导出场景不调用） |
| JVM 堆 | analyzeHeadless 默认 `-Xmx` 2G（未设 `GHIDRA_HEADLESS_MAXMEM`） |

> 版本均来自 `config/versions.env`，不在本页硬编码。

## 2. 被测目标（确定性构造）

| 目标 | 大小 | 函数数 | 构造方式 |
|---|---:|---:|---|
| `examples/demo` | 17,928 B ELF (PIE, debug, not stripped) | 21 | `make -C examples`（gcc -O0 -g） |
| `t00`（单目标大样本） | 159,536 B ELF | 617 | gcc -O0 -g，600 个算术函数 + 函数指针表 |
| `t00`…`t07`（8 个并行样本） | 各 159,536 B ELF | 各 617 | 同上，仅 `const char *TARGET` 字符串不同 → sha256 互异、单目标分析代价相同 |

## 3. 单目标重复（`scripts/benchmark.sh`）

对 `examples/demo` 连续 3 次、每次全新临时工程（`-deleteProject`，无缓存复用）：

| 指标 | min | median | max |
|---|---:|---:|---:|
| 端到端墙钟（JVM 启动 + 导入 + 分析 + 导出 JSON） | 30.17 s | 30.50 s | 30.71 s |
| Ghidra 自动分析阶段（日志 `Total Time`） | 5 s | 5 s | 5 s |

- **波动范围**：墙钟极差 0.54 s（约 ±0.9% 围绕中位数），分析阶段稳定 5 s。
- 大头是 JVM 冷启动 + 导入 + 反编译导出（约 25 s），Ghidra 自动分析本身仅 5 s。

大样本单目标对比（`ghidra-export.sh --kind all`，单次）：

| 目标 | 墙钟 | Ghidra `Total Time` |
|---|---:|---:|
| `examples/demo`（18 KB / 21 函数） | 33.9 s | 5 s |
| `t00`（159 KB / 617 函数） | 39.9 s | 9 s |

→ 函数数 21 → 617（约 29×），分析阶段 5 s → 9 s；墙钟增量主要仍是固定的 JVM 启动开销。

## 4. 并行 jobs 对比（8 个等代价目标，冷跑、无快照）

`batch-analyze.sh --kind functions`，目标数 N=8，每次全新 out 目录（无缓存）：

| `--jobs` | 总耗时 | 单目标耗时区间 | 相对 jobs=1 提速 |
|---:|---:|---|---:|
| 1 | 282 s | 32 – 42 s | 1.00× |
| 2 | 233 s | 47 – 76 s | 1.21× |
| 4 | 214 s | 96 – 117 s | 1.32× |

**结论（本机 8 GB）**：并行**不是近线性扩展**。jobs 1→2 有收益（−49 s），2→4 几乎不再缩短（−19 s），
且单目标墙钟随并发数显著变长（~37 s → ~105 s）。原因是每个并发 `analyzeHeadless` 是一个
约 2 G 堆的 JVM，4 路 ≈ 8 G 堆 + RSS 已逼近 8 GB 物理内存且无 swap，发生内存竞争。
这与 `docs/batch.md`「16 G 跑 3~4 路、内存是瓶颈」一致——**8 GB 机器建议 `--jobs 2` 为宜**。

## 5. 快照缓存：冷 vs 热（8 目标，`--jobs 4`，`--kind functions`）

| 阶段 | 总耗时 | 缓存命中 | 说明 |
|---|---:|---:|---|
| 冷跑（写快照 `--snapshot`） | 219 s | 0 / 8 | 首次真实 analyzeHeadless 分析并落盘缓存 |
| 热跑（同快照、全新 out 目录） | **1 s（实测墙钟 0.56 s）** | **8 / 8** | 跳过分析，直接 `cp` 缓存的 JSON 产物 |

→ 二次同快照约 **219×** 提速、8/8 全命中。与 `docs/batch.md`「二次同 snapshot ~1 s 全命中」一致。
缓存键 = `<二进制 sha256>_<kind>_v1`，内容/kind/schema 任一变化即失效。

## 6. 可复现命令

```bash
# 前置：JDK21 + Ghidra 已装（./rea-ghidra current 应指向 ghidra_12.1.4_PUBLIC）
cd <repo>

# (a) 单目标重复（本页第 3 节）：30s 级 × 3 ≈ 90s
bash scripts/benchmark.sh examples/demo --runs 3 --out /tmp/bench-demo

# (b) 确定性构造 8 个等代价目标（gcc -O0 -g；目录自行选）
mkdir -p /tmp/bt/src /tmp/bt/targets
for k in 0 1 2 3 4 5 6 7; do
  { echo '#include <stdio.h>'; echo "const char *TARGET=\"t0$k\";"
    for i in $(seq 1 600); do
      echo "static int fn_$i(int x){ int r=x*$i+($i%97); r=(r^(r>>3))*($i|1); return r&0xffff; }"
    done
    echo "static int (*const tbl[])(int)={"
    for i in $(seq 1 600); do echo "fn_$i,"; done
    echo "}; int (*f)(int); int main(void){ long s=0;"
    echo "  for(int i=0;i<600;i++){ f=tbl[i]; s+=f(i); }"
    echo '  printf("%s %ld\n", TARGET, s); return (int)(s&0xff); }'
  } > /tmp/bt/src/t0$k.c
  gcc -O0 -g -o /tmp/bt/targets/t0$k /tmp/bt/src/t0$k.c
done

# (c) 并行 jobs 扫描（冷跑，分别计时；每次换新 out）
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/j1 --kind functions --jobs 1
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/j2 --kind functions --jobs 2
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/j4 --kind functions --jobs 4
# 各次总耗时见该次末尾 "[batch] 完成：... 总耗时 Ns" 或 out/summary.json 的 total_elapsed_sec

# (d) 缓存冷 vs 热
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/cold --kind functions --jobs 4 --snapshot /tmp/bt/snap
bash scripts/batch-analyze.sh --dir /tmp/bt/targets --out /tmp/bt/warm --kind functions --jobs 4 --snapshot /tmp/bt/snap
# 热跑 summary.json 中 cached 应 = 8

# 链接自检
bash scripts/check-docs-links.sh
```

## 7. 复现注意事项与波动

- **顺序跑、别争抢**：每次只跑一批测量；并行批内部由脚本用 `xargs -P` 管理 JVM。
  与其它重进程同机会拉长墙钟。
- **机器规格主导结论**：第 4 节的「非近线性」是 8 GB / swap=0 的观测；在 16 GB+ 机器上
  `--jobs 4` 会更接近线性。换机器需重测，不要外推。
- **波动**：单目标墙钟 ±约 1–2 s；并行总耗时受系统负载影响约 ±10%。结论性数字（1.32×、缓存 219×）
  在本环境稳定复现，不依赖单次偶然。
- **不可在本环境实测项**：macOS/Windows、多架构交叉 fixture、needs-device/needs-macos/needs-jeb 场景
  未纳入本基准（见 `docs/release-validation.md`）。

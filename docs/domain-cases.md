# 领域案例自动化断言（v5.6.0）

> 把能力地图里"✅ 本机可实测 / 🔧 需安装工具"的命令，从"文档标注"变成**CI 里真实跑通并断言**的自动化案例。
> 运行器：[`scripts/run-domain-cases.sh`](../scripts/run-domain-cases.sh)；样本生成器：[`scripts/build-domain-fixtures.sh`](../scripts/build-domain-fixtures.sh)。
> 对应 CI 作业：`.github/workflows/ci.yml` 的 `domain-cases`（仅 schedule / workflow_dispatch 触发）。

## 设计原则

- **只在 Linux 上真实跑**：不碰 Android 真机 / JEB / macOS / docker。凡前置不可得的命令一律**显式 skip 并打印原因**，绝不把 needs-device / needs-macos / needs-jeb 写成已测。
- **断言口径**：成功必须 rea-wrap 退出 0 且 JSON 含预期字段（`architecture` / `procedure_count` / `string_count` / `segment_count` 或对应 inspect 结构）；非 0 退出即 failed。
- **skip 口径**：工具/样本/运行时版本轮廓缺失时计 skipped，不阻断作业（CI 只要求 `failed=0`）。

## 样本（gitignored 产物，源文件入库）

生成器 `scripts/build-domain-fixtures.sh` 产出到 `examples/domain-fixtures/`（gitignore）：

| 样本 | 生成方式 | 对应命令 |
|---|---|---|
| `sample.pyc` | `py_compile` 编译 [`sample.py`](../examples/domain-fixtures_src/sample.py)（含 `DOMFIX-2026` 常量、`greet`/`Counter`） | `inspect-python-pyc` |
| `sample.db` | stdlib sqlite3 建表 `items`/`meta` 并插行 | `inspect-sqlite-database` |
| `sample.pcap` | Python `struct` 拼 libpcap 头 + 1 个以太/IP/TCP 包 | `inspect-pcap-capture` / `inspect-pcap-client` |
| `add.wasm` / `sub.wasm` | `wat2wasm` 编译 [`add.wat`](../examples/domain-fixtures_src/add.wat) / [`sub.wat`](../examples/domain-fixtures_src/sub.wat)（导出接口不同） | `inspect-wasm-artifact` / `compare-wasm-interfaces` |
| `linux_x86_64` ELF | 复用 [`build-fixtures.sh`](../scripts/build-fixtures.sh) 产物 `examples/fixtures/` | objdump / pwntools / gdb / rizin / 静态内置命令 |

## 覆盖命令与前置轮廓

| REA 命令 | 领域 | 前置（缺失即 skip） | 断言字段 |
|---|---|---|---|
| `inspect-python-pyc` | ⑦ 多格式 | python3（内置） | header.python_version=3.x、code_objects names 含 greet、常量含 DOMFIX-2026 |
| `inspect-sqlite-database` | ⑦ 多格式 | **Node ≥ 24.15**（REA sqlite provider 要求） | normalized_result 非空、含表 items |
| `inspect-wasm-artifact` | ⑦ 多格式 | **REA_WABT_BIN_DIRECTORY 指向 WABT 1.0.42** | validation=valid、导出含 add |
| `compare-wasm-interfaces` | ⑦ 多格式 | 同上（两份 inspect Evidence 拼 left/right/scope） | scope=exports、changes 非空 |
| `inspect-pcap-client` | ⑦ 多格式 | **Wireshark tshark/capinfos 4.x** | Evidence 信封、提及 tshark |
| `inspect-pcap-capture` | ⑦ 多格式 | 同上 + sample.pcap | normalized_result 非空 |
| `inspect-with-objdump` | ② 离线二进制 | binutils objdump | raw stdout 含 elf64-x86-64 |
| `list-objdump-architectures` | ② 离线二进制 | binutils objdump | raw stdout 含 elf64-x86-64 |
| `inspect-binary-layout` | ② 离线二进制 | **REA_PWNTOOLS_PYTHON 钉死 pwntools4.15.0/pyelftools0.33/unicorn2.1.2** | architecture.bits=64、sections 非空 |
| `debug-with-gdb` | ③ 动态 | gdb + 一个 pty 作 --inferior-tty | MI records 含 GNU gdb 版本横幅 |
| `execute-rizin-command` | ③ 动态 | rizin | Evidence 信封 |
| `debug-with-rizin` | ③ 动态 | rizin | Evidence 信封 |
| `inspect-artifact` | ② 离线二进制 | 内置 | observations 非空 |
| `inspect-byte-entropy` | ② 离线二进制 | 内置 | file_entropy ∈ [0,8] |
| `inspect-elf-notes` | ② 离线二进制 | 内置 | machine=62 (EM_X86_64) |
| `capabilities` | ⑩ 平台自检 | 内置 | capabilities 非空数组 |

## 与能力地图可测性的对应

- 表中"前置"列即能力地图里 🔧（需安装工具）的具体轮廓；本机/CI 装上对应版本后即从"未实测"转为自动化 PASS。
- 📱 needs-device（adb/frida/浏览器/存活 UI）、🍎 needs-macos、💼 needs-jeb 的命令**不在本表**，仍保持能力地图里"未实测"标注，不冒充实测。
- `list-architectures` 在 TSV 标 linux-testable，但实际走 macOS Hopper 原生工具，Linux 上 unsupported_host，故不纳入。

## 本机运行

```bash
export PATH=/opt/nodejs/22/bin:$PATH
bash scripts/build-fixtures.sh          # 产出 examples/fixtures/linux_x86_64
bash scripts/build-domain-fixtures.sh   # 产出 examples/domain-fixtures/
# 按需提供钉死版本轮廓（缺哪个对应案例就 skip）：
export REA_WABT_BIN_DIRECTORY=/path/to/wabt-1.0.42/bin
export REA_PWNTOOLS_PYTHON=/path/to/venv-with-pwntools4.15.0/bin/python
bash scripts/run-domain-cases.sh
```

## CI 作业设计（domain-cases）

- 触发：`schedule` / `workflow_dispatch`（与 fixture-multiarch 同）。
- runner：`ubuntu-latest`（24.04 自带 Wireshark 4.x）。
- Node **24**（sqlite provider 需要）；apt 装 binutils/gdb/tshark/rizin（单项失败不阻断）；
  官方 release 拉 **WABT 1.0.42** 解到 `~/.local/wabt-1.0.42`；venv 装钉死版 pwntools 三件套到 `/opt/rea-pwntools-env`。
- 不依赖 Ghidra/JDK（全部为非 d1-core-native 命令），比 e2e 轻。
- 末尾要求 `汇总：passed=N failed=0 skipped=M`。

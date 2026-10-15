# 退出码与机器可读错误输出

本项目所有 bash 脚本（`install.sh` / `install-macos.sh` / `scripts/ghidra-export.sh` /
`scripts/batch-analyze.sh` / `scripts/doctor.sh` 等）使用统一的命名退出码。
错误信息同时给出两种形态：

- **人类可读**：`[ERR] 消息` 行，照旧打到 stderr；
- **机器可读**：当 stderr 不是 TTY（CI / 管道 / 重定向）时，额外在 stderr 输出一行
  JSON envelope，供上层脚本与 CI 解析。

## 退出码表

| 退出码 | 常量名 | 含义 | 典型触发场景 |
| --- | --- | --- | --- |
| `0` | `RC_OK` | 成功 | 正常结束、`--help` / `--dry-run` 成功、诊断全部通过 |
| `1` | （未归类） | 未归类错误（历史兼容） | 旧代码路径；`die <msg>` 内部即 `fatal 1`。新代码请改用命名码 |
| `2` | `RC_USAGE` | 用法 / 参数错误 | 未知参数、缺少目标 / 多余目标、`--out` / `--kind` 缺值、参数取值非法 |
| `10` | `RC_DEPENDENCY` | 缺少本地依赖 | 缺少 curl / unzip / tar；未找到 JDK21 / Ghidra / 满足版本要求的 Node；缺少版本文件 `config/versions.env`（安装包不完整） |
| `11` | `RC_CHECKSUM` | 校验和校验失败 | 下载物 SHA-256 与上游（或离线清单 `SHA256SUMS.txt`）不一致，文件被删除并中止 |
| `12` | `RC_UPSTREAM` | 上游 / 资源不可用，或环境不匹配 | 下载失败、URL 不可达、目标二进制不存在、CPU 架构不受支持、在 Linux 上运行 `install-macos.sh`、JDK 解压后未找到 java 二进制（上游包损坏） |
| `13` | `RC_DISK` | 磁盘空间不足 | `$TOOLS_DIR` 或临时目录可用空间低于安装所需阈值 |

> 设计约定：**用法错误 = 2**；**本机环境缺东西 = 10**；**网络/上游资源问题 = 12**；
> **磁盘 = 13**；**校验和 = 11**。架构不支持属于环境问题，统一归到 12，不归 2。

## JSON envelope 格式

当 stderr 非 TTY 时，`fatal <rc> <msg>` 在 `[ERR]` 人类行之后额外输出一行：

```json
{"error": {"code": 10, "name": "RC_DEPENDENCY", "message": "未找到 Ghidra（设 GHIDRA_INSTALL_DIR 或先跑 install.sh）", "tool": "ghidra-export.sh"}}
```

字段说明：

- `code`：数字退出码（与进程退出码一致）；
- `name`：命名常量（`RC_USAGE` / `RC_DEPENDENCY` / `RC_CHECKSUM` / `RC_UPSTREAM` / `RC_DISK`；未归类 1 记为 `RC_UNCLASSIFIED`）；
- `message`：原始错误消息（可含中文/引号/特殊字符，由 `python3 json.dumps` 转义，任意消息安全）；
- `tool`：出错脚本的 basename（如 `install.sh`）。

stderr 为 TTY（人在终端里跑）时**不输出** JSON 行，保持人类可读输出干净。

## 如何被 CI / 脚本消费

CI 步骤（`.github/workflows/ci.yml` 的 `lint-build`）示例：

```bash
bash install.sh --no-such-flag >/dev/null 2>/tmp/e.txt; rc=$?
[ "$rc" -eq 2 ] || exit 1
python3 - /tmp/e.txt <<'PY'
import json, sys
lines = [l for l in open(sys.argv[1], encoding='utf-8') if l.strip().startswith('{')]
env = json.loads(lines[-1])
assert env['error']['code'] == 2 and env['error']['name'] == 'RC_USAGE'
PY
```

上层编排脚本（如 MCP server、自动化测试）可据此按 `code` 分支处理：
10 提示用户"先跑 install.sh"，12 提示网络/镜像问题，11 提示校验和失败需重跑，13 提示清理磁盘。

## 各脚本的语义说明

- **`scripts/doctor.sh`**：语义是「诊断报告」——退出码 0 = 全部通过、1 = 存在 FAIL 项，
  该语义**保持不变**；其内部错误（如缺版本文件）走命名码。不要把它的退出码当作
  "命令失败"来处理。
- **`scripts/batch-analyze.sh`**：worker 分支（`--worker`）永远 exit 0，结果写
  `.results/<sha12>.json`，失败隔离是设计如此；主模式末尾按失败数 `sys.exit(1 if fail else 0)`
  也是批量语义，均不改。仅用法错误（未收集到目标、未知参数）走 `RC_USAGE=2`。
- **`uninstall.sh` / `verify.sh` / `scripts/run-cases.sh`**：仅"用法错误"走 2，
  其余历史退出语义（如 verify.sh 的 `0=全过 / 1=有失败`）保持现状。
- **`lib/exitcodes.sh`** 只被 source，不直接执行；`die <msg>` 保留为 `fatal 1` 的别名，
  历史调用方无需改动。

## 如何触发各命名码（本地复现）

| 码 | 复现命令 |
| --- | --- |
| 2 | `bash install.sh --no-such-flag`；`bash scripts/ghidra-export.sh`（无目标） |
| 10 | `TOOLS_DIR=/nonexistent GHIDRA_INSTALL_DIR= JAVA_HOME= bash scripts/ghidra-export.sh examples/demo`；PATH 中去掉 curl 后跑 `bash install.sh` |
| 11 | 构造一个哈希与 `SHA256SUMS.txt` 不符的离线包后 `OFFLINE_DIR=... bash install.sh`（正常链路由 `scripts/selfcheck-checksums.sh` 守护） |
| 12 | `bash scripts/ghidra-export.sh /不存在/文件`；在 Linux 上跑 `bash install-macos.sh` |
| 13 | 真实模拟需填满磁盘；代码路径为 install 前置磁盘检查直接 `fatal "$RC_DISK"` |

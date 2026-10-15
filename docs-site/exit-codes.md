[English](https://yyds8170-ctrl.github.io/rea-ghidra-setup/en/exit-codes/) | 简体中文

# 退出码与机器可读错误输出

本项目 bash 脚本（`install.sh` / `install-macos.sh` / `scripts/ghidra-export.sh` /
`scripts/batch-analyze.sh` / `scripts/doctor.sh` 等）使用统一的命名退出码。
错误信息有两种形态：人类可读的 `[ERR]` 行照旧打到 stderr；当 stderr 不是 TTY
（CI / 管道 / 重定向）时，额外输出一行 JSON envelope 供上层脚本与 CI 解析。

## 退出码表

| 退出码 | 常量名 | 含义 | 典型触发场景 |
| --- | --- | --- | --- |
| `0` | `RC_OK` | 成功 | 正常结束、`--help` / `--dry-run`、诊断全部通过 |
| `1` | （未归类） | 历史兼容 | 旧代码路径；`die <msg>` 即 `fatal 1`。新代码请用命名码 |
| `2` | `RC_USAGE` | 用法 / 参数错误 | 未知参数、缺少/多余目标、`--out` / `--kind` 缺值 |
| `10` | `RC_DEPENDENCY` | 缺少本地依赖 | 缺 curl/unzip/tar；未找到 JDK21 / Ghidra / 满足版本的 Node；缺版本文件 |
| `11` | `RC_CHECKSUM` | 校验和失败 | 下载物 SHA-256 与上游/离线清单不一致，删除并中止 |
| `12` | `RC_UPSTREAM` | 上游/资源不可用，或环境不匹配 | 下载失败、URL 不可达、目标二进制不存在、CPU 架构不支持、Linux 上跑 install-macos.sh |
| `13` | `RC_DISK` | 磁盘空间不足 | 安装目录或临时目录可用空间低于阈值 |

## JSON envelope 示例

```json
{"error": {"code": 10, "name": "RC_DEPENDENCY", "message": "未找到 Ghidra（设 GHIDRA_INSTALL_DIR 或先跑 install.sh）", "tool": "ghidra-export.sh"}}
```

`code` 与进程退出码一致；`message` 可含中文/引号，由 `python3 json.dumps` 转义；
`tool` 为出错脚本 basename。TTY 下不输出 JSON 行，保持终端干净。

## CI / 上层脚本消费示例

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

## 各脚本语义说明

- `scripts/doctor.sh`：诊断报告语义不变（0=全部通过 / 1=存在 FAIL），不要当作"命令失败"。
- `scripts/batch-analyze.sh`：worker 永远 exit 0、失败写 `.results/*.json`（设计如此）；
  仅用法错误走 `RC_USAGE=2`。
- `uninstall.sh` / `verify.sh` / `scripts/run-cases.sh`：仅用法错误走 2，其余历史语义保持现状。

详细版见
[docs/exit-codes.md](https://github.com/yyds8170-ctrl/rea-ghidra-setup/blob/main/docs/exit-codes.md)。

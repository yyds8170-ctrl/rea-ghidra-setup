# tests/ — 可复现测试体系（离线、零外部框架）

统一入口：

```bash
bash tests/run.sh            # 跑 bash + python + shellcheck 静态门
TESTS_LOG_DIR=/tmp/x bash tests/run.sh   # 自定义日志目录
```

不联网、不依赖 Ghidra/Node/JDK 二进制、不依赖 bats/pytest（bash 自带断言 + python3 stdlib unittest）。

## 结构

| 文件 | 覆盖对象 |
|---|---|
| `harness.sh` | 零依赖断言小框架（PASS/FAIL 计数） |
| `test_exitcodes.sh` | `lib/exitcodes.sh`：RC_* 常量、fatal 退出码、非 TTY JSON envelope、die 兼容 |
| `test_args.sh` | `lib/args.sh`：参数解析、开关透传、未知参数/缺值 -> RC_USAGE(2) |
| `test_checksums.sh` | `lib/checksums.sh`：cs_sha256 / cs_manifest_sha / cs_verify（调用原文件，不改它） |
| `test_mirrors.sh` | `lib/mirrors.sh`：rea_mode 短路与 auto 降级（假 curl 模拟断网）、候选 URL 顺序、npm registry 注入 |
| `test_install_lock.sh` | `lib/install-lock.sh`：拿/放锁、死锁接管、活锁 RC_BUSY(14)、半成品自愈 |
| `test_common_pure.sh` | `lib/common.sh`：URL/命名派生、normalize_arch、load_versions |
| `python/test_audit_collect_drift.py` | `scripts/audit_collect_drift.py`：parse_ver_tuple / semver_level / extract_commands / load_versions / find_baseline / probe_*（mock http，离线） |

## 供应链

- `scripts/gen-sbom.sh`：可复现生成 `packaging/rea-ghidra-setup.spdx.json`（SPDX 2.3）。
  命令：`OFFLINE_DIR=/abs/offline bash scripts/gen-sbom.sh`
- `scripts/verify-integrity.sh`：核对离线工件 SHA-256 与清单一致、版本漂移检测。
  命令：`OFFLINE_DIR=/abs/offline bash scripts/verify-integrity.sh`

> 已知缺陷（未在本仓库修复，见提交说明）：`semver_level` 按位比较，upstream minor 降而 patch 升时会误报 patch 漂移；
> `test_older_upstream_current_known_behavior` 钉住现状，待上游修复后翻转提醒。

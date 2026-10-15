# 里程碑状态

本页记录本迭代周期内各版本的发布状态：版本 / tag / commit / CI / Release 资产 / 验证摘要。
数字均来自实跑记录，不做估算。

## 版本发布总表

| 版本 | tag | commit | CI（全量 9 作业） | Release 资产（tar.gz / checksums / spdx） | 主题 |
| --- | --- | --- | --- | --- | --- |
| v4.1.0 | `v4.1.0` | `b35e433` | 9/9 绿 | 408828 / 97 / 27642 字节 | 命名退出码体系 + 机器可读 JSON 错误 envelope |
| v4.2.0 | `v4.2.0` | `34ff293` | 9/9 绿 | 414275 / 97 / 27642 字节 | 安装原子锁 + 半成品自愈 + CI 缓存兜底 |
| v4.3.0 | `v4.3.0` | `9465577` | 9/9 绿 | 417267 / 97 / 27642 字节 | NUL 安全收集 + WSL /mnt 提示 + 上游漂移巡检 |
| v5.0.0 | `v5.0.0` | 见提交记录 | 9/9 绿 | 见 Release | 收官：全量同步 + 最终体检 |

## 每版验证摘要

- **v4.1.0**：verify 9/9；run-cases 10 二进制 55 断言 0 失败；死链 0；mkdocs strict 通过；退出码人工核验 2/10/11/12 与 JSON envelope 正确。
- **v4.2.0**：真实 install.sh 拿锁→组件幂等命中→完成 exit 0→锁自动清理；selftest-install-lock 7/7；shellcheck -x 0；bash3.2 紧邻零匹配。
- **v4.3.0**：selftest-batch 4/4；含换行文件名计 1 目标；selftest-install-lock 7/7；check-versions 通过（Ghidra 12.1.4 / rea-agents 6.5.0 / Node 24.22.0 与上游持平）。

## 仍做不到 / 未实机 / 未授权项（风险清单）

- **Windows 实机**：本机仅 Linux；Windows 行为靠 GitHub Actions `windows-latest` runner 实测（e2e-windows / verify.ps1）。
- **macOS 实机**：靠 `macos-latest` runner（Apple Silicon arm64，含 native 构建）实测。
- **真实大文件破坏 / 填满磁盘模拟**：RC_CHECKSUM=11 用 tampered 离线包单测验证映射；RC_DISK=13 走通 fatal 公共路径，未真实填盘。
- **Dockerfile 实机构建**：本机无 docker，靠 CI `docker` / `docker-arm64` 作业（build 后容器内跑 verify.sh）。
- **GHA action 升级**：巡检发现本地 pin（checkout@v4 等）落后上游 major，按"不盲目升级"原则列报告 WARN，未自动 bump。
- **GHCR 镜像 / 外部注册表**：按硬约束未发布；镜像仅在 CI 内 build 后 `docker run` 验证，不推送。

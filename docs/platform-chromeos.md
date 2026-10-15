# ChromeOS 平台部署指南（Linux 开发环境 / Crostini）

> **结论先行**：ChromeOS 本体**不能**直接运行 JDK / Ghidra / Node；唯一受支持的官方途径是
> **Linux 开发环境（Crostini）**——它是一个运行在轻量虚拟机里的 Debian 容器。进入该容器后，
> 安装流程与普通 Linux 完全一致，直接复用 [`install.sh`](../install.sh)。

## 一、支持矩阵（ChromeOS）

| 形态 | 能否运行 | 说明 |
| --- | --- | --- |
| ChromeOS 本体（直接装 JDK/Ghidra） | ❌ 不支持 | 无传统 Linux 运行时，不能直接跑 |
| **x86_64 Chromebook + Crostini** | ✅ 完整支持 | 等同普通 Linux x64，`linux_x86_64` native 官方预编译 |
| **ARM64 Chromebook + Crostini** | 🟠 部分支持 | 容器为 aarch64，需从源码构建 `linux_arm_64` native decompiler（安装器自动处理） |
| Crostini 内再装 Docker | ✅ 支持 | 可在容器内安装 Docker（无 KVM 加速，性能受限） |
| 在 Crostini 里再开虚拟机（嵌套虚拟化） | ❌ 一般不支持 | 仅少数设备为 Android 模拟器开了嵌套虚拟化；VirtualBox 不可用 |

> ChromeOS 没有对应的 CI runner，本项目的 ChromeOS 路径**无法在 GitHub Actions 中实跑**，
> 仅做文档化与脚本侧自动识别；`detect-env.sh` 会在 Crostini 中正确报告环境。

## 二、打开 Linux 开发环境（Crostini）

1. 设置 → 高级 → 开发者（或「开发者」）→ **Linux 开发环境** → **打开/启用**；
2. 按提示创建 Linux 用户名、分配磁盘，系统会自动下载并安装一个 **Debian** 容器（当前为 Debian 12 bookworm）；
3. 完成后启动器里出现 **Terminal** 应用，打开即是 Debian 容器的 shell（默认用户有 `sudo` 权限）。

> 该过程**不需要开启「开发者模式」**（保持普通验证模式即可）。

### 磁盘与内存

- 默认 Linux 磁盘约 10GB、动态分配。JDK + Ghidra 解压后约 1.5GB、安装包约 0.8GB，
  建议把 Linux 磁盘调到 **15–20GB**：设置 → 关于 ChromeOS → Linux 开发环境 → **磁盘大小** → 调整。
- 内存建议给 Crostini 至少 4GB（设置里可调整 Linux 内存；低内存机器请用 `GHIDRA_HEADLESS_MAXMEM=512M`）。

### 与 ChromeOS 交换文件

- ChromeOS 的「文件」应用中会出现 **Linux files**；
- 要把下载目录/Google Drive 中的目标二进制给容器分析，右键文件夹 → **与 Linux 共享**，
  容器内挂载在 `/mnt/chromeos`（`/mnt/chromeos/MyFiles`、`/mnt/chromeos/GoogleDrive/...`）。

## 三、在容器里确认环境

先确认容器架构与运行环境（决定 native 是否需要构建）：

```bash
git clone https://github.com/yyds8170-ctrl/rea-ghidra-setup.git
cd rea-ghidra-setup
bash scripts/detect-env.sh
```

- x86_64 设备应显示：`CPU 架构: x64`、`Ghidra 平台: linux_x86_64`、`native: 官方预编译`；
- ARM 设备应显示：`CPU 架构: aarch64`、`Ghidra 平台: linux_arm_64`、`native: 需自建`。

也可以用 `uname -m` 直接确认：x86_64 设备输出 `x86_64`，ARM 设备输出 `aarch64`。

## 四、一键安装（在 Crostini 内，等同 Linux）

```bash
# Debian 容器默认是最小化的，先装基础工具（Crostini 默认可 sudo）
sudo apt update
sudo apt install -y curl unzip tar make gcc build-essential

# 运行本项目安装脚本（与普通 Linux 完全相同）
bash install.sh
source ~/.bashrc

# 端到端验证
bash verify.sh
```

安装器会自动：

- 识别出 `ChromeOS Crostini（Linux 开发环境）` 环境；
- 下载 Temurin JDK 21、Ghidra（x86_64 用官方预编译 native）；
- **在 ARM64 设备上**：下载 aarch64 JDK，并调用 [`scripts/build-ghidra-native.sh`](../scripts/build-ghidra-native.sh)
  用 `make ghidra_opt` 构建 `os/linux_arm_64/decompile`（需要 `build-essential`、`bison`）：
  ```bash
  sudo apt install -y build-essential bison
  ```
- Node 不满足 REA 要求时自动装便携 Node 24.22.0。

> 因为 `analyzeHeadless` 是纯命令行、不需要 GUI，Crostini 里跑 headless 分析是最顺的用法，
> 不依赖 Wayland/X 转发。

## 五、在 Crostini 内运行 Docker（可选）

官方明确支持在 Crostini 容器里运行 Docker：

```bash
sudo apt install -y docker.io
sudo usermod -aG docker "$USER"   # 重新登录终端后生效
# 回到项目目录
docker build -t rea-ghidra .
docker run --rm -v "$PWD:/workspace" rea-ghidra analyze ./demo --provider ghidra --format json
```

注意：Crostini 里没有 KVM 加速，Docker 构建（尤其 arm64 镜像内编译 native）会较慢；详见
[platform-docker.md](platform-docker.md)。

## 六、各运行环境（ChromeOS 视角）

| 运行环境 | 在 ChromeOS 上的形态 |
| --- | --- |
| 物理本机 | 即「本机硬件 + Crostini（Debian 容器）」；x86_64 完整支持 |
| 虚拟机 | ChromeOS 已运行在 Crostini VM 内；**不支持再嵌套通用虚拟机**（QEMU 无 KVM 会很慢） |
| WSL | ➖ WSL 是 Windows 专属，ChromeOS 不适用 |
| Docker 容器 | 可在 Crostini 内安装 Docker（见第五节），但无嵌套虚拟化加速 |
| 云电脑（VDI） | 一般通过 Chrome 浏览器连接远程 Windows/Linux 桌面；**真正的分析在云端**，请按云端系统选用对应平台文档，Chromebook 本机只当瘦客户端 |

## 七、重要限制与注意事项

- **登出/关闭 Linux 终端会停止所有 Crostini 进程**（含后台分析/容器）；长任务请在容器内用 `tmux`/`nohup`，或保持终端开启。
- Termina VM **不允许加载自定义内核模块**，因此 VirtualBox/内核级虚拟化类方案不可用。
- 不支持 L2 网络；网络为 NAT，容器内开端口可通过 ChromeOS 的端口转发在浏览器访问。
- 升级容器系统：`sudo apt update && sudo apt upgrade`；必要时官方提供
  `/opt/google/cros-containers/bin/upgrade_container`。
- **ARM 设备** 除了要自建 native，部分第三方二进制（如 x86 版 demo/工具）也不能直接运行，需用 aarch64 对应物；不要指望跨架构模拟。

## 八、常见问题

- **设置里找不到「Linux 开发环境」**：该设备/地区的固件可能不支持 Crostini，或由学校/企业管理员在策略中关闭；请联系管理员确认。
- **构建 `linux_arm_64` 失败**：确认 `sudo apt install -y build-essential bison make`，再 `bash scripts/build-ghidra-native.sh --force`。
- **磁盘不足**：调大 Linux 磁盘（第二节），或安装后删除 `~/tools` 下的安装包与临时目录。
- **内存不足 / Java 启动失败**：`echo 'export GHIDRA_HEADLESS_MAXMEM=512M' >> ~/.bashrc` 后重开终端。
- 更多通用问题见 [troubleshooting.md](troubleshooting.md)。

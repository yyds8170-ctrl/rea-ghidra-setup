[English](troubleshooting.en.md) | 简体中文

# 故障排查（跨平台）

> 第一步永远是跑只读诊断：`bash scripts/doctor.sh`（Windows 用 `.\scripts\doctor.ps1`），
> 再跑 `rea doctor`。下面按平台与现象汇总（均为实际踩坑与修复）。

## 通用

### 1. JDK 版本不对（报 unsupported_version / 要求 JDK 21）

Ghidra 12.x 要求**恰好 JDK 21**。常见错误是系统/CI 上默认 JDK 17：

- 检查：`java -version`；`echo $JAVA_HOME`（Windows：`$env:JAVA_HOME`）。
- 修复：用安装脚本安装的 `tools/jdk-21*`，并确保它在 PATH 最前、`JAVA_HOME` 指向它。
- **CI/托管环境会向每个步骤注入 `JAVA_HOME=JDK17`**（覆盖注册表用户值）；本仓库的 `doctor.ps1`
  与 `verify.ps1` 已改为优先 `tools\jdk-21*` 并回写 `$env:JAVA_HOME`。
- 高版本 JDK（如 25）也可能不被支持，请用 Temurin 21。

### 2. Node 版本不满足（^22.19 || ^24.11 || >=26）

- REA 拒绝 Node 23/25 及低版本 22/24。安装脚本会装便携 Node 24.22.0；`SKIP_NODE=1` 时请自行切换。
- 用 fnm/nvm 时注意它注入的 `NODE_VERSION` 变量；本项目的版本变量因此命名为 `REA_NODE_VERSION`。
- 验证：`node --version` 需 ≥ v22.19（或 v24.11 / v26+）。

### 3. 分析很慢 / 超时 / 内存不足

- 加大启动超时：`REA_GHIDRA_STARTUP_TIMEOUT_MS=600000`（默认 330000）。
- 低内存机器（云电脑/Crostini）：`GHIDRA_HEADLESS_MAXMEM=512M`（默认 2G）。
- 注意 MCP 客户端自身也有请求超时，可能比 Ghidra 更早超时。

### 4. 下载校验和不匹配

- 安装器会对 JDK/Node/Ghidra 做 SHA-256 强校验；不匹配会删除并中止（可能下载损坏/被篡改）。
- 重试下载；公司网关/代理若做了 HTTPS 解密，请走镜像或离线包（见 [offline.md](offline.md)）。
- 获取不到校验和（离线/限流）时会警告放行；Ghidra 限流可设置 `GH_TOKEN`。

## macOS

### 5. “无法打开，因为无法验证开发者”（Gatekeeper）

REA 不会替你改隔离属性；安装脚本会对整个 Ghidra 目录执行：

```bash
xattr -dr com.apple.quarantine "$GHIDRA_INSTALL_DIR"
```

若仍被拦，手动执行该命令；不要动 `spctl`（系统级，需管理员）。

### 6. 报 `unbound variable` / 变量名后面跟着乱码（CI 或非 UTF-8 locale）

macOS 自带 `/bin/bash` 是 **3.2.57**，在非 UTF-8 locale 下会把 `$VAR` 后紧跟中文的首字节并入变量名。
脚本已统一：① `lib/common.sh` 里 `ensure_utf8_locale()` 强制 C/en_US.UTF-8；② 变量统一加花括号
（`${VAR}`）。自行改脚本时请保持花括号风格。

### 7. 反编译失败 / 找不到函数；日志里函数名带前导下划线

Mach-O 的 C 符号带下划线（`_secret_check`）。三个 verify 脚本已先用
`rea search --kind procedures --mode regex` 解析 Ghidra 内真实函数名再 decompile；
你自己写命令时也请以 `rea search` 输出的真实名字为准。

### 8. Apple Silicon 缺 native decompiler（mac_arm_64）

官方 zip 不含 `mac_arm_64`（Intel 的 `mac_x86_64` 个别版本也只有源码）。安装脚本会自动：

```bash
cd "$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/src/decompile/cpp"
make ghidra_opt ARCH_TYPE="-arch arm64" OSDIR=mac_arm_64 ADDITIONAL_FLAGS="-w"
install -m 755 ghidra_opt "$GHIDRA_INSTALL_DIR/Ghidra/Features/Decompiler/os/mac_arm_64/decompile"
```

依赖 Xcode 命令行工具（`xcode-select --install`）。Apple Silicon 虚拟机只能跑 arm64 guest。

## Windows

### 9. `rea` 命令找不到 / 全局安装后无法识别

便携 Node 不会自动把 npm 全局目录加进 PATH。安装脚本已把 `%APPDATA%\npm` 幂等追加到**用户级** PATH；
请**重开终端**。临时使用：`$env:Path="$env:APPDATA\npm;$env:Path"`。

### 10. REA 命令几秒就失败、stderr 为空

- 先确认是 JDK 17 问题（见第 1 条）：`verify.ps1` 会把 `$env:JAVA_HOME` 回写为 JDK21。
- REA 的错误信封是 **JSON（以 `{` 开头）并输出到 stdout**；脚本会解析并打印 `error`/`message`/`rejections`。
  手工排查时运行：`rea doctor --json`。

### 11. 路径 / 网络盘 / 重解析点不支持

- Ghidra 路径不能含 `!` 和 `^`（headless 无法启动）；用纯 ASCII 路径，如 `C:\tools\...`。
- REA Windows P0 仅支持**固定本地 NTFS**；不支持 UNC/网络盘/重解析点。验证用的 PE fixture 会复制到
  `$env:TEMP`（本地 C 盘）再分析。

### 12. 脚本无法执行（执行策略）

用一次性、进程级绕过（不改动系统策略）：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### 13. 缺 `VCRUNTIME140.dll`（少见）

官方 zip 已带 `decompile.exe`；若报缺 VC++ 运行库，安装微软 VC++ Redist x64（需管理员）。

## Linux / WSL / ChromeOS

### 14. arm64 缺 `linux_arm_64` native decompiler

安装器检测到 aarch64 会自动构建；手动方式：

```bash
sudo apt install build-essential bison make
bash scripts/build-ghidra-native.sh
```

### 15. WSL2 / Crostini 特有问题

- WSL2 中建议把待分析文件放在 `\\wsl$` 的 Linux 文件系统内（放 NTFS 挂载盘 IO 慢且有重解析点问题）。
- ChromeOS 只能用 Crostini（Linux 开发环境）；ARM Chromebook 需构建 `linux_arm_64`，磁盘建议 15–20GB，
  登出即停。详见 [platform-chromeos.md](platform-chromeos.md)。

## Docker

### 16. arm64 构建极慢 / 超时

x86 机器上用 QEMU 交叉构建 arm64 时，镜像内编译 native 极慢。改用**原生 arm64 机器/runner**
（本仓库 CI 用 `ubuntu-24.04-arm`），或加 buildx 缓存。详见 [platform-docker.md](platform-docker.md)。

### 17. AppArmor / SELinux / 权限

- AppArmor（仅本地测试）：`docker run --security-opt apparmor=unconfined ...`。
- SELinux 挂载：`-v "$PWD:/workspace:z"`。
- rootless：无需特权即可 headless 分析；遇到设备/网络命名空间问题按 rootless 文档排查。

## 收集信息求助

请附上：`scripts/doctor.sh`（或 `doctor.ps1`）全文输出、`uname -a`（Windows 为系统版本与
`$env:PROCESSOR_ARCHITECTURE`）、`rea doctor --json`、复现命令与 `--format json` 输出。
不要把 `~/.config` 下的 token、完整环境变量贴到公开渠道。

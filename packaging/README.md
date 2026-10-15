# 分发渠道资产 / Distribution packaging

本目录是**已就绪、可直接发布**的第三方包管理器资产。由于本项目许可为 **PolyForm Noncommercial 1.0.0**，
无法进入 homebrew/core（要求 DFSG 兼容许可），故走**个人 tap / 个人 bucket**（不限制许可）。

> 说明：发布需要在主仓库之外**新建两个独立仓库**（tap 与 bucket）。按项目边界，未擅自创建；
> 维护者确认后，照下面步骤执行即可。npm 包装器**有意不做**（Windows 无 bash、postinstall 不可靠、
> 不适合分发数百 MB 运行时下载，见下）。

## 1. Homebrew（macOS / Linux）

文件：[`homebrew/rea-ghidra.rb`](homebrew/rea-ghidra.rb)

```bash
# 1) 新建 tap 仓库（仅首次）：GitHub 上创建 yyds8170-ctrl/homebrew-rea-ghidra
# 2) 放入 Formula/rea-ghidra.rb
# 3) 发版后把 url 的 tag 与 sha256 更新为真实值：
curl -sL https://github.com/yyds8170-ctrl/rea-ghidra-setup/archive/refs/tags/v4.0.0.tar.gz | shasum -a 256
# 4) 提交并推 tap
# 用户安装：
brew tap yyds8170-ctrl/rea-ghidra && brew install rea-ghidra
```

formula 把脚本本体装到 `libexec`、bin 放薄包装，**不让 brew 下载 Ghidra 本体**（运行时由脚本拉取）。

## 2. Scoop（Windows）

文件：[`scoop/rea-ghidra.json`](scoop/rea-ghidra.json)

```powershell
# 1) 新建 bucket 仓库（仅首次）：GitHub 上创建 yyds8170-ctrl/scoop-rea
# 2) 把 rea-ghidra.json 放到 bucket 根目录
# 3) 发版后更新 hash（或交给 checkver/autoupdate 自动）：
scoop install checkver; scoop checkver -u
# 用户安装：
scoop bucket add rea https://github.com/yyds8170-ctrl/scoop-rea
scoop install rea/rea-ghidra
```

manifest 直接解包仓库并给 `rea-ghidra.ps1` 建 shim；Scoop 以用户态运行，路径在用户目录，无需管理员。

## 3. 单行命令（零成本，所有平台通用，已在 README 顶部给出）

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/yyds8170-ctrl/rea-ghidra-setup/main/install.sh | bash
```
```powershell
# Windows PowerShell
irm https://raw.githubusercontent.com/yyds8170-ctrl/rea-ghidra-setup/main/install.ps1 | iex
```

## 4. 为什么不做 npm 包装器

- 核心安装逻辑是 bash，Windows 无 Git Bash 时会失败，等于把跨平台问题退回给用户；
- npm 对 `postinstall` 安全审查收紧，`--ignore-scripts` 在 CI/企业默认启用，脚本可能根本不跑；
- npm 不适合承载“运行时下载数百 MB Ghidra”的系统安装器，用户心智模型也错位。

---

# Distribution packaging (English)

Ready-to-publish assets for third-party package managers. PolyForm Noncommercial cannot enter
homebrew/core (DFSG-incompatible), so use a **personal tap/bucket** (no license restriction).
Publishing requires creating two separate repos outside this repository (not done by default):
`yyds8170-ctrl/homebrew-rea-ghidra` and `yyds8170-ctrl/scoop-rea`. No npm wrapper by design
(Windows lacks bash, postinstall is unreliable, and npm is a poor fit for a runtime-downloaded system tool).

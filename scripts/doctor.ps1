# =============================================================================
# scripts/doctor.ps1 — REA + Ghidra 只读自检（Windows 10/11 x64）
#
# 安装前预检、安装后复检都用它。不修改任何配置，只报告：
#   [PASS] 满足 / [WARN] 可用但有隐患 / [FAIL] 阻断（必须处理）
# 存在任一 FAIL 时退出码为 1。
#
# 用法（PowerShell 7 推荐）：
#   pwsh -ExecutionPolicy Bypass -File .\scripts\doctor.ps1
# 或 Windows PowerShell 5.1：
#   powershell -ExecutionPolicy Bypass -File .\scripts\doctor.ps1
# =============================================================================
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$cfg = Import-VersionConfig
$script:PassCount = 0; $script:WarnCount = 0; $script:FailCount = 0
function Add-Pass { param([string]$m) Write-Output "[PASS] $m"; $script:PassCount++ }
function Add-Warn { param([string]$m) Write-Output "[WARN] $m"; $script:WarnCount++ }
function Add-Fail { param([string]$m) Write-Output "[FAIL] $m"; $script:FailCount++ }
function Write-Rule { Write-Output ('-' * 60) }

$ToolsDir = Join-Path $env:USERPROFILE 'tools'
$arch = Get-WindowsArch

Write-Output '============================================================'
Write-Output ' REA + Ghidra 自检（doctor / Windows）'
Write-Output (" 系统 = {0} ({1}) / 版本 {2}" -f (Get-CimInstance Win32_OperatingSystem).Caption, $env:PROCESSOR_ARCHITECTURE, [Environment]::OSVersion.Version)
Write-Output (" 锁定版本 = Ghidra {0} / JDK {1} / Node {2} / rea {3}" -f $cfg.GHIDRA_VERSION, $cfg.JDK_FEATURE, $cfg.REA_NODE_VERSION, $cfg.REA_VERSION)
Write-Rule

# ---- 1. CPU 架构（Ghidra 官方不支持 Windows on ARM64）---------------------
if ($arch -eq 'x64') {
  Add-Pass "CPU 架构 x64（Ghidra 官方支持）"
} else {
  Add-Fail "CPU 架构为 $arch：Ghidra 无 win_arm64 native，官方不支持 Windows on ARM；请改用 x64 或 WSL2/容器"
}

# ---- 2. Node --------------------------------------------------------------
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  $nv = (& node --version 2>&1 | Out-String).Trim()
  if (Test-NodeVersion $nv) {
    Add-Pass "Node $nv 满足 REA 要求（^22.19 || ^24.11 || >=26）"
  } else {
    Add-Fail "Node $nv 不满足要求：需 Node 22.19+ / 24.11+ / 26+（运行 install.ps1 会装便携 Node）"
  }
} else {
  Add-Fail "未找到 node：REA 要求 Node 22.19+ / 24.11+ / 26+（运行 install.ps1 会装便携 Node）"
}

# ---- 3. JDK 21 ------------------------------------------------------------
# v3.0 集中发现：显式 env(合法) ＞ current junction ＞ 枚举 jdk-21*
$JavaHome = Resolve-JdkHome
if (-not $JavaHome) {
  $procJava = Get-Command java -ErrorAction SilentlyContinue
  if ($procJava) {
    $gh = & $procJava.Source -XshowSettings:properties -version 2>&1 | Select-String 'java.home = (.*)' | Select-Object -First 1
    if ($gh) { $JavaHome = $gh.Matches[0].Groups[1].Value.Trim() }
  }
}

if ($JavaHome) {
  $major = Get-JdkMajor $JavaHome
  if ($major -eq [int]$cfg.JDK_FEATURE) {
    Add-Pass "JDK $major（$JavaHome）"
  } elseif ($major -gt [int]$cfg.JDK_FEATURE) {
    Add-Warn "JDK $major 高于要求的 $($cfg.JDK_FEATURE)；Ghidra 通常要求恰好 $($cfg.JDK_FEATURE)，建议装 Temurin $($cfg.JDK_FEATURE)"
  } else {
    Add-Fail "JDK $major 过低：Ghidra 12.x 要求 JDK $($cfg.JDK_FEATURE)（运行 install.ps1 会装 Temurin $($cfg.JDK_FEATURE)）"
  }
} else {
  Add-Fail "未找到 JDK：Ghidra 要求 64 位 JDK $($cfg.JDK_FEATURE)（运行 install.ps1 会装 Temurin）"
}

# ---- 4. Ghidra + analyzeHeadless.bat --------------------------------------
$GhDir = Resolve-GhidraDir
if ($GhDir -and (Test-Path -LiteralPath $GhDir)) {
  $bat = Join-Path $GhDir 'support\analyzeHeadless.bat'
  if (Test-Path -LiteralPath $bat) {
    Add-Pass "Ghidra 安装目录存在且 analyzeHeadless.bat 就位（$GhDir）"
  } else {
    Add-Fail "GHIDRA_INSTALL_DIR 已设但缺少 support\analyzeHeadless.bat：$GhDir"
  }
  $decomp = Join-Path $GhDir 'Ghidra\Features\Decompiler\os\win_x86_64\decompile.exe'
  if (Test-Path -LiteralPath $decomp) {
    Add-Pass "native decompiler 就位：os\win_x86_64\decompile.exe"
  } else {
    Add-Fail "缺少官方预编译 native decompiler：$decomp（发布包可能解压不完整，建议重新解压）"
  }
  if (Test-GhidraPathSafe $GhDir) {
    Add-Pass "Ghidra 路径无 ! 或 ^ 特殊字符"
  } else {
    Add-Fail "Ghidra 路径含 ! 或 ^（$GhDir），analyzeHeadless 无法启动，请改到纯字母数字路径"
  }
} else {
  Add-Fail "未设置或不存在 GHIDRA_INSTALL_DIR（运行 install.ps1 会下载并解压 Ghidra $($cfg.GHIDRA_VERSION)）"
}

# ---- 5. rea 命令 ----------------------------------------------------------
$rea = Get-Command rea -ErrorAction SilentlyContinue
if ($rea) {
  Add-Pass "已全局安装 rea（$($rea.Source)）"
} else {
  Add-Warn "未发现全局 rea 命令；可直接用 npx -y rea-agents@$($cfg.REA_VERSION)（install.ps1 会全局安装），并确认 %APPDATA%\npm 在 PATH"
}

# ---- 6. 磁盘空间 ----------------------------------------------------------
$drive = if ($GhDir) { (Split-Path $GhDir -Qualifier) } else { $env:SystemDrive }
try {
  $free = (Get-PSDrive -Name ($drive.TrimEnd(':'))).Free
  $freeGb = [math]::Round($free / 1GB)
  if ($freeGb -ge 5) { Add-Pass "磁盘 $drive 可用空间约 ${freeGb}GB" }
  else { Add-Warn "磁盘 $drive 可用空间仅约 ${freeGb}GB（Ghidra 解压+JDK 约需 2GB）" }
} catch { }

# ---- 7. 内存配置 ----------------------------------------------------------
if ($env:GHIDRA_HEADLESS_MAXMEM) {
  Add-Pass "GHIDRA_HEADLESS_MAXMEM=$env:GHIDRA_HEADLESS_MAXMEM（自定义堆内存）"
} else {
  Add-Warn "GHIDRA_HEADLESS_MAXMEM 未设置（默认 2G；低内存机器可设 512M）"
}

Write-Rule
Write-Output (" 自检结果：{0} 通过 / {1} 警告 / {2} 失败" -f $script:PassCount, $script:WarnCount, $script:FailCount)
Write-Output '============================================================'
if ($script:FailCount -gt 0) { exit 1 }

#Requires -Version 7
<#
.SYNOPSIS
  Windows 一键部署 REA (rea-agents) + Ghidra 反编译环境（用户态，免管理员）。

.DESCRIPTION
  与 install.sh / install-macos.sh 对应：
    1. 下载 Temurin JDK 21（Windows x64 zip，解压到 %USERPROFILE%\tools）
    2. 检查 Node（不满足 REA 要求 ^22.19||^24.11||>=26 时解压便携 Node 24.22.0）
    3. 下载并解压 Ghidra（跨平台同一个 zip）
    4. 校验官方自带的 win_x86_64 native decompiler
    5. 写入用户级环境变量 JAVA_HOME / GHIDRA_INSTALL_DIR / PATH（幂等）

  全程安装到用户目录，无需管理员权限；不写注册表的 HKLM，不动系统 PATH。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  # 或在 PowerShell 7 中：
  pwsh -File .\install.ps1
  pwsh -File .\install.ps1 -DryRun -Mirror cn
#>
[CmdletBinding()]
param(
  [switch]$Help,
  [switch]$DryRun,
  [switch]$Yes,
  [string]$ToolsDir = '',
  [string]$Mirror = '',
  [switch]$SkipNode,
  [switch]$NoNative,
  [string]$Provider = '',
  [string]$OfflineDir = '',
  [string]$GhidraVersion = '',
  [string]$NodeVersion = '',
  [string]$ReaVersion = ''
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/checksums.ps1')

# 版本/镜像覆盖：在 Import-VersionConfig 之前写入进程环境（复用“已有环境变量优先”）
if ($GhidraVersion) { $env:GHIDRA_VERSION = $GhidraVersion }
if ($NodeVersion)   { $env:REA_NODE_VERSION = $NodeVersion }
if ($ReaVersion)    { $env:REA_VERSION = $ReaVersion }
if ($Mirror)        { $env:REA_MIRROR = $Mirror }
if ($Provider)      { $env:REA_ANALYSIS_PROVIDER = $Provider }
if ($OfflineDir)    { $env:OFFLINE_DIR = $OfflineDir }

function Show-InstallHelp {
  Write-Output @'
用法：pwsh -File .\install.ps1 [选项]

非交互参数化安装（默认不带参数时行为与历史一致）。

  -Help            打印本用法并退出
  -DryRun          只打印将要执行的安装计划，不下载/解压/写环境变量
  -Yes             显式声明非交互（不阻塞）
  -ToolsDir <dir>  安装根目录（默认 %USERPROFILE%\tools）
  -Mirror <auto|cn|global>   镜像模式（默认 auto）
  -SkipNode        不安装便携 Node
  -NoNative        跳过 native decompiler 校验/构建提示
  -Provider <名>   设置 REA_ANALYSIS_PROVIDER（如 ghidra）
  -OfflineDir <dir> 离线包目录
  -GhidraVersion <ver>  覆盖 Ghidra 版本
  -NodeVersion <ver>    覆盖便携 Node 版本
  -ReaVersion <ver>     覆盖 rea-agents 版本

示例：
  pwsh -File .\install.ps1
  pwsh -File .\install.ps1 -DryRun -Mirror cn
  pwsh -File .\install.ps1 -Yes -SkipNode
'@
}
if ($Help) { Show-InstallHelp; exit 0 }

$Cfg = Import-VersionConfig
$Arch = Get-WindowsArch
if ($ToolsDir) {
  $ToolsDirResolved = $ToolsDir
} elseif ($env:TOOLS_DIR) {
  $ToolsDirResolved = $env:TOOLS_DIR
} else {
  # 跨平台安全默认目录：兼容 CI 在 ubuntu 上跑 pwsh -DryRun（USERPROFILE 为空）
  $homeBase = $env:USERPROFILE
  if ([string]::IsNullOrWhiteSpace($homeBase)) { $homeBase = $HOME }
  if ([string]::IsNullOrWhiteSpace($homeBase)) { $homeBase = [Environment]::GetFolderPath('UserProfile') }
  $ToolsDirResolved = Join-Path $homeBase 'tools'
}
$MirrorMode = Get-ReaMirrorMode

if ($DryRun) {
  Write-Output '========== Dry-run：将要执行的安装计划（不会做任何改动）=========='
  Write-Output "  平台/环境   : Windows / $Arch"
  Write-Output "  镜像模式    : $(if ($env:REA_MIRROR) { $env:REA_MIRROR } else { 'auto' }) → 有效 = $MirrorMode"
  Write-Output "  安装目录    : $ToolsDirResolved"
  Write-Output "  组件版本    : Ghidra $($Cfg.GHIDRA_VERSION) ｜ JDK $($Cfg.JDK_FEATURE) ｜ Node $($Cfg.REA_NODE_VERSION) ｜ REA $($Cfg.REA_VERSION)"
  Write-Output "  provider    : $(if ($Provider) { $Provider } else { '(自动选择)' })"
  Write-Output "  离线包      : $(if ($OfflineDir) { "是（$OfflineDir）" } else { '否' })"
  Write-Output "  跳过 Node   : $(if ($SkipNode) { '是' } else { '否' })"
  Write-Output "  跳过 native : $(if ($NoNative) { '是' } else { '否' })"
  Write-Output '  步骤预览    : [1]JDK [2]Node [3]Ghidra [4]native [5]写用户环境变量 → verify.ps1'
  Write-Output '=================================================================='
  exit 0
}

$ToolsDir = $ToolsDirResolved

Write-Output '=========================================================='
Write-Output ' REA + Ghidra 部署（Windows）'
Write-Output " 架构   : $Arch"
Write-Output " 目录   : $ToolsDir"
Write-Output " Ghidra : $($Cfg.GHIDRA_VERSION) ｜ JDK: $($Cfg.JDK_FEATURE) ｜ Node: $($Cfg.REA_NODE_VERSION) ｜ REA: $($Cfg.REA_VERSION)"
Write-Output '=========================================================='

if ($Arch -eq 'arm64') {
  Write-Note '检测到 Windows on ARM64。本脚本安装的是 x64 版本，依赖 Windows 11 的 x64 模拟运行；'
  Write-Note '官方 CI 仅在 x64 上验证，ARM64 属“受限支持”（详见 docs/platform-windows.md）。'
}
if (-not (Test-GhidraPathSafe -Path $ToolsDir)) {
  Stop-Fatal "安装路径不能包含字符 ! 或 ^（Ghidra headless 无法启动）：$ToolsDir，请改用 -ToolsDir 或设置 TOOLS_DIR"
}
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
$dlDir = Join-Path $env:TEMP 'rea-ghidra-dl'
New-Item -ItemType Directory -Force -Path $dlDir | Out-Null

# ---------------------------------------------------------------------------
# 1. Temurin JDK 21（用户态 zip，解压即用）
# ---------------------------------------------------------------------------
Write-Info "[1/5] 准备 Temurin JDK 21（windows/x64）..."
$JdkHome = Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
  Select-Object -First 1 -ExpandProperty FullName
if ($JdkHome -and (Get-JdkMajor -JavaHome $JdkHome) -ge 21) {
  Write-Ok "已存在 JDK：$JdkHome（跳过下载）"
} else {
  $jdkZip = Join-Path $dlDir 'jdk21.zip'
  Write-Info '下载 Temurin JDK 21 zip（约 200MB）…'
  Get-VerifiedArtifact -Kind jdk -Name 'jdk21-windows-x64.zip' -Url (Get-JdkUrl $Cfg) -Out $jdkZip -Cfg $Cfg
  Expand-ZipArchive -Zip $jdkZip -DestinationParent $ToolsDir
  $JdkHome = Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'jdk-21*' |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
    Select-Object -First 1 -ExpandProperty FullName
  if (-not $JdkHome) { Stop-Fatal 'JDK 解压后未找到 jdk-21* 目录' }
  Remove-Item -LiteralPath $jdkZip -Force -ErrorAction SilentlyContinue
  Write-Ok "JDK 安装完成：$JdkHome"
}
if ((Get-JdkMajor -JavaHome $JdkHome) -lt 21) { Stop-Fatal "JDK 主版本低于 21：$JdkHome" }

# ---------------------------------------------------------------------------
# 2. Node（满足 REA 要求则用系统 Node；否则解压便携 Node 24.22.0）
# ---------------------------------------------------------------------------
Write-Info "[2/5] 检查 Node（REA 要求 ^22.19 || ^24.11 || >=26）..."
$NodeDir = $null
$sysNode = Get-Command node -ErrorAction SilentlyContinue
if ($sysNode -and (Test-NodeVersion -VersionString ((& node --version 2>$null) -as [string]))) {
  Write-Ok "系统 Node 已满足：$(& node --version)"
} elseif ($SkipNode) {
  Write-Note '-SkipNode：跳过便携 Node 安装（请自行确保 Node 22.19+/24.11+/26+）'
} else {
  $NodeDir = Join-Path $ToolsDir (Get-NodeDirName $Cfg)
  if (-not (Test-Path -LiteralPath (Join-Path $NodeDir 'node.exe'))) {
    $nodeZip = Join-Path $dlDir 'node.zip'
    Write-Info "下载便携 Node $($Cfg.REA_NODE_VERSION)（win-x64）…"
    $nodePkg = "$(Get-NodeDirName $Cfg).zip"
    Get-VerifiedArtifact -Kind node -Name $nodePkg -Url (Get-NodeZipUrl $Cfg) -Out $nodeZip -Cfg $Cfg
    Expand-ZipArchive -Zip $nodeZip -DestinationParent $ToolsDir
    Remove-Item -LiteralPath $nodeZip -Force -ErrorAction SilentlyContinue
  }
  if (-not (Test-Path -LiteralPath (Join-Path $NodeDir 'node.exe'))) { Stop-Fatal "便携 Node 解压失败：$NodeDir" }
  $env:Path = "$NodeDir;$env:Path"
  Write-Ok "便携 Node 就绪：$NodeDir（$(& (Join-Path $NodeDir 'node.exe') --version)）"
}
# npm 全局 bin 目录（便携 Node 不会自动加 PATH；必须显式加入）
$NpmGlobal = Join-Path $env:APPDATA 'npm'
New-Item -ItemType Directory -Force -Path $NpmGlobal | Out-Null

# ---------------------------------------------------------------------------
# 3. Ghidra（跨平台 zip，解压即用）
# ---------------------------------------------------------------------------
Write-Info "[3/5] 准备 Ghidra $($Cfg.GHIDRA_VERSION)..."
$GhidraDir = Join-Path $ToolsDir (Get-GhidraDirName $Cfg)
if (Test-Path -LiteralPath (Join-Path $GhidraDir 'support\analyzeHeadless.bat')) {
  Write-Ok "已存在 Ghidra：$GhidraDir（跳过下载）"
} else {
  $ghZip = Join-Path $dlDir 'ghidra.zip'
  Write-Info '下载 Ghidra zip（约 570MB）…'
  Get-VerifiedArtifact -Kind ghidra -Name (Get-GhidraZipName $Cfg) -Url (Get-GhidraUrl $Cfg) -Out $ghZip -Cfg $Cfg
  Expand-ZipArchive -Zip $ghZip -DestinationParent $ToolsDir
  Remove-Item -LiteralPath $ghZip -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path -LiteralPath (Join-Path $GhidraDir 'support\analyzeHeadless.bat'))) {
    Stop-Fatal "Ghidra 解压后未找到 support\analyzeHeadless.bat：$GhidraDir"
  }
  Write-Ok "Ghidra 安装完成：$GhidraDir"
}

# ---------------------------------------------------------------------------
# 4. 校验官方自带的 win_x86_64 native decompiler
# ---------------------------------------------------------------------------
Write-Info "[4/5] 校验 native decompiler（win_x86_64）..."
if ($NoNative) {
  Write-Note '-NoNative：跳过 native decompiler 校验（Windows x64 官方包通常自带 decompile.exe）'
} else {
$Decompiler = Join-Path $GhidraDir 'Ghidra\Features\Decompiler\os\win_x86_64\decompile.exe'
if (Test-Path -LiteralPath $Decompiler) {
  Write-Ok '找到官方预编译 decompile.exe（win_x86_64）'
} else {
  Write-Note '未找到 win_x86_64\decompile.exe。Windows x64 官方发布包应自带该文件；'
  Write-Note '请确认下载的 Ghidra 包完整，或重新运行安装脚本。'
}
}
Remove-Item -LiteralPath $dlDir -Recurse -Force -ErrorAction SilentlyContinue

# v3.0：current junction（目录联接，免管理员；非 Windows 自动跳过）
New-ToolJunction -LinkName (Join-Path $ToolsDir 'current-ghidra') -Target $GhidraDir
New-ToolJunction -LinkName (Join-Path $ToolsDir 'current-jdk')    -Target $JdkHome
Write-Ok "current junction 已指向：$(Split-Path $GhidraDir -Leaf) / $(Split-Path $JdkHome -Leaf)"

# ---------------------------------------------------------------------------
# 5. 写入用户级环境变量（免管理员，幂等）并即时同步当前进程
# ---------------------------------------------------------------------------
Write-Info "[5/5] 配置用户级环境变量..."
Set-UserVariable -Name 'JAVA_HOME' -Value $JdkHome
Set-UserVariable -Name 'GHIDRA_INSTALL_DIR' -Value $GhidraDir
Add-UserPathEntry -Directory (Join-Path $JdkHome 'bin')
if ($NodeDir) { Add-UserPathEntry -Directory $NodeDir }
Add-UserPathEntry -Directory $NpmGlobal
$env:Path = "$(Join-Path $JdkHome 'bin');$($NodeDir);$NpmGlobal;$env:Path"

# 可选：默认堆内存（低内存机器可设为 512M）
if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('GHIDRA_HEADLESS_MAXMEM'))) {
  Set-UserVariable -Name 'GHIDRA_HEADLESS_MAXMEM' -Value '2G'
}

# ---------------------------------------------------------------------------
# REA 就绪体检（无需安装，直接 npx）
# ---------------------------------------------------------------------------
Write-Output ''
Write-Info 'REA 就绪检查（直接用 npx，无需安装）：'
$npx = if ($NodeDir) { Join-Path $NodeDir 'npx.cmd' } else { 'npx.cmd' }
$mirrorReg = Get-NpmMirrorRegistry
if ($mirrorReg) { $env:npm_config_registry = $mirrorReg }
try {
  & $npx -y "rea-agents@$($Cfg.REA_VERSION)" doctor --provider ghidra
  if ($LASTEXITCODE -ne 0) { Write-Note 'doctor 有未通过项，可按上面提示排查（不影响安装）。' }
} catch {
  Write-Note "doctor 未能运行（可能首次 npx 拉取超时）：$($_.Exception.Message)"
}

Write-Output ''
Write-Output '============ 安装完成（Windows） ============'
Write-Output "  JAVA_HOME          = $JdkHome"
Write-Output "  GHIDRA_INSTALL_DIR = $GhidraDir"
Write-Output '  请【重新打开】一个 PowerShell/终端让环境变量生效，然后运行：'
Write-Output '      powershell -ExecutionPolicy Bypass -File .\verify.ps1'
Write-Output '  常用命令：'
Write-Output '      npx -y rea-agents@latest analyze <二进制路径> --provider ghidra --format json'
Write-Output '  全局安装：npm install --global rea-agents'
Write-Output '  接 MCP 客户端（先预览再确认）：'
Write-Output '      pwsh -File .\scripts\mcp-setup.ps1 -List'
Write-Output '      pwsh -File .\scripts\mcp-setup.ps1 -Client claude-desktop -Yes'
Write-Output '      pwsh -File .\scripts\mcp-setup.ps1 -Check'
Write-Output '  卸载：    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1'

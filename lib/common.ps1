# =============================================================================
# lib/common.ps1 — Windows PowerShell 安装/验证脚本共用的工具函数
#
# 本文件只被 dot-source（. "$PSScriptRoot/common.ps1"），不直接执行。
# 与 lib/common.sh 一一对应：版本号加载、下载 URL 构造、架构归一化、
# Node 版本门禁、用户级环境变量、下载/解压等。
#
# 目标：PowerShell 7（pwsh，跨平台默认 UTF-8）。Windows 10/11 自带的是
#       Windows PowerShell 5.1，建议安装 pwsh 7 后运行（见 docs/platform-windows.md）。
# =============================================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # 关闭 Invoke-WebRequest 进度条，加速大文件
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# 仓库根目录（lib/ 的上一级）
$Script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

# ---- 日志（纯文本前缀，避免 Write-Host 的宿主依赖与 PSScriptAnalyzer 告警）----
function Write-Info { param([string]$Message) Write-Output "[*] $Message" }
function Write-Ok   { param([string]$Message) Write-Output "[OK] $Message" }
function Write-Note { param([string]$Message) Write-Output "[!] $Message" }
function Stop-Fatal {
  param([string]$Message)
  Write-Output "[ERR] $Message"
  exit 1
}

# ---- 版本加载：config/versions.env 为默认，已存在的进程环境变量优先 ----------
# 返回一个有序字典（GHIDRA_VERSION / GHIDRA_BUILD / GHIDRA_DATE / JDK_FEATURE /
# REA_NODE_VERSION / REA_VERSION）。
function Import-VersionConfig {
  $path = Join-Path $Script:RepoRoot 'config/versions.env'
  if (-not (Test-Path -LiteralPath $path)) { Stop-Fatal "找不到版本文件 $path" }
  $cfg = [ordered]@{}
  foreach ($raw in Get-Content -LiteralPath $path) {
    $line = $raw.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { continue }
    $key = $line.Substring(0, $eq).Trim()
    $val = $line.Substring($eq + 1).Trim()
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($key))) {
      $cfg[$key] = $val
    } else {
      $cfg[$key] = [Environment]::GetEnvironmentVariable($key)
    }
  }
  return $cfg
}

# ---- 下载 URL 构造（与 lib/common.sh 保持一致）-----------------------------
function Get-GhidraZipName { param($Cfg) "ghidra_$($Cfg.GHIDRA_VERSION)_PUBLIC_$($Cfg.GHIDRA_DATE).zip" }
function Get-GhidraUrl     { param($Cfg) "https://github.com/NationalSecurityAgency/ghidra/releases/download/$($Cfg.GHIDRA_BUILD)/$(Get-GhidraZipName $Cfg)" }
function Get-GhidraDirName { param($Cfg) "ghidra_$($Cfg.GHIDRA_VERSION)_PUBLIC" }

# Adoptium Temurin JDK 21 Windows x64 zip（用户态免安装，302 重定向到具体文件）
function Get-JdkUrl { param($Cfg) "https://api.adoptium.net/v3/binary/latest/$($Cfg.JDK_FEATURE)/ga/windows/x64/jdk/hotspot/normal/eclipse" }

# Node 官方 Windows x64 zip（解压即用；REA 要求 ^22.19 || ^24.11 || >=26）
function Get-NodeZipUrl  { param($Cfg) "https://nodejs.org/dist/v$($Cfg.REA_NODE_VERSION)/node-v$($Cfg.REA_NODE_VERSION)-win-x64.zip" }
function Get-NodeDirName { param($Cfg) "node-v$($Cfg.REA_NODE_VERSION)-win-x64" }

# ---- CPU 架构归一化（x64 / arm64）------------------------------------------
function Get-WindowsArch {
  switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { return 'x64' }
    'ARM64' { return 'arm64' }
    default { return "$($env:PROCESSOR_ARCHITECTURE)" }
  }
}

# ---- Node 版本门禁：满足 ^22.19 || ^24.11 || >=26 ---------------------------
function Test-NodeVersion {
  param([string]$VersionString)
  if ($null -eq $VersionString) { return $false }
  $m = [regex]::Match($VersionString, 'v?(\d+)\.(\d+)\.(\d+)')
  if (-not $m.Success) { return $false }
  $major = [int]$m.Groups[1].Value
  $minor = [int]$m.Groups[2].Value
  if ($major -ge 26) { return $true }
  if ($major -eq 24 -and $minor -ge 11) { return $true }
  if ($major -eq 22 -and $minor -ge 19) { return $true }
  return $false
}

# 读取某 JDK 目录的主版本号；失败返回 0
function Get-JdkMajor {
  param([string]$JavaHome)
  $java = Join-Path $JavaHome 'bin\java.exe'
  if (-not (Test-Path -LiteralPath $java)) { return 0 }
  try {
    $out = & $java -version 2>&1 | Out-String
    $m = [regex]::Match($out, 'version\s+"(\d+)(?:\.(\d+))?')
    if (-not $m.Success) { return 0 }
    $first = [int]$m.Groups[1].Value
    if ($first -eq 1) { return [int]$m.Groups[2].Value }  # 1.8 这种老写法
    return $first
  } catch { return 0 }
}

# ---- 健壮下载内核（与 lib/download.sh 对应；PS 5.1 兼容）---------------------
# 环境变量可覆盖：REA_DL_RETRIES / REA_DL_CONNECT_TIMEOUT / REA_DL_MAX_TIME
$script:ReaDlRetries = 5
if ($env:REA_DL_RETRIES) { [int]::TryParse($env:REA_DL_RETRIES, [ref]$script:ReaDlRetries) | Out-Null }
$script:ReaDlConnectTimeout = 15
if ($env:REA_DL_CONNECT_TIMEOUT) { [int]::TryParse($env:REA_DL_CONNECT_TIMEOUT, [ref]$script:ReaDlConnectTimeout) | Out-Null }
$script:ReaDlMaxTime = 1800
if ($env:REA_DL_MAX_TIME) { [int]::TryParse($env:REA_DL_MAX_TIME, [ref]$script:ReaDlMaxTime) | Out-Null }

# GitHub release 候选 URL：官方直连在前，代理前缀在后（与 bash github_proxy_urls 一致）
function Get-GithubProxyUrls {
  param([Parameter(Mandatory)][string]$BaseUrl)
  $urls = @($BaseUrl)
  $over = $env:REA_GITHUB_PROXIES
  if ([string]::IsNullOrWhiteSpace($over)) { $over = 'https://gh-proxy.com/' }
  if ($over -ne 'none') {
    foreach ($p in ($over -split '[,; ]')) {
      $pp = $p.Trim()
      if ($pp) { $urls += ($pp + $BaseUrl) }
    }
  }
  return $urls
}

# 用 Range: bytes=0-0 的 GET 取远端总字节数（不依赖 HEAD）；失败返回 0
function Get-RemoteSizeBytes {
  param([Parameter(Mandatory)][string]$Url)
  $hdr = & curl.exe -sL -D - -o NUL --connect-timeout $script:ReaDlConnectTimeout --max-time 60 -H 'Range: bytes=0-0' $Url 2>$null
  $total = [int64]0
  foreach ($line in $hdr) {
    if ($line -match '(?i)^content-range:.*?/(\d+)') { $total = [int64]$Matches[1] }
    elseif ($line -match '(?i)^content-length:\s*(\d+)') { if ($total -eq 0) { $total = [int64]$Matches[1] } }
  }
  return $total
}

# 多源 failover 下载：先下到 <OutFile>.part，成功后 Move-Item 原子落地。
# 优先 curl.exe（Win10 1803+ 自带，-C - 断点续传），回退 Start-BitsTransfer（自带续传/重试），
# 再回退 Invoke-WebRequest。全部失败抛错，且不留半截目标文件。
function Save-RemoteFile {
  param(
    [Parameter(Mandatory)][string[]]$Url,
    [Parameter(Mandatory)][string]$OutFile
  )
  $outDir = Split-Path -Parent $OutFile
  if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
  $part = "$OutFile.part"
  $tried = $false

  foreach ($u in $Url) {
    if ($tried) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
    $tried = $true
    $ok = $false

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
      # 注意：PS 5.1 里 curl 是 Invoke-WebRequest 的别名，必须显式 curl.exe
      & curl.exe -fL --show-error --connect-timeout $script:ReaDlConnectTimeout --max-time $script:ReaDlMaxTime --retry $script:ReaDlRetries --retry-delay 2 -C - -o $part $u
      $rc = $LASTEXITCODE
      if ($rc -eq 0) {
        $ok = $true
      } elseif ($rc -eq 22 -or $rc -eq 33) {
        # 可能是续传一个其实已下完的文件（HTTP 416）：本地 .part 与远端等大则视为成功
        if ((Test-Path -LiteralPath $part) -and (Get-Item -LiteralPath $part).Length -gt 0) {
          $remote = Get-RemoteSizeBytes -Url $u
          if ($remote -gt 0 -and (Get-Item -LiteralPath $part).Length -eq $remote) { $ok = $true }
        }
      }
    }
    elseif (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
      try {
        Start-BitsTransfer -Source $u -Destination $part -ErrorAction Stop
        $ok = $true
      } catch { $ok = $false }
    }
    else {
      try {
        Invoke-WebRequest -Uri $u -OutFile $part -UseBasicParsing -TimeoutSec $script:ReaDlMaxTime
        $ok = $true
      } catch { $ok = $false }
    }

    if ($ok -and (Test-Path -LiteralPath $part) -and (Get-Item -LiteralPath $part).Length -gt 0) {
      Move-Item -LiteralPath $part -Destination $OutFile -Force
      return $true
    }
  }
  Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
  throw "所有下载源均失败：$($Url -join ' , ')"
}

# 兼容旧调用：单 URL 下载（保留幂等：目标已存在则跳过）
function Get-RemoteFile {
  param([Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination)
  if (Test-Path -LiteralPath $Destination) { return }
  Save-RemoteFile -Url $Url -OutFile $Destination
}

# ---- 解压 zip 到指定父目录 ---------------------------------------------------
function Expand-ZipArchive {
  param([Parameter(Mandatory)][string]$Zip,
        [Parameter(Mandatory)][string]$DestinationParent)
  if (-not (Test-Path -LiteralPath $DestinationParent)) {
    New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
  }
  Expand-Archive -LiteralPath $Zip -DestinationPath $DestinationParent -Force
}

# ---- 用户级（HKCU，免管理员）环境变量 ---------------------------------------
function Set-UserVariable {
  param([Parameter(Mandatory)][string]$Name, [string]$Value)
  [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
  Set-Item -Path "Env:$Name" -Value $Value
}

# 幂等追加到用户级 PATH（Windows 用分号分隔）；同时同步当前进程
function Add-UserPathEntry {
  param([Parameter(Mandatory)][string]$Directory)
  if (-not (Test-Path -LiteralPath $Directory)) { return }
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($null -eq $userPath) { $userPath = '' }
  $entries = $userPath -split ';' | Where-Object { $_ -ne '' }
  if ($entries -notcontains $Directory) {
    $merged = (@($entries) + $Directory) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $merged, 'User')
  }
  $procEntries = ($env:Path -split ';') | Where-Object { $_ -ne '' }
  if ($procEntries -notcontains $Directory) { $env:Path = "$env:Path;$Directory" }
}

# 从用户级 PATH 中删除匹配通配符的条目（卸载用）
function Remove-UserPathEntry {
  param([Parameter(Mandatory)][string]$LikePattern)
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($null -eq $userPath) { return }
  $kept = ($userPath -split ';') | Where-Object { $_ -ne '' -and ($_ -notlike $LikePattern) }
  [Environment]::SetEnvironmentVariable('Path', ($kept -join ';'), 'User')
}

# 校验 Ghidra 安装路径禁忌（不能含 ! 和 ^）
function Test-GhidraPathSafe {
  param([string]$Path)
  if ($Path -match '[!^]') { return $false }
  return $true
}

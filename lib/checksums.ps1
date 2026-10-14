# =============================================================================
# lib/checksums.ps1 — Windows 下载物 SHA-256 校验（与 lib/checksums.sh 对应）
#
# 校验和来源：
#   Node   官方 SHASUMS256.txt
#   JDK    Adoptium v3 assets JSON 的 package.checksum
#   Ghidra GitHub release asset 的 digest（sha256: 前缀）
#   离线包 scripts/prepare-offline.ps1 生成的 SHA256SUMS.txt
#
# 策略：能拿到校验和且不匹配 → 硬错误；离线/限流拿不到且无离线清单 → 警告放行。
# 仅在已 dot-source lib/common.ps1 后使用。
# =============================================================================

function Get-Sha256Hex {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

# 从离线清单 SHA256SUMS.txt 取某文件期望哈希；无清单/无匹配返回 $null
function Get-ManifestSha {
  param([string]$Manifest, [string]$Name)
  if (-not (Test-Path -LiteralPath $Manifest)) { return $null }
  foreach ($line in Get-Content -LiteralPath $Manifest) {
    if ($line -match '^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$') {
      if ($matches[2] -eq $Name) { return $matches[1].ToLower() }
    }
  }
  return $null
}

# Node 官方 SHASUMS256.txt
function Get-ExpectedNodeSha {
  param([string]$Version, [string]$Name)
  try {
    $sum = Invoke-RestMethod -Uri "https://nodejs.org/dist/v$Version/SHASUMS256.txt" -TimeoutSec 60
    foreach ($line in ($sum -split "`n")) {
      if ($line -match '^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$' -and $matches[2] -eq $Name) {
        return $matches[1].ToLower()
      }
    }
  } catch { }
  return $null
}

# Adoptium assets JSON（windows/x64）
function Get-ExpectedJdkSha {
  param([string]$Feature)
  try {
    $uri = "https://api.adoptium.net/v3/assets/latest/$Feature/hotspot?architecture=x64&os=windows&image_type=jdk&vendor=eclipse"
    $data = Invoke-RestMethod -Uri $uri -TimeoutSec 60
    foreach ($b in $data) {
      if ($b.binary.package.checksum) { return [string]$b.binary.package.checksum }
    }
  } catch { }
  return $null
}

# GitHub release asset digest（Ghidra）；token 提升限流
function Get-ExpectedGhidraSha {
  param($Cfg)
  try {
    $uri = "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/tags/$($Cfg.GHIDRA_BUILD)"
    $headers = @{ 'Accept' = 'application/vnd.github+json' }
    $tok = $env:GITHUB_TOKEN; if (-not $tok) { $tok = $env:GH_TOKEN }
    if ($tok) { $headers['Authorization'] = "Bearer $tok" }
    $data = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 60
    foreach ($a in $data.assets) {
      if ($a.name -eq (Get-GhidraZipName $Cfg)) {
        $d = [string]$a.digest
        if ($d.StartsWith('sha256:')) { $d = $d.Substring(7) }
        return $d.ToLower()
      }
    }
  } catch { }
  return $null
}

# 统一取交付物：优先离线目录，否则下载，再做 SHA-256 校验。
# Kind: node | jdk | ghidra；返回 $true 成功；校验不匹配抛错（$ErrorActionPreference=Stop）
function Get-VerifiedArtifact {
  param([Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Out,
        [Parameter(Mandatory)]$Cfg)
  $outDir = Split-Path -Parent $Out
  if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

  $offlineDir = $env:OFFLINE_DIR
  $manifest = if ($offlineDir) { Join-Path $offlineDir 'SHA256SUMS.txt' } else { $null }

  $expected = $null
  if ($manifest) { $expected = Get-ManifestSha -Manifest $manifest -Name $Name }

  # 离线目录优先
  if ($offlineDir -and (Test-Path -LiteralPath (Join-Path $offlineDir $Name))) {
    Copy-Item -LiteralPath (Join-Path $offlineDir $Name) -Destination $Out -Force
    Write-Output "[离线] 使用 $(Join-Path $offlineDir $Name)"
  } else {
    Get-RemoteFile -Url $Url -Destination $Out
  }

  if (-not $expected) {
    switch ($Kind) {
      'node'   { $expected = Get-ExpectedNodeSha -Version $Cfg.REA_NODE_VERSION -Name $Name }
      'jdk'    { $expected = Get-ExpectedJdkSha -Feature $Cfg.JDK_FEATURE }
      'ghidra' { $expected = Get-ExpectedGhidraSha -Cfg $Cfg }
    }
  }

  if ($expected) {
    $actual = Get-Sha256Hex -Path $Out
    if ($actual -eq $expected) {
      Write-Output "[校验] $Name SHA-256 一致"
      return $true
    }
    Remove-Item -LiteralPath $Out -Force -ErrorAction SilentlyContinue
    throw "校验失败：$Name 哈希不匹配（期望 $expected，实际 $actual），可能下载损坏或被篡改"
  }

  if ($offlineDir -and -not (Test-Path -LiteralPath $manifest)) {
    Write-Note "离线目录无 SHA256SUMS.txt，未校验 $Name（建议用 prepare-offline.ps1 生成完整离线包）"
  } else {
    Write-Note "未能获取 $Name 的上游校验和（离线或限流），已跳过校验"
  }
  return $true
}

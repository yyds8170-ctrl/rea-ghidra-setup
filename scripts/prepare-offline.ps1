#Requires -Version 7
<#
.SYNOPSIS
  在【有网】的 Windows x64 机器上准备离线安装包（JDK21 + Node 24.22.0 + Ghidra + 校验清单）。

.DESCRIPTION
  产物目录（默认 .\offline，可用 -OutDir 或 $env:OUT_DIR 覆盖）：
    jdk21-windows-x64.zip
    node-v<ver>-win-x64.zip
    ghidra_<ver>_PUBLIC_<date>.zip
    SHA256SUMS.txt / MANIFEST.txt
  每一项都与【上游官方校验和】比对（Node SHASUMS256、Adoptium JSON、GitHub release digest），
  任一不匹配即中止；目标机再用 SHA256SUMS.txt 离线强校验。

  在离线目标机：
    $env:OFFLINE_DIR='<目录>'; .\install.ps1
#>
. (Join-Path $PSScriptRoot '..\lib\common.ps1')
. (Join-Path $PSScriptRoot '..\lib\checksums.ps1')

$Cfg = Import-VersionConfig
$OutDir = if ($env:OUT_DIR) { $env:OUT_DIR } else { Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'offline' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$JdkName = 'jdk21-windows-x64.zip'
$NodeName = "$(Get-NodeDirName $Cfg).zip"
$GhidraName = Get-GhidraZipName $Cfg

Write-Output '=========================================================='
Write-Output " 准备离线安装包（windows/x64）-> $OutDir"
Write-Output " Ghidra $($Cfg.GHIDRA_VERSION) / JDK $($Cfg.JDK_FEATURE) / Node $($Cfg.REA_NODE_VERSION) / REA $($Cfg.REA_VERSION)"
Write-Output '=========================================================='

function Save-AndVerify {
  param([string]$Name, [string]$Url, [string]$Expected)
  $dest = Join-Path $OutDir $Name
  if (-not $Expected) { throw "无法获取 $Name 的上游校验和（限流/离线？）。Ghidra 可设置 `$env:GH_TOKEN 后重试。" }
  if ((Test-Path -LiteralPath $dest) -and ((Get-Sha256Hex $dest) -eq $Expected)) {
    Write-Output "[已存在且校验通过] $Name"; return
  }
  Write-Output "[下载] $Name"
  if ($Name -eq $GhidraName) {
    # Ghidra 大文件走官方 + GitHub 代理池多源回退
    Save-RemoteFile -Url (Get-GithubProxyUrls -BaseUrl $Url) -OutFile $dest
  } else {
    Get-RemoteFile -Url $Url -Destination $dest
  }
  $actual = Get-Sha256Hex $dest
  if ($actual -ne $Expected) { Remove-Item -LiteralPath $dest -Force; throw "校验失败：$Name（期望 $Expected，实际 $actual）" }
  Write-Output "[校验一致] $Name"
}

Save-AndVerify -Name $JdkName -Url (Get-JdkUrl $Cfg) -Expected (Get-ExpectedJdkSha -Feature $Cfg.JDK_FEATURE)
Save-AndVerify -Name $NodeName -Url (Get-NodeZipUrl $Cfg) -Expected (Get-ExpectedNodeSha -Version $Cfg.REA_NODE_VERSION -Name $NodeName)
Save-AndVerify -Name $GhidraName -Url (Get-GhidraUrl $Cfg) -Expected (Get-ExpectedGhidraSha -Cfg $Cfg)

# 生成清单
$manifestLines = foreach ($f in Get-ChildItem -LiteralPath $OutDir -File -Include '*.zip','*.tgz','*.tar.gz') {
  "$(Get-Sha256Hex $f.FullName)  $($f.Name)"
}
$manifestLines | Set-Content -LiteralPath (Join-Path $OutDir 'SHA256SUMS.txt') -Encoding ascii

@(
  'REA + Ghidra 离线安装包（windows/x64）'
  "generated_at : $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
  "ghidra       : $($Cfg.GHIDRA_VERSION)"
  "jdk_feature  : $($Cfg.JDK_FEATURE)"
  "node         : $($Cfg.REA_NODE_VERSION)"
  "rea          : $($Cfg.REA_VERSION)"
  ''
  "离线目标机：`$env:OFFLINE_DIR='$($OutDir)'; .\install.ps1"
) | Set-Content -LiteralPath (Join-Path $OutDir 'MANIFEST.txt') -Encoding utf8

Write-Output "完成。离线包目录：$OutDir"
Write-Output "目标机：`$env:OFFLINE_DIR='<目录>'; .\install.ps1"

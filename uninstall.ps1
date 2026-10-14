#Requires -Version 7
<#
.SYNOPSIS
  卸载本脚本在 Windows 上安装的 JDK / Ghidra / 便携 Node 与用户级环境变量。
  只删除本项目在 %USERPROFILE%\tools 下安装的内容，不动其它程序。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -Yes
#>
[CmdletBinding()]
param(
  [switch]$Help,
  [switch]$Yes,
  [string]$ToolsDir = ''
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')

if ($Help) {
  Write-Output @'
用法：pwsh -File .\uninstall.ps1 [选项]

  -Help            打印本用法并退出
  -Yes             非交互，跳过确认提示
  -ToolsDir <dir>  要清理的安装根目录（默认 %USERPROFILE%\tools）
'@
  exit 0
}

$Cfg = Import-VersionConfig
if ($ToolsDir) {
  $ToolsDirResolved = $ToolsDir
} elseif ($env:TOOLS_DIR) {
  $ToolsDirResolved = $env:TOOLS_DIR
} else {
  $ToolsDirResolved = Join-Path $env:USERPROFILE 'tools'
}
$ToolsDir = $ToolsDirResolved

Write-Output '=========================================================='
Write-Output ' REA + Ghidra 卸载（Windows）'
Write-Output " 目标目录：$ToolsDir"
Write-Output '=========================================================='

$targets = @(
  (Join-Path $ToolsDir (Get-GhidraDirName $Cfg))
)
$targets += Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName
$targets += Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName
$targets = $targets | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

if (-not $targets) {
  Write-Output '没有找到需要删除的 JDK / Ghidra / 便携 Node 目录。'
} else {
  Write-Output '将删除以下目录：'
  $targets | ForEach-Object { Write-Output "  - $_" }
}
Write-Output '将删除用户级环境变量：JAVA_HOME、GHIDRA_INSTALL_DIR、GHIDRA_HEADLESS_MAXMEM'
Write-Output '将从用户级 PATH 移除：tools 下的 jdk/bin 与便携 Node 目录'
Write-Output '注：保留 %APPDATA%\npm（npm 全局目录，可能被其它工具使用）。'

if (-not $Yes) {
  $ans = Read-Host '确认卸载？输入 yes 继续'
  if ($ans -ne 'yes') { Write-Output '已取消。'; exit 0 }
}

foreach ($t in $targets) {
  Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
  Write-Output "已删除：$t"
}

# 删除用户级环境变量
foreach ($name in 'JAVA_HOME','GHIDRA_INSTALL_DIR','GHIDRA_HEADLESS_MAXMEM') {
  [Environment]::SetEnvironmentVariable($name, $null, 'User')
  Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
}
# 从用户 PATH 移除本项目加入的目录（tools 下的 jdk/bin 与 node 便携目录）
Remove-UserPathEntry -LikePattern "$ToolsDir\jdk-21*"
Remove-UserPathEntry -LikePattern "$ToolsDir\node-v*"

Write-Output ''
Write-Output '卸载完成。如需彻底移除 npm 全局安装的 REA，可执行：npm uninstall -g rea-agents'

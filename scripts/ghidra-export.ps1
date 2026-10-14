# ghidra-export.ps1 — 用 Ghidra analyzeHeadless 导出二进制静态分析产物（JSON）。
# 不依赖 REA / Node。PS 5.1 / 7 兼容。
#
# 用法：
#   pwsh -File scripts/ghidra-export.ps1 -Bin <二进制> [-Out DIR] [-Kind functions|strings|symbols|calls|decompiled|all]
#   pwsh -File scripts/ghidra-export.ps1 -Help
param(
  [string]$Bin = "",
  [string]$Out = ".\ghidra-export",
  [ValidateSet("functions","strings","symbols","calls","decompiled","all")]
  [string]$Kind = "all",
  [switch]$Help
)
$ErrorActionPreference = "Stop"

# 复用 Get-JdkMajor 等公共函数（脚本在 scripts/，库在 ../lib/）
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

if ($Help -or $Bin -eq "") {
  Write-Output "ghidra-export.ps1 — Ghidra headless 导出静态分析产物"
  Write-Output "  -Bin <path>    目标二进制（必填）"
  Write-Output "  -Out <dir>     输出目录（默认 .\ghidra-export）"
  Write-Output "  -Kind <kind>   functions|strings|symbols|calls|decompiled|all（默认 all）"
  if ($Bin -eq "" -and -not $Help) { exit 2 } else { exit 0 }
}

if (-not (Test-Path $Bin)) { throw "二进制不存在：$Bin" }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPathDir = Join-Path $scriptDir "ghidra"

# ---- v3.0 集中发现：显式 env ＞ current junction ＞ 枚举（CI runner 注入 JDK17 时自动回退）----
$JavaHome = Resolve-JdkHome
if (-not $JavaHome) {
  $cur = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { '(空)' }
  throw "未找到 JDK21（要求 major>=21）。当前 JAVA_HOME=$cur；请先跑 install.ps1 或设置 JAVA_HOME 指向 JDK21。"
}
$env:JAVA_HOME = $JavaHome
$env:Path = "$(Join-Path $JavaHome 'bin');$env:Path"

$ghidra = Resolve-GhidraDir
if (-not $ghidra) { throw "未找到 Ghidra（设 GHIDRA_INSTALL_DIR 或先跑 install.ps1）" }
$headless = Join-Path $ghidra "support\analyzeHeadless.bat"

$kindMap = @{
  functions  = "ExportFunctions.java"; strings = "ExportStrings.java";
  symbols    = "ExportSymbols.java";  calls   = "ExportCalls.java";
  decompiled = "ExportDecompiled.java"; all   = "ExportAll.java"
}
$script = $kindMap[$Kind]

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Out = (Resolve-Path $Out).Path
$proj = Join-Path ([System.IO.Path]::GetTempPath()) ("rea-proj-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $proj | Out-Null
try {
  # Ghidra 会往 stderr 打 WARNING/INFO，PS7.4+ 在 EAP=Stop 下会把原生命令 stderr 当终止错误，临时关闭
  if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) { $PSNativeCommandUseErrorActionPreference = $false }
  Write-Output ("导出：" + $Bin + "  kind=" + $Kind + "  JAVA_HOME=" + $JavaHome + "  -> " + $Out)
  & $headless $proj Proj -import $Bin -scriptPath $scriptPathDir -postScript $script $Out -deleteProject
  $code = $LASTEXITCODE
  if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) { $PSNativeCommandUseErrorActionPreference = $true }
  if ($code -ne 0) { throw "analyzeHeadless 退出码 $code" }
  Write-Output "完成。产物："
  foreach ($f in @("functions","strings","symbols","calls","decompiled")) {
    $p = Join-Path $Out ($f + ".json")
    if (Test-Path $p) { Write-Output ("  {0}.json {1}" -f $f, $p) }
  }
}
finally {
  Remove-Item -Recurse -Force $proj -ErrorAction SilentlyContinue
}

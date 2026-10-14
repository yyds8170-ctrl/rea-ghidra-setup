#Requires -Version 7
<#
.SYNOPSIS
  Windows 端到端自检：对仓库自带的预编译 PE fixture 真实调用 REA 的 Ghidra provider。

.DESCRIPTION
  Windows 上通常没有 C 编译器，因此不现场编译，而是使用仓库自带的
  examples/bin/windows-x64/demo.exe（由 Zig 交叉编译，函数在导出表中）：
    1) 前置：node / analyzeHeadless.bat / JDK21 / native decompiler
    2) fixture 为有效 PE（MZ）且导出 secret_check / calc_discount
    3) analyze 能识别 PE / x86_64 / 函数数量 / 字符串
    4) decompile 还原 secret_check（observed，含 0x539）
    5) decompile 还原 calc_discount（observed，含 0x32）
    6) 剥离符号版仍可导入分析

  共 9 项断言，全部通过退出码 0；任一失败退出码 1。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\verify.ps1
#>
. (Join-Path $PSScriptRoot 'lib/common.ps1')

$Cfg = Import-VersionConfig
$ToolsDir = if ($env:TOOLS_DIR) { $env:TOOLS_DIR } else { Join-Path $env:USERPROFILE 'tools' }

$Pass = 0; $Fail = 0
function Write-Pass { param([string]$m) Write-Output "  [PASS] $m"; $script:Pass++ }
function Write-Fail { param([string]$m) Write-Output "  [FAIL] $m"; $script:Fail++ }
function Write-Step { param([string]$m) Write-Output "  [....] $m" }

# ---- 定位 JDK21 / Ghidra（用户级变量优先，其次 tools 目录）------------------
$JavaHome = $env:JAVA_HOME
if (-not $JavaHome -or (Get-JdkMajor -JavaHome $JavaHome) -lt 21) {
  $found = Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue |
    Where-Object { (Get-JdkMajor -JavaHome $_.FullName) -ge 21 } | Select-Object -First 1
  if ($found) { $JavaHome = $found.FullName }
}
$GhidraDir = $env:GHIDRA_INSTALL_DIR
if (-not $GhidraDir -or -not (Test-Path -LiteralPath (Join-Path $GhidraDir 'support\analyzeHeadless.bat'))) {
  $found = Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'ghidra_*_PUBLIC' -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'support\analyzeHeadless.bat') } |
    Select-Object -First 1
  if ($found) { $GhidraDir = $found.FullName }
}
if ($JavaHome) { $env:Path = "$(Join-Path $JavaHome 'bin');$env:Path" }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  $portableNode = Get-ChildItem -LiteralPath $ToolsDir -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($portableNode) { $env:Path = "$($portableNode.FullName);$env:Path" }
}
$env:GHIDRA_INSTALL_DIR = $GhidraDir

# REA 调用：优先 PATH 上的 rea，否则用 npx 拉取已发布版本
$reaCmd = Get-Command rea -ErrorAction SilentlyContinue
$npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
if (-not $npx) {
  $localNpx = Join-Path $ToolsDir 'node-v*-win-x64\npx.cmd'
  $found = Get-ChildItem $localNpx -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { $npx = Get-Command $found.FullName -ErrorAction SilentlyContinue }
}
$pkg = "rea-agents@$($Cfg.REA_VERSION)"

# 运行 REA 并把 stdout 存为 JSON 文件、stderr 存为日志；返回是否成功
function Invoke-ReaToFile {
  param([string[]]$ReaArgs, [string]$OutFile, [string]$ErrFile)
  if ($reaCmd) {
    & rea @ReaArgs 2>$ErrFile | Out-File -FilePath $OutFile -Encoding utf8
  } else {
    & $npx.Path -y $pkg @ReaArgs 2>$ErrFile | Out-File -FilePath $OutFile -Encoding utf8
  }
  return ($LASTEXITCODE -eq 0)
}

Write-Output '== 环境 =='
Write-Output "  JAVA_HOME          = $JavaHome"
Write-Output "  GHIDRA_INSTALL_DIR = $GhidraDir"
Write-Output "  REA 调用           = $(if ($reaCmd) { 'rea' } else { "npx -y $pkg" })"

# 硬性前置（不满足直接终止，避免后面一堆次生错误）
if ((Get-JdkMajor -JavaHome $JavaHome) -lt 21) { Stop-Fatal '未找到 JDK 21，请先运行 install.ps1（或设置 JAVA_HOME）' }
if (-not $GhidraDir -or -not (Test-Path -LiteralPath (Join-Path $GhidraDir 'support\analyzeHeadless.bat'))) {
  Stop-Fatal '未找到 Ghidra 的 support\analyzeHeadless.bat，请先运行 install.ps1'
}
$decompiler = Join-Path $GhidraDir 'Ghidra\Features\Decompiler\os\win_x86_64\decompile.exe'
if (-not (Test-Path -LiteralPath $decompiler)) {
  Stop-Fatal '未找到 native decompiler（win_x86_64\decompile.exe），官方 Windows x64 包应自带该文件'
}

$BinDir = Join-Path $Script:RepoRoot 'examples\bin\windows-x64'
$Fixture = Join-Path $BinDir 'demo.exe'
$Stripped = Join-Path $BinDir 'demo-stripped.exe'
$WorkDir = Join-Path $env:TEMP ("rea-verify-" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# ---- 1. 前置检查 ------------------------------------------------------------
Write-Output '== 1. 前置检查 =='
if (Get-Command node -ErrorAction SilentlyContinue) { Write-Pass 'node 存在' } else { Write-Fail '缺少 node' }
if (Test-Path -LiteralPath (Join-Path $GhidraDir 'support\analyzeHeadless.bat')) {
  Write-Pass 'analyzeHeadless.bat 存在'
} else { Write-Fail '未找到 Ghidra analyzeHeadless.bat（请先运行 install.ps1）' }

# ---- 2. 预编译 fixture 检查（替代 Linux 上的 gcc 编译步骤）------------------
Write-Output '== 2. 检查预编译 PE fixture =='
if (Test-Path -LiteralPath $Fixture) {
  Write-Pass '预编译 fixture（demo.exe）存在'
} else {
  Write-Fail "未找到 fixture：$Fixture（请确认仓库完整，不要删除 examples/bin）"
}
if (Test-Path -LiteralPath $Fixture) {
  $bytes = [System.IO.File]::ReadAllBytes($Fixture)[0..1]
  $isMZ = ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A)
  $hasSecret = (Select-String -LiteralPath $Fixture -Pattern 'secret_check' -SimpleMatch -Quiet -ErrorAction SilentlyContinue)
  $hasCalc = (Select-String -LiteralPath $Fixture -Pattern 'calc_discount' -SimpleMatch -Quiet -ErrorAction SilentlyContinue)
  if ($isMZ -and $hasSecret -and $hasCalc) {
    Write-Pass 'fixture 为有效 PE（MZ）且导出 secret_check / calc_discount'
  } else {
    Write-Fail "fixture 校验失败（MZ=$isMZ secret=$hasSecret calc=$hasCalc）"
  }
}

# ---- 3. analyze（含导出函数）-----------------------------------------------
Write-Output '== 3. analyze demo.exe =='
Write-Step '首次分析会启动 Ghidra headless，可能需 1-3 分钟…'
$aJson = Join-Path $WorkDir 'analyze.json'; $aErr = Join-Path $WorkDir 'analyze.err'
$ok = Invoke-ReaToFile -ReaArgs @('analyze', $Fixture, '--provider', 'ghidra', '--format', 'json',
        '--snapshot', (Join-Path $WorkDir 'demo.snap')) -OutFile $aJson -ErrFile $aErr
if ($ok) {
  Write-Pass 'analyze 命令成功'
  try {
    $d = Get-Content -LiteralPath $aJson -Raw | ConvertFrom-Json
    $fmt = $d.subject.format
    $arch = $d.subject.architecture
    $procs = [int]$d.normalized_result.procedure_count
    $strs = [int]$d.normalized_result.string_count
    if ($fmt -eq 'pe' -and $procs -ge 3 -and $strs -gt 0) {
      Write-Pass "识别 PE / $arch / 函数数(>=3) / 字符串（format=$fmt procs=$procs strings=$strs）"
    } else {
      Write-Fail "analyze 结构不符（format=$fmt procs=$procs strings=$strs）"
    }
  } catch {
    Write-Fail "analyze JSON 解析失败：$($_.Exception.Message)"
    Get-Content -LiteralPath $aJson -Raw -ErrorAction SilentlyContinue
  }
} else {
  Write-Fail 'analyze 失败'
  Get-Content -LiteralPath $aErr -Tail 15 -ErrorAction SilentlyContinue
}

# ---- 4. decompile secret_check ----------------------------------------------
Write-Output '== 4. decompile secret_check =='
$dJson = Join-Path $WorkDir 'secret.json'; $dErr = Join-Path $WorkDir 'secret.err'
$ok = Invoke-ReaToFile -ReaArgs @('decompile', $Fixture, 'secret_check', '--provider', 'ghidra',
        '--format', 'json', '--snapshot', (Join-Path $WorkDir 'demo.snap')) -OutFile $dJson -ErrFile $dErr
if ($ok) {
  try {
    $d = Get-Content -LiteralPath $dJson -Raw | ConvertFrom-Json
    $code = [string]$d.normalized_result
    if ($d.confidence -eq 'observed' -and $code.Contains('secret_check') -and $code.Contains('0x539')) {
      Write-Pass "secret_check 还原（observed，含 0x539=1337，confidence=$($d.confidence)）"
    } else {
      Write-Fail "decompile 结果不符（confidence=$($d.confidence)，name=$($code.Contains('secret_check'))，0x539=$($code.Contains('0x539'))）"
    }
  } catch { Write-Fail "secret_check JSON 解析失败：$($_.Exception.Message)" }
} else {
  Write-Fail 'secret_check 反编译失败'
  Get-Content -LiteralPath $dErr -Tail 15 -ErrorAction SilentlyContinue
}

# ---- 5. decompile calc_discount ---------------------------------------------
Write-Output '== 5. decompile calc_discount =='
$cJson = Join-Path $WorkDir 'calc.json'; $cErr = Join-Path $WorkDir 'calc.err'
$ok = Invoke-ReaToFile -ReaArgs @('decompile', $Fixture, 'calc_discount', '--provider', 'ghidra',
        '--format', 'json', '--snapshot', (Join-Path $WorkDir 'demo.snap')) -OutFile $cJson -ErrFile $cErr
if ($ok) {
  try {
    $d = Get-Content -LiteralPath $cJson -Raw | ConvertFrom-Json
    $code = [string]$d.normalized_result
    if ($d.confidence -eq 'observed' -and $code.Contains('calc_discount') -and $code.Contains('0x32')) {
      Write-Pass "calc_discount 还原（observed，含 0x32=50，confidence=$($d.confidence)）"
    } else {
      Write-Fail "calc_discount 结果不符（confidence=$($d.confidence)，0x32=$($code.Contains('0x32'))）"
    }
  } catch { Write-Fail "calc_discount JSON 解析失败：$($_.Exception.Message)" }
} else {
  Write-Fail 'calc_discount 反编译失败'
  Get-Content -LiteralPath $cErr -Tail 15 -ErrorAction SilentlyContinue
}

# ---- 6. analyze（剥离符号 / 无 PDB）----------------------------------------
Write-Output '== 6. analyze demo-stripped.exe（无符号）=='
$sJson = Join-Path $WorkDir 'stripped.json'; $sErr = Join-Path $WorkDir 'stripped.err'
$ok = Invoke-ReaToFile -ReaArgs @('analyze', $Stripped, '--provider', 'ghidra', '--format', 'json',
        '--snapshot', (Join-Path $WorkDir 'stripped.snap')) -OutFile $sJson -ErrFile $sErr
if ($ok) {
  try {
    $d = Get-Content -LiteralPath $sJson -Raw | ConvertFrom-Json
    $procs = [int]$d.normalized_result.procedure_count
    if ($procs -ge 3) { Write-Pass "无符号二进制仍可导入分析（procedures=$procs）" }
    else { Write-Fail "stripped 函数数异常（procs=$procs）" }
  } catch { Write-Fail "stripped JSON 解析失败：$($_.Exception.Message)" }
} else {
  Write-Fail 'stripped analyze 失败'
  Get-Content -LiteralPath $sErr -Tail 15 -ErrorAction SilentlyContinue
}

# ---- 汇总 -------------------------------------------------------------------
Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output ''
Write-Output '================================================'
Write-Output " 结果：$Pass 通过 / $Fail 失败"
Write-Output '================================================'
if ($Fail -eq 0) { exit 0 } else { exit 1 }

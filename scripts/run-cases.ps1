# =============================================================================
# run-cases.ps1 —— 端到端逆向案例库自动断言（Windows / PowerShell 版）
#
# 与 scripts/run-cases.sh 等价：
#   1) 编译 5 个案例的「带符号版」与「strip 版」（需要 make/gcc；不可用时回退到
#      已存在的 build/ 预编译产物，并给出明确提示）。
#   2) 对每个二进制调用 scripts/ghidra-export.ps1 -Kind all。
#   3) 读取 JSON，逐项断言【字符串 / 函数名 / 调用边 / 反编译常量】。
#   4) 打印 [PASS]/[FAIL] 中文结果与汇总，任一失败退出非 0。
#
# 用法：
#   pwsh -File scripts/run-cases.ps1
#   pwsh -File scripts/run-cases.ps1 -Help
# =============================================================================
[CmdletBinding()]
param(
  [switch]$Help
)

$ErrorActionPreference = "Stop"

# 复用公共函数（Ghidra/JDK 发现）
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$casesDir = Join-Path $repoRoot 'examples\cases'
$buildDir = Join-Path $casesDir 'build'
$exportPs1 = Join-Path $repoRoot 'scripts\ghidra-export.ps1'
$outRoot = Join-Path $buildDir 'ghidra-out'

$cases = @(
  '01-crackme-password',
  '02-license-key',
  '03-tiered-pricing',
  '04-switch-dispatch',
  '05-export-flow'
)

function Show-Usage {
  Write-Output 'run-cases.ps1 — 端到端逆向案例库自动断言'
  Write-Output '  pwsh -File scripts/run-cases.ps1           # 全量跑'
  Write-Output '  pwsh -File scripts/run-cases.ps1 -Help'
  Write-Output '  需要：Ghidra + JDK21（由 ghidra-export.ps1 自动发现）；编译需要 make/gcc 或已有 build/ 产物'
}

if ($Help) { Show-Usage; exit 0 }

# ---------- 工具函数 ----------
function Test-FileOrThrow($p) {
  if (-not (Test-Path $p)) { throw "缺少文件：$p" }
}

# 在反编译文本里同时接受 十六进制 token 或 十进制 token
function Test-DecompConst([string]$text, [string]$hexTok, [string]$decTok) {
  $low = $text.ToLower()
  if ($low.Contains($hexTok.ToLower())) { return $true }
  # 十进制按独立数字 token
  $pattern = '(?<![0-9a-fA-Fx])' + [regex]::Escape($decTok) + '\b'
  return [regex]::IsMatch($text, $pattern)
}

# 对单个二进制做断言。返回失败项数量。
function Invoke-CaseAssert {
  param(
    [string]$CaseName,
    [string]$Mode,      # 'symbols' | 'stripped'
    [string]$Dir
  )
  $script:badCount = 0
  function Check([bool]$ok, [string]$msg) {
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Output ("  [{0}] {1}/{2}: {3}" -f $tag, $CaseName, $Mode, $msg)
    if (-not $ok) { $script:badCount++ }
  }

  $funcs   = Get-Content (Join-Path $Dir 'functions.json')   -Raw | ConvertFrom-Json
  $strings = Get-Content (Join-Path $Dir 'strings.json')       -Raw | ConvertFrom-Json
  $symbols = Get-Content (Join-Path $Dir 'symbols.json')       -Raw | ConvertFrom-Json
  $calls   = Get-Content (Join-Path $Dir 'calls.json')          -Raw | ConvertFrom-Json
  $decomp  = Get-Content (Join-Path $Dir 'decompiled.json')    -Raw | ConvertFrom-Json

  $funcNames = @{}
  foreach ($f in $funcs) { $funcNames[$f.name] = $true }

  $callees = @{}
  foreach ($c in $calls) { $callees[$c.callee] = $true }

  $symNameSet = @{}
  foreach ($s in $symbols) { $symNameSet[$s.name] = $true }

  # 跨平台归一化：Mach-O 给 C 符号加前导下划线（_printf）；去命名空间末段与下划线后比较。
  $externSet = @{}
  foreach ($k in @($symNameSet.Keys) + @($callees.Keys)) {
    if (-not $k) { continue }
    $seg = ($k -split '::')[-1]
    $n = if ($seg.StartsWith('_') -and $seg.Length -gt 1) { $seg.Substring(1) } else { $seg }
    if ($n) { $externSet[$n] = $true }
  }

  $strText = ($strings | ForEach-Object { $_.value }) -join "`n"

  $decompText = ''
  foreach ($p in $decomp.PSObject.Properties) { $decompText += "`n" + $p.Value }

  $isStripped = ($Mode -eq 'stripped')

  switch ($CaseName) {
    '01-crackme-password' {
      Check ($strText.Contains('S3cr3t-2026')) '字符串表含硬编码口令 S3cr3t-2026'
      Check ($strText.Contains('ACCESS GRANTED')) '字符串表含 ACCESS GRANTED'
      if (-not $isStripped) { Check ($funcNames.ContainsKey('check_password')) '函数表含 check_password' }
      Check ($externSet.ContainsKey('strcmp')) '调用边出现 strcmp（跨平台）'
    }
    '02-license-key' {
      Check (Test-DecompConst $decompText '0x5a' '90')   '反编译含异或常量 0x5a(90)'
      Check (Test-DecompConst $decompText '0x1b7' '439') '反编译含魔数 0x1b7(439)'
      Check ($strText.Contains('LICENSE OK')) '字符串表含 LICENSE OK'
      if (-not $isStripped) { Check ($funcNames.ContainsKey('verify_key')) '函数表含 verify_key' }
    }
    '03-tiered-pricing' {
      Check (Test-DecompConst $decompText '0x32' '50') '反编译含满减常量 0x32(50)'
      Check ([regex]::IsMatch($decompText, '(?<![0-9])100\b')) '反编译含高数量阈值 100(0x64)'
      if (-not $isStripped) { Check ($funcNames.ContainsKey('compute_price')) '函数表含 compute_price' }
    }
    '04-switch-dispatch' {
      foreach ($s in @('login-menu','buy-menu','about-menu','exit-menu')) {
        Check ($strText.Contains($s)) "字符串表含 $s"
      }
      if (-not $isStripped) {
        Check ($callees.ContainsKey('do_login')) '调用边出现 do_login'
        Check ($callees.ContainsKey('do_buy'))   '调用边出现 do_buy'
        Check ($callees.ContainsKey('do_exit'))  '调用边出现 do_exit'
        Check ($funcNames.ContainsKey('dispatch')) '函数表含 dispatch'
      }
    }
    '05-export-flow' {
      Check ($funcs.Count   -ge 1) "functions 非空（$($funcs.Count)）"
      Check ($strings.Count -ge 1) "strings 非空（$($strings.Count)）"
      Check ($calls.Count   -ge 1) "calls 非空（$($calls.Count)）"
      Check ($symbols.Count -ge 1) "symbols 非空（$($symbols.Count)）"
      foreach ($lib in @('printf','strlen','strcmp')) {
        Check ($externSet.ContainsKey($lib)) "识别 libc 导入 $lib（跨平台）"
      }
    }
    default {
      Check $false "未知案例 $CaseName"
    }
  }

  if ($script:badCount -gt 0) {
    Write-Output "[FAIL] $CaseName/$Mode 共 $($script:badCount) 项失败"
  } else {
    Write-Output "[PASS] $CaseName/$Mode 全部断言通过"
  }
  return $script:badCount
}

# ---------- 主流程 ----------
Write-Output '==> [1/3] 编译全部案例'
$built = $false
if (Get-Command make -ErrorAction SilentlyContinue) {
  & make -C $casesDir clean
  & make -C $casesDir all
  if ($LASTEXITCODE -eq 0) { $built = $true }
}
if (-not $built -and (Test-Path (Join-Path $buildDir '01-crackme-password.exe'))) {
  Write-Output '    未找到 make，使用已存在的 build/ 预编译产物。'
  $built = $true
}
if (-not $built) {
  Write-Output '    [提示] 未找到 make/gcc 且无预编译产物；请在 WSL/MSYS2 中 make，或预先放好 build/ 产物。'
}

Write-Output '==> [2/3] 准备导出目录（幂等清空）'
if (Test-Path $outRoot) { Remove-Item -Recurse -Force $outRoot }
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$failTotal = 0
Write-Output '==> [3/3] 逐二进制导出并断言'

foreach ($c in $cases) {
  foreach ($variant in @(@{stem=$c; mode='symbols'}, @{stem="$c-stripped"; mode='stripped'})) {
    $stem = $variant.stem
    $mode = $variant.mode
    # Windows 可执行文件可能是 .exe；兼容两种命名
    $bin = Join-Path $buildDir $stem
    if (-not (Test-Path $bin)) { $bin = "$bin.exe" }
    Write-Output '----------------------------------------------------------------'
    Write-Output ">> 导出 $stem  [$mode]"
    if (-not (Test-Path $bin)) {
      Write-Output "[FAIL] ${stem}: 二进制不存在（需先编译或提供预编译产物）"
      $failTotal++
      continue
    }
    $out = Join-Path $outRoot $stem
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    try {
      & $exportPs1 -Bin $bin -Out $out -Kind all | Out-Null
    } catch {
      Write-Output "[FAIL] ${stem}: ghidra-export.ps1 异常：$($_.Exception.Message)"
      $failTotal++
      continue
    }
    $bad = Invoke-CaseAssert -CaseName $c -Mode $mode -Dir $out
    if ($bad -gt 0) { $failTotal++ }
  }
}

Write-Output '=================================================================='
if ($failTotal -ne 0) {
  Write-Output "汇总：有 $failTotal 个二进制断言失败（详见上方 [FAIL]）"
  exit 1
}
Write-Output '汇总：全部 10 个二进制（5 案例 × 带符号/strip）断言通过'
exit 0

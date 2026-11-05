# =============================================================================
# lib/rea-wrap.ps1 — v5.4.0 统一 REA 命令包装器（PowerShell，仅被 dot-source）
#
# 与 lib/rea-wrap.sh 对等：统一环境解析 + 包装器开关 + 稳定退出码。
# 运行时只依赖入库基线 config/command-baseline/command-domain.tsv（175 行），
# 不依赖 gitignored 的 research/。
#
# 提供：
#   Get-ReaCommandRecord <cmd>   返回 @{Domain;Testability}；命令不在基线返回 $null
#   Get-ReaDomainsTable          返回 [pscustomobject]@{Domain;Count}[]（10 行）
#   Invoke-ReaCommand            解析 -Rest（= <cmd> [开关] [-- 透传...]）并执行，
#                                可选 -ExpectedDomain 做领域归属校验；返回退出码
#
# 包装器开关（在透传前解析；`--` 之后全部原样透传给 REA）：
#   --json / --schema / --out <file> / --quiet / --
#
# 退出码（本包装器在 REA 之上叠加的稳定分类；REA 原生只有 0/1）：
#   0 成功；2 用法错误（基线/开关/缺值，调用 npx 前判定）；
#   3 前置缺失（1-core-native 命令解析不到 JDK/Ghidra，不调用 npx）；
#   4 运行时失败（REA 已执行但返回非 0）。
#
# 注意：2/3/4 是本包装器根据预检查与 REA 退出码映射产生的分类，
#       并非 REA 原生返回码（REA 自身只返回 0 与 1）。
# =============================================================================

# 复用 common.ps1（Resolve-JdkHome / Resolve-GhidraDir / Get-ReaMirrorMode / Import-VersionConfig）
. (Join-Path $PSScriptRoot 'common.ps1')

$script:ReaDomainTsv = Join-Path $Script:RepoRoot 'config/command-baseline/command-domain.tsv'

# 命令名 -> @{Domain;Testability}；找不到返回 $null
function Get-ReaCommandRecord {
  param([Parameter(Mandatory)][string]$Command)
  if (-not (Test-Path -LiteralPath $script:ReaDomainTsv)) { return $null }
  foreach ($line in Get-Content -LiteralPath $script:ReaDomainTsv) {
    if (-not $line) { continue }
    $f = $line -split "`t"
    if ($f.Count -ge 3 -and $f[0] -eq $Command) {
      return [pscustomobject]@{ Domain = $f[1]; Testability = $f[2] }
    }
  }
  return $null
}

# 返回 [pscustomobject]@{Domain;Count}[]（按 Domain 排序）
function Get-ReaDomainsTable {
  $counts = @{}
  foreach ($line in Get-Content -LiteralPath $script:ReaDomainTsv) {
    if (-not $line) { continue }
    $f = $line -split "`t"
    if ($f.Count -lt 2) { continue }
    if ($counts.ContainsKey($f[1])) { $counts[$f[1]]++ } else { $counts[$f[1]] = 1 }
  }
  $counts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Domain = $_.Key; Count = $_.Value }
  }
}

# d1..d10 标签 -> 领域名
function Get-ReaDomainName {
  param([Parameter(Mandatory)][string]$Label)
  switch ($Label) {
    'd1'  { return '1-core-native' }
    'd2'  { return '2-offline-binary' }
    'd3'  { return '3-dynamic-debug' }
    'd4'  { return '4-web-js-electron' }
    'd5'  { return '5-android-adb' }
    'd6'  { return '6-apple' }
    'd7'  { return '7-multiformat' }
    'd8'  { return '8-firmware-embedded' }
    'd9'  { return '9-evidence-engineering' }
    'd10' { return '10-platform-jeb' }
    default { return '' }
  }
}

# 解析环境并 export：成功就设置进程 env，失败不在这里报错。
function Initialize-ReaEnvironment {
  $cfg = Import-VersionConfig
  $jh = Resolve-JdkHome
  if ($jh) { $env:JAVA_HOME = $jh }
  $gd = Resolve-GhidraDir
  if ($gd) { $env:GHIDRA_INSTALL_DIR = $gd }
  return $cfg
}

# 真正的包装执行：返回退出码 0/2/3/4
# -Rest: <cmd> [开关...] [-- 透传...]
# -ExpectedDomain: 若非空，要求命令的领域与之相等，否则返回 2
function Invoke-ReaCommand {
  param(
    [string]$ExpectedDomain = '',
    [Parameter(Mandatory)][string[]]$Rest
  )

  if ($Rest.Count -lt 1 -or [string]::IsNullOrWhiteSpace($Rest[0])) {
    Write-Host 'rea-wrap: 缺少命令名（用 run <命令>）' -ForegroundColor Red
    return 2
  }
  $cmd = $Rest[0]

  # ---- 解析包装器开关（-- 之后全部透传）----
  $forceJson = $false; $wantSchema = $false; $quiet = $false; $outFile = $null
  $passthrough = @()
  $i = 1
  if ($Rest.Count -gt 1) {
    while ($i -lt $Rest.Count) {
      $a = [string]$Rest[$i]
      if ($a -eq '--') {
        if ($i + 1 -lt $Rest.Count) { $passthrough = @($Rest[($i + 1)..($Rest.Count - 1)]) }
        break
      }
      switch -Wildcard ($a) {
        '--json'    { $forceJson = $true; $i++ }
        '--schema'  { $wantSchema = $true; $i++ }
        '--quiet'   { $quiet = $true; $i++ }
        '--out' {
          if ($i + 1 -ge $Rest.Count) {
            Write-Host 'rea-wrap: --out 需要一个文件路径参数' -ForegroundColor Red; return 2
          }
          $outFile = [string]$Rest[$i + 1]; $i += 2
        }
        '--out=*' { $outFile = $a.Substring(6); $i++ }
        default {
          Write-Host "rea-wrap: 未知包装器开关：$a" -ForegroundColor Red
          Write-Host '        可用：--json --schema --out <file> --quiet --（其后透传 REA）'
          return 2
        }
      }
    }
  }

  # ---- 1) 命令必须在基线 ----
  $rec = Get-ReaCommandRecord -Command $cmd
  if ($null -eq $rec) {
    Write-Host "rea-wrap: 未知命令：$cmd（不在 rea-agents 基线的 175 个命令内）" -ForegroundColor Red
    return 2
  }
  if ($ExpectedDomain -ne '' -and $rec.Domain -ne $ExpectedDomain) {
    Write-Host "rea-wrap: 命令 '$cmd' 属于领域 '$($rec.Domain)'，不是 '$ExpectedDomain'" -ForegroundColor Red
    Write-Host "        （用 ./rea-ghidra.ps1 run $cmd 直接跑，或选对应 dN 领域入口）"
    return 2
  }

  # ---- 2) 前置解析 ----
  $cfg = Initialize-ReaEnvironment
  if ($rec.Domain -eq '1-core-native') {
    if (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
      Write-Host "rea-wrap: 命令 '$cmd' 属于 1-core-native，需要 JDK 21，但未解析到可用 JAVA_HOME（请先运行 .\rea-ghidra.ps1 install）" -ForegroundColor Red
      return 3
    }
    if (-not $env:GHIDRA_INSTALL_DIR -or -not (Test-Path -LiteralPath (Join-Path $env:GHIDRA_INSTALL_DIR 'support\analyzeHeadless.bat'))) {
      Write-Host "rea-wrap: 命令 '$cmd' 属于 1-core-native，需要 Ghidra，但未解析到 GHIDRA_INSTALL_DIR（请先运行 .\rea-ghidra.ps1 install）" -ForegroundColor Red
      return 3
    }
  }

  # ---- 3) 构造 REA 调用 ----
  $reaCmd = @()
  if (Get-Command rea -ErrorAction SilentlyContinue) {
    $reaCmd = @('rea')
  } else {
    $reaCmd = @('npx', '-y', "rea-agents@$($cfg.REA_VERSION)")
    if ((Get-ReaMirrorMode) -eq 'cn') { $env:npm_config_registry = 'https://registry.npmmirror.com' }
  }

  $final = @($cmd) + $passthrough
  if ($forceJson)  { $final += @('--format', 'json') }
  if ($wantSchema) { $final += '--schema' }

  # PS 的 & $array 会把数组合并成一个命令名串；必须取首元素作命令、其余 splat 成参数
  $exe = $reaCmd[0]
  $exeArgs = @()
  if ($reaCmd.Count -gt 1) { $exeArgs = $reaCmd[1..($reaCmd.Count - 1)] }
  $allArgs = $exeArgs + $final

  # ---- 4) 执行 ----
  if ($outFile) {
    $parent = Split-Path -Parent $outFile
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    if ($quiet) { & $exe @allArgs > $outFile 2>$null } else { & $exe @allArgs > $outFile }
  } else {
    if ($quiet) { & $exe @allArgs 2>$null } else { & $exe @allArgs }
  }
  $rc = $LASTEXITCODE

  # ---- 5) 退出码映射 ----
  if ($rc -eq 0) { return 0 }
  Write-Host "rea-wrap: REA 执行 '$cmd' 返回非 0（rc=$rc）" -ForegroundColor Red
  return 4
}

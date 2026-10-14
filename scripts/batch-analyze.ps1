# batch-analyze.ps1 — 批量并行 Ghidra 静态分析（v2.7 单目标导出之上编排）。
# 不依赖 REA / Node。多目标并行（Start-Job 节流，PS5.1/7 通吃）、失败隔离、sha256 快照缓存。
#
# 用法：
#   pwsh -File scripts/batch-analyze.ps1 -Bin <bin>[,bin2...] [-Dir DIR] [-Recurse] [-Pattern *.elf]
#                            [-Out DIR] [-Kind all] [-Jobs N] [-Retries M] [-Snapshot DIR] [-Continue]
#   pwsh -File scripts/batch-analyze.ps1 -Help
param(
  [string[]]$Bin = @(),
  [string]$Dir = "",
  [switch]$Recurse,
  [string]$Pattern = "",
  [string]$Out = ".\batch-out",
  [ValidateSet("functions","strings","symbols","calls","decompiled","all")]
  [string]$Kind = "all",
  [int]$Jobs = 0,
  [int]$Retries = 1,
  [string]$Snapshot = "",
  [switch]$Continue,
  [switch]$Help
)
$ErrorActionPreference = "Stop"
$ExportSchemaVersion = 1

if ($Help) {
  Write-Output "batch-analyze.ps1 — 批量并行 Ghidra 导出"
  Write-Output "  -Bin <路径[]>    一个或多个二进制"
  Write-Output "  -Dir DIR         额外收集目录（-Recurse 递归，-Pattern glob 过滤）"
  Write-Output "  -Out DIR         输出根目录（默认 .\batch-out）"
  Write-Output "  -Kind <kind>     functions|strings|symbols|calls|decompiled|all（默认 all）"
  Write-Output "  -Jobs N          并行数（默认取 CPU 数，封顶 4）"
  Write-Output "  -Retries M       单目标失败重试（默认 1）"
  Write-Output "  -Snapshot DIR    快照缓存目录（不传则不缓存）"
  Write-Output "  -Continue        已有完整产物则跳过"
  exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exporter = Join-Path $scriptDir "ghidra-export.ps1"

# 收集目标
$targets = New-Object System.Collections.Generic.List[string]
foreach ($b in $Bin) { if (Test-Path -LiteralPath $b -PathType Leaf) { $targets.Add($b) } }
if ($Dir -ne "") {
  $files = if ($Recurse) { Get-ChildItem -LiteralPath $Dir -Recurse -File } else { Get-ChildItem -LiteralPath $Dir -File }
  foreach ($f in $files) {
    if ($Pattern -eq "" -or $f.Name -like $Pattern) { $targets.Add($f.FullName) }
  }
}
if ($targets.Count -eq 0) { throw "未收集到任何目标文件" }

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$targetsRoot = Join-Path $Out "targets"
New-Item -ItemType Directory -Force -Path $targetsRoot | Out-Null

# jobs：CPU 数封顶 4，不超过目标数
if ($Jobs -le 0) { $Jobs = [Environment]::ProcessorCount }
if ($Jobs -gt 4) { $Jobs = 4 }
if ($Jobs -gt $targets.Count) { $Jobs = $targets.Count }
if ($Jobs -lt 1) { $Jobs = 1 }

Write-Output ("[batch] 目标数=" + $targets.Count + "  jobs=" + $Jobs + "  kind=" + $Kind + "  snapshot=" + ($(if ($Snapshot) { $Snapshot } else { "(无)" })))

# kind 对应产物标记
$markMap = @{ functions="functions.json"; strings="strings.json"; symbols="symbols.json"; calls="calls.json"; decompiled="decompiled.json"; all="functions.json" }
$mark = $markMap[$Kind]

$results = New-Object System.Collections.Generic.List[object]
$running = @()
$queue = New-Object System.Collections.Queue
foreach ($t in $targets) { $queue.Enqueue($t) }

function Start-OneTarget {
  param([string]$Target)
  $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $Target).Hash.ToLower()
  $sha12 = $sha.Substring(0,12)
  $tOut = Join-Path $targetsRoot $sha12
  New-Item -ItemType Directory -Force -Path $tOut | Out-Null
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  # 快照命中
  if ($Snapshot -ne "") {
    $cDir = Join-Path $Snapshot ($sha + "_" + $Kind + "_v" + $ExportSchemaVersion)
    if (Test-Path -LiteralPath (Join-Path $cDir $mark)) {
      Copy-Item (Join-Path $cDir "*.json") $tOut -Force -ErrorAction SilentlyContinue
      $sw.Stop()
      return [pscustomobject]@{ input=$Target; sha256=$sha; status="success"; cached=$true; elapsed_sec=[int]$sw.Elapsed.TotalSeconds; retries=0; out_dir=$tOut; error="" }
    }
  }
  # continue
  if ($Continue -and (Test-Path -LiteralPath (Join-Path $tOut $mark))) {
    $sw.Stop()
    return [pscustomobject]@{ input=$Target; sha256=$sha; status="skipped"; cached=$false; elapsed_sec=[int]$sw.Elapsed.TotalSeconds; retries=0; out_dir=$tOut; error="" }
  }

  $tries = 0; $ok = $false; $err = ""
  while ($tries -le $Retries -and -not $ok) {
    $tries++
    $log = Join-Path $tOut "headless.log"
    & pwsh -NoProfile -File $exporter -Bin $Target -Out $tOut -Kind $Kind *> $log
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath (Join-Path $tOut $mark))) { $ok = $true }
    else { $err = (Get-Content $log -Tail 3 -ErrorAction SilentlyContinue) -join " " }
  }
  if ($ok -and $Snapshot -ne "") {
    $cDir = Join-Path $Snapshot ($sha + "_" + $Kind + "_v" + $ExportSchemaVersion)
    New-Item -ItemType Directory -Force -Path $cDir | Out-Null
    Copy-Item (Join-Path $tOut "*.json") $cDir -Force -ErrorAction SilentlyContinue
  }
  $sw.Stop()
  return [pscustomobject]@{ input=$Target; sha256=$sha; status=$(if ($ok) {"success"} else {"failed"}); cached=$false; elapsed_sec=[int]$sw.Elapsed.TotalSeconds; retries=$tries; out_dir=$tOut; error=$err }
}

# 节流：最多 $Jobs 个 Start-Job 并行
$start = Get-Date
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
    $t = $queue.Dequeue()
    $running += Start-Job -ScriptBlock ${function:Start-OneTarget} -ArgumentList $t
  }
  if ($running.Count -gt 0) {
    $done = $running | Wait-Job -Any
    foreach ($j in $done) {
      $results += Receive-Job $j
      Remove-Job $j
      $running = @($running | Where-Object { $_.Id -ne $j.Id })
    }
  }
}
$elapsed = [int]((Get-Date) - $start).TotalSeconds

$succ = @($results | Where-Object { $_.status -eq "success" }).Count
$fail = @($results | Where-Object { $_.status -eq "failed" }).Count
$skip = @($results | Where-Object { $_.status -eq "skipped" }).Count
$cached = @($results | Where-Object { $_.cached }).Count
$summary = [pscustomobject]@{
  export_schema_version = $ExportSchemaVersion; total=$results.Count; success=$succ; failed=$fail;
  skipped=$skip; cached=$cached; total_elapsed_sec=$elapsed; targets=$results
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Out "summary.json") -Encoding UTF8
Write-Output ("[batch] 完成：成功 " + $succ + " / 失败 " + $fail + " / 跳过 " + $skip + "（缓存命中 " + $cached + "），总耗时 " + $elapsed + "s")
foreach ($r in $results) {
  $tag = $r.status.ToUpper() + $(if ($r.cached) { "(cached)" })
  Write-Output ("  - " + $tag.PadRight(16) + " " + (Split-Path -Leaf $r.input) + "  " + $r.elapsed_sec + "s")
}
if ($fail -gt 0) { exit 1 }

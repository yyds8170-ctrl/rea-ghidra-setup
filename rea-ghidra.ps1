<#
.SYNOPSIS
  rea-ghidra 统一入口（Windows PowerShell 5.1 / 7）。极薄分发层：定位仓库根 → 选脚本 → 透传参数并保留退出码。
.EXAMPLE
  .\rea-ghidra.ps1 install
  .\rea-ghidra.ps1 verify
  .\rea-ghidra.ps1 mcp --check
#>
$ErrorActionPreference = 'Stop'
# PS7 下避免原生命令往 stderr 打 WARNING 被当终止错误（PS5.1 无此变量，用 try）
try { $PSNativeCommandUseErrorActionPreference = $false } catch {}

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# 跨平台安全：USERPROFILE 为空时回退 HOME / UserProfile
$ToolsDir = $env:TOOLS_DIR
if (-not $ToolsDir) {
  if ($env:USERPROFILE) { $ToolsDir = Join-Path $env:USERPROFILE 'tools' }
  elseif ($HOME) { $ToolsDir = Join-Path $HOME 'tools' }
  else { $ToolsDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'tools' }
}
# 复用公共库（Resolve-JdkHome/Resolve-GhidraDir/New-ToolJunction）
. (Join-Path $RepoDir 'lib\common.ps1')

function Usage {
@'
rea-ghidra 一体化入口（v3.0）

用法：.\rea-ghidra.ps1 <子命令> [参数...]

子命令：
  install        安装 JDK21 + Ghidra + 便携 Node（install.ps1）
  doctor         只读环境自检（doctor.ps1）
  verify         端到端验证 9 项（verify.ps1）
  mcp ...        MCP 客户端对接，如：.\rea-ghidra.ps1 mcp --check
  export ...     Ghidra 静态导出，如：.\rea-ghidra.ps1 export .\examples\demo --out C:\tmp\out --kind all
  batch ...      批量并行 + 快照缓存（batch-analyze.ps1）
  fixtures       交叉编译 fixture（需 bash 交叉链，Windows 请在 WSL/CI linux 跑）
  walkthrough    端到端演练（bash 脚本，Windows 请在 WSL/CI 跑）
  version        打印本仓库 VERSION；--check 联网查最新 release（只读）
  self-update    自更新（git 副本 ff-only；tarball 校验 checksums）；--check 只报告
  current        列出 tools 下 Ghidra/JDK 版本与 current 联接指向
  rollback       把 current 切回上一版本（多版本并存时生效）
  help           本帮助
'@
}

# 透传一个 ps1 脚本并保留退出码
function Run-Target([string]$script, [string[]]$rest) {
  & (Join-Path $RepoDir $script) @rest
  exit $LASTEXITCODE
}

function Get-Version {
  $v = 'unknown'
  try { $v = (Get-Content (Join-Path $RepoDir 'VERSION') -ErrorAction Stop).Trim() } catch {}
  Write-Host "当前版本：$v"
  if ($args -contains '--check') {
    try {
      $meta = Invoke-RestMethod -Uri 'https://api.github.com/repos/yyds8170-ctrl/rea-ghidra-setup/releases/latest' -TimeoutSec 10
      Write-Host "最新 release：$($meta.tag_name)"
    } catch { Write-Host "（离线或限流，无法查询最新版，跳过）" }
  }
}

function Show-Current {
  Write-Host "TOOLS_DIR：$ToolsDir"
  Write-Host "Ghidra 版本化安装："
  Get-ChildItem -Path $ToolsDir -Filter 'ghidra_*_PUBLIC' -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.FullName)" }
  Write-Host "JDK 版本化安装："
  Get-ChildItem -Path $ToolsDir -Filter 'jdk-21*' -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.FullName)" }
  $cg = Join-Path $ToolsDir 'current-ghidra'
  $cj = Join-Path $ToolsDir 'current-jdk'
  if (Test-Path -LiteralPath $cg) { Write-Host "current-ghidra -> $((Get-Item -LiteralPath $cg).Target)" } else { Write-Host "current-ghidra（未设置）" }
  if (Test-Path -LiteralPath $cj) { Write-Host "current-jdk     -> $((Get-Item -LiteralPath $cj).Target)" } else { Write-Host "current-jdk（未设置）" }
}

function Invoke-Rollback {
  $list = @(Get-ChildItem -Path $ToolsDir -Filter 'ghidra_*_PUBLIC' -Directory -ErrorAction SilentlyContinue)
  if ($list.Count -lt 2) {
    Write-Host "无可回滚版本：~/tools 下只发现 $($list.Count) 个 Ghidra 安装。"
    Write-Host "（config 只锁一个 Ghidra 版本；并存多版本目录后此命令才生效。）"
    return
  }
  $cg = Join-Path $ToolsDir 'current-ghidra'
  $cur = $null
  if (Test-Path -LiteralPath $cg) { $cur = (Get-Item -LiteralPath $cg).Target }
  $target = $null
  foreach ($d in $list) { if ($d.FullName -ne $cur) { $target = $d.FullName } }
  if (-not $target) { Write-Host '无可回滚版本。'; return }
  Write-Host "记录当前 -> $cur"
  Set-Content -LiteralPath (Join-Path $ToolsDir 'current.previous') -Value $cur -ErrorAction SilentlyContinue
  try {
    New-ToolJunction -LinkName $cg -Target $target
    Write-Host "current-ghidra 已切换 -> $target"
  } catch {
    Write-Host "（非 Windows 无 mklink，无法切换 junction；请在真实 Windows 或 WSL 执行。）"
  }
}

# 受保护路径（不覆盖/不删除）：offline/ examples/fixtures/ .git/，兼容 / 与 \
function Test-Protected {
  param([string]$Rel)
  $norm = $Rel -replace '\\','/'
  return ($norm -match '(^|/)(offline|examples/fixtures|\.git)(/|$)')
}

# 应用一个已校验的 tarball 到 RepoDir：备份旧文件→覆盖；--DryRun 只列不写。
# 返回 hashtable：Updated / Skipped / BackupDir
function Invoke-TarballApply {
  param(
    [Parameter(Mandatory)][string]$ExtractRoot,
    [Parameter(Mandatory)][string]$RepoDir,
    [switch]$DryRun
  )
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backup = Join-Path $RepoDir ('.self-update-backup-' + $stamp)
  $updated = 0; $skipped = 0
  $files = Get-ChildItem -LiteralPath $ExtractRoot -Recurse -File
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($ExtractRoot.Length).TrimStart('\','/')
    $relFwd = $rel -replace '\\','/'
    if (Test-Protected $relFwd) { $skipped++; continue }
    $dest = Join-Path $RepoDir $rel
    if ($DryRun) {
      if (Test-Path -LiteralPath $dest) { Write-Host "  [dry-run] 覆盖：$relFwd" } else { Write-Host "  [dry-run] 新增：$relFwd" }
      $updated++; continue
    }
    if (Test-Path -LiteralPath $dest) {
      $bd = Split-Path -Parent (Join-Path $backup $rel)
      New-Item -ItemType Directory -Force -Path $bd | Out-Null
      Copy-Item -LiteralPath $dest -Destination (Join-Path $backup $rel) -Force
    }
    $dd = Split-Path -Parent $dest
    New-Item -ItemType Directory -Force -Path $dd | Out-Null
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    $updated++
  }
  return @{ Updated = $updated; Skipped = $skipped; BackupDir = $backup }
}

function Invoke-SelfUpdate {
  param([string[]]$Rest)
  $v = 'unknown'
  try { $v = (Get-Content (Join-Path $RepoDir 'VERSION') -ErrorAction Stop).Trim() } catch {}
  Write-Host "当前版本：$v"
  $isCheck = ($Rest -contains '--check')
  $isDry = ($Rest -contains '--dry-run')
  if (Test-Path (Join-Path $RepoDir '.git')) {
    if ($isCheck) {
      Write-Host '（--check）只 fetch 对比，不写盘。'
      git -C $RepoDir fetch --tags 2>$null | Out-Null
      Write-Host 'git 副本：如需更新请手动 git pull --ff-only（入口不自动 stash/覆盖）。'
      return
    }
    if ((git -C $RepoDir status --porcelain) -and (git -C $RepoDir status --porcelain).Count -gt 0) {
      Write-Host '检测到本地未提交改动：为避免覆盖，请先 commit/stash，再运行 self-update。' -ForegroundColor Yellow
      exit 1
    }
    git -C $RepoDir pull --ff-only
    exit $LASTEXITCODE
  }

  # 非 git（Release tarball 解压）副本
  $api = 'https://api.github.com/repos/yyds8170-ctrl/rea-ghidra-setup/releases/latest'
  $meta = $null
  try { $meta = Invoke-RestMethod -Uri $api -TimeoutSec 15 } catch { $meta = $null }
  if ($null -eq $meta) {
    Write-Host '（离线或限流，无法查询最新 release，跳过。）'
    return
  }
  $tag = $meta.tag_name
  Write-Host "最新 release：$tag"
  if ($tag -eq ('v' + $v)) { Write-Host '已是最新。'; return }
  if ($isCheck) { Write-Host "有新版本可用：$v -> $tag（--check 不写盘）"; return }

  $tgz = "https://github.com/yyds8170-ctrl/rea-ghidra-setup/releases/download/$tag/rea-ghidra-setup-$tag.tar.gz"
  $sumUrl = "$tgz.checksums.txt"
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('rea-su-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $outTgz = Join-Path $tmp 'app.tar.gz'
  try {
    Invoke-WebRequest -Uri $tgz -OutFile $outTgz -TimeoutSec 120
  } catch { Write-Host "下载 tar.gz 失败：$($_.Exception.Message)" -ForegroundColor Red; exit 1 }
  $expected = $null
  try {
    $sumText = (Invoke-WebRequest -Uri $sumUrl -TimeoutSec 20).Content
    $expected = ($sumText -split '\s+')[0]
  } catch { $expected = $null }
  if ([string]::IsNullOrWhiteSpace($expected)) {
    Write-Host '取不到 checksums.txt，安全起见拒绝更新。' -ForegroundColor Red; exit 1
  }
  $actual = (Get-FileHash -LiteralPath $outTgz -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $expected.ToLower()) {
    Write-Host "校验失败：tar.gz sha256($actual) != checksums($expected)，拒绝更新。" -ForegroundColor Red; exit 1
  }
  Write-Host '校验通过（sha256 一致）。解压……'
  if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
    Write-Host '未找到 tar（bsdtar），无法解压，中止。' -ForegroundColor Red; exit 1
  }
  & tar -xzf $outTgz -C $tmp
  if ($LASTEXITCODE -ne 0) { Write-Host 'tar 解压失败。' -ForegroundColor Red; exit 1 }
  $root = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { $_.Name -like 'rea-ghidra-setup-*' } | Select-Object -First 1
  if (-not $root) { Write-Host '解压后未找到 rea-ghidra-setup-<tag>/ 目录。' -ForegroundColor Red; exit 1 }
  $res = Invoke-TarballApply -ExtractRoot $root.FullName -RepoDir $RepoDir -DryRun:$isDry
  if ($isDry) {
    Write-Host ("（--dry-run：将更新 {0} 个文件，受保护跳过 {1} 个，未写盘。）" -f $res.Updated, $res.Skipped)
  } else {
    Write-Host ("更新完成：覆盖/新增 {0} 个文件；受保护路径跳过 {1} 个。" -f $res.Updated, $res.Skipped)
    Write-Host ("旧文件备份在：{0}" -f $res.BackupDir)
    Write-Host "如需回滚：Copy-Item -Recurse -Force `"$($res.BackupDir)\*`" `"$RepoDir`""
    Write-Host ("新版本：{0}" -f (Get-Content (Join-Path $RepoDir 'VERSION') -ErrorAction SilentlyContinue).Trim())
  }
}

$sub = ''
if ($args.Count -gt 0) { $sub = $args[0]; $rest = @($args[1..($args.Count-1)]) } else { $rest = @() }

switch -Wildcard ($sub) {
  ''          { Usage; exit 0 }
  '-h'        { Usage; exit 0 }
  '--help'    { Usage; exit 0 }
  'help'      { Usage; exit 0 }
  'install'   { Run-Target 'install.ps1' $rest }
  'doctor'    { Run-Target 'scripts\doctor.ps1' $rest }
  'verify'    { Run-Target 'verify.ps1' $rest }
  'mcp'       { Run-Target 'scripts\mcp-setup.ps1' $rest }
  'export'    { Run-Target 'scripts\ghidra-export.ps1' $rest }
  'batch'     { Run-Target 'scripts\batch-analyze.ps1' $rest }
  'fixtures'  { Write-Host 'fixtures 需要 i686/aarch64/mingw 交叉工具链（Linux），请在 WSL 或 CI ubuntu 作业运行：bash scripts/build-fixtures.sh'; exit 0 }
  'walkthrough' { Write-Host 'walkthrough 是 bash 演练脚本，请在 WSL 或 CI linux 运行：bash examples/walkthrough.sh'; exit 0 }
  'version'   { Get-Version @rest; exit 0 }
  'current'   { Show-Current; exit 0 }
  'rollback'  { Invoke-Rollback; exit 0 }
  'self-update' { Invoke-SelfUpdate -Rest $rest; exit 0 }
  default { Write-Host "未知子命令：$sub（用 .\rea-ghidra.ps1 help 查看全部）" -ForegroundColor Red; exit 2 }
}

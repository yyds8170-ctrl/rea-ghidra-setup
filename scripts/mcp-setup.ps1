<#
.SYNOPSIS
  REA MCP server 一键注册 + 连接自检（Windows；PS 5.1/7 兼容，也可在 Linux pwsh 下跑 -DryRun/-List）。

.DESCRIPTION
  与 scripts/mcp-setup.sh 等价。真实能力（rea-agents@6.5.0）：MCP over stdio 为换行分隔 JSONL
  （无 Content-Length）；发一行 initialize，回一行 {"result":{...},"id":1}。
  本脚本自己写标准 MCP stdio JSON（最小副作用：备份 .bak → 只合并 mcpServers.rea → 不动其它条目）。

.PARAMETER List
  只检测客户端配置是否存在，不改动。
.PARAMETER DryRun
  渲染将要注册的 stdio JSON，不写盘。
.PARAMETER Check
  原生 MCP stdio initialize 握手；有 Ghidra/JDK 环境时再跑 doctor --provider ghidra。
.PARAMETER Client
  目标客户端：claude-desktop / cursor / vscode / claude-code。
.PARAMETER Yes
  真正写盘（默认不写）。

.EXAMPLE
  pwsh -File ./scripts/mcp-setup.ps1 -List
  pwsh -File ./scripts/mcp-setup.ps1 -DryRun -Client claude-desktop
  pwsh -File ./scripts/mcp-setup.ps1 -Client claude-desktop -Yes
  pwsh -File ./scripts/mcp-setup.ps1 -Check
#>
param(
  [switch]$List,
  [switch]$DryRun,
  [switch]$Check,
  [switch]$Yes,
  [string]$Client = ''
)
. (Join-Path $PSScriptRoot '..\lib\common.ps1')

$Cfg = Import-VersionConfig

# v3.0 集中发现：env 未设/不合法时回退 current junction → 枚举（不覆盖合法显式 env）
$rJdk = Resolve-JdkHome;     if ($rJdk) { $env:JAVA_HOME = $rJdk }
$rGh  = Resolve-GhidraDir;   if ($rGh)  { $env:GHIDRA_INSTALL_DIR = $rGh }

# npx 绝对路径（找不到回退 npx）
$npxCmd = (Get-Command npx -ErrorAction SilentlyContinue)
$npxBin = if ($npxCmd) { $npxCmd.Source } else { 'npx' }

function Get-ClientConfigPath {
  param([string]$Name)
  # 跨平台安全：APPDATA 为空（如 CI 在 Linux pwsh）时回退 $HOME
  $base = $env:APPDATA
  if ([string]::IsNullOrWhiteSpace($base)) { $base = $HOME }
  switch ($Name) {
    'claude-desktop' { return @{ Path = (Join-Path $base 'Claude\claude_desktop_config.json'); Key = 'mcpServers' } }
    'cursor'         { return @{ Path = (Join-Path $base 'Cursor\User\globalStorage\mcp.json'); Key = 'mcpServers' } }
    'vscode'         { return @{ Path = (Join-Path $base 'Code\User\mcp.json'); Key = 'servers' } }
    'claude-code'     { return @{ Path = (Join-Path $HOME '.claude.json'); Key = 'mcpServers' } }
    default           { return $null }
  }
}

function New-ReaEntry {
  $env = [ordered]@{}
  if ($env:JAVA_HOME) { $env['JAVA_HOME'] = $env:JAVA_HOME }
  if ($env:GHIDRA_INSTALL_DIR) { $env['GHIDRA_INSTALL_DIR'] = $env:GHIDRA_INSTALL_DIR }
  if ((Get-ReaMirrorMode) -eq 'cn') { $env['REA_MIRROR'] = 'cn' }
  return [ordered]@{
    command = $npxBin
    args    = @('-y', "rea-agents@$($Cfg.REA_VERSION)", '--mcp')
    env     = $env
  }
}

# ---- -List ----
if ($List) {
  Write-Output '== 检测到的 MCP 客户端配置 =='
  foreach ($c in @('claude-desktop','cursor','vscode','claude-code')) {
    $r = Get-ClientConfigPath $c
    $st = if (Test-Path -LiteralPath $r.Path) { '已安装' } else { '未安装' }
    Write-Output ("  {0,-14} {1,-8} -> {2}" -f $c, $st, $r.Path)
  }
  Write-Output ""
  Write-Output ("将注册 server 名 rea（command={0} -y rea-agents@{1} --mcp）" -f $npxBin, $Cfg.REA_VERSION)
  exit 0
}

# ---- -Check：原生 stdio 握手 ----
if ($Check) {
  # common.ps1 设了 $ErrorActionPreference='Stop'；PS7.4+ 会把原生命令 stderr 当终止错误，
  # 而 npx 启动总会往 stderr 写东西。这里临时关闭该行为，避免握手管道被中断。
  $prevNativeErr = $PSNativeCommandUseErrorActionPreference
  $PSNativeCommandUseErrorActionPreference = $false
  # common.ps1 把 $OutputEncoding 设为 UTF8 带 BOM，会在管道 stdin 前加 BOM 导致 npx 收到非法 JSON；
  # 这里重置为 UTF8 无 BOM，握手 JSONL 才能被 npx 正确解析。
  $prevOutEnc = $OutputEncoding
  $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  Write-Output '== [a] MCP stdio 原生握手（JSON-RPC initialize）=='
  $init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"rea-setup","version":"1.0.0"}}}'
  $resp = ($init | & $npxBin -y "rea-agents@$($Cfg.REA_VERSION)" --mcp 2>$null | Select-Object -First 1)
  $OutputEncoding = $prevOutEnc
  if ("$resp" -match '"result"') {
    Write-Output "  [OK] initialize 成功：$resp"
  } else {
    $PSNativeCommandUseErrorActionPreference = $prevNativeErr
    Write-Error "  [FAIL] 未收到合法 initialize result（响应：$resp）"
    exit 1
  }
  if ($env:GHIDRA_INSTALL_DIR -and $env:JAVA_HOME) {
    Write-Output '== [b] Ghidra provider 体检 =='
    $doc = & $npxBin -y "rea-agents@$($Cfg.REA_VERSION)" doctor --provider ghidra --format json 2>$null | Out-String
    $ok = $false; $gv = '?'
    try {
      $d = $doc | ConvertFrom-Json
      foreach ($p in $d.providerInspections) {
        if ($p.id -eq 'ghidra') { $ok = [bool]$p.available; $gv = $p.providerVersion; break }
      }
    } catch { $ok = $false }
    if ($ok) { Write-Output "  [OK] Ghidra provider 可用（version=$gv）" }
    else { $PSNativeCommandUseErrorActionPreference = $prevNativeErr; Write-Error '  [FAIL] Ghidra provider 不可用'; exit 1 }
  } else {
    Write-Output '  [跳过] 未设置 GHIDRA_INSTALL_DIR/JAVA_HOME（仅做握手 a）'
  }
  $PSNativeCommandUseErrorActionPreference = $prevNativeErr
  Write-Output '连接自检通过。'
  exit 0
}

# ---- -DryRun / -Client -Yes ----
if (-not $Client) { Write-Output '需要 -Client <名>（或 -List/-Check）' ; exit 2 }
$reg = Get-ClientConfigPath $Client
if (-not $reg) { Write-Output "未知客户端：$Client" ; exit 2 }
$entry = New-ReaEntry

if ($DryRun) {
  Write-Output "== Dry-run：将合并进 $($reg.Path) 的 '$($reg.Key)' 下（server 名 rea）=="
  Write-Output '（不写盘；写前备份 .bak，不动其它条目）'
  Write-Output ''
  $entry | ConvertTo-Json -Depth 6
  exit 0
}

if (-not $Yes) { Write-Output "将修改 $($reg.Path)。确认请加 -Yes（或先 -DryRun）。" ; exit 1 }

$dir = Split-Path -Parent $reg.Path
New-Item -ItemType Directory -Force -Path $dir | Out-Null
if (Test-Path -LiteralPath $reg.Path) { Copy-Item -LiteralPath $reg.Path -Destination "$($reg.Path).bak" -Force; Write-Output "已备份：$($reg.Path).bak" }

$data = $null
if (Test-Path -LiteralPath $reg.Path) {
  try { $data = Get-Content -LiteralPath $reg.Path -Raw | ConvertFrom-Json } catch { $data = $null }
}
if ($null -eq $data) { $data = [pscustomobject]@{} }
if (-not ($data.PSObject.Properties.Name -contains $reg.Key)) {
  $data | Add-Member -NotePropertyName $reg.Key -NotePropertyValue ([pscustomobject]@{})
}
$data.$($reg.Key) | Add-Member -NotePropertyName 'rea' -NotePropertyValue $entry -Force

($data | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $reg.Path -Encoding utf8
Write-Output "已写入：$($reg.Path)（$($reg.Key).rea）"
Write-Output "完成。请重启 $Client 让 MCP server 生效；可用 -Check 自检。"

# Instala o Chrome DevTools MCP otimizado + skill no Grok (Windows).
# Não instala Node nem Chrome. Não mexe em outros MCP servers.
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$PackageVersion = "1.8.0"
$MaxOutputBytes = "262144"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillSrc = Join-Path $ScriptDir "skill\grok-mcp-chrome"

$ChromeBlock = @"
[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@$PackageVersion",
    "--autoConnect",
    "--no-category-performance",
    "--no-performance-crux",
    "--no-usage-statistics",
    "--screenshot-format=jpeg",
    "--screenshot-quality=60",
    "--screenshot-max-width=1280",
    "--screenshot-max-height=768",
    "--allow-unrestricted-paths",
]
startup_timeout_sec = 45
tool_timeout_sec = 45
tool_timeouts = { take_screenshot = 30, wait_for = 25 }
enabled = true

[mcp_servers.chrome-devtools.env]
CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1"
CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1"
"@

function Show-Usage {
    @"
Uso: install.ps1 [-DryRun] [-Uninstall] [-Help]

1. Grava [mcp_servers.chrome-devtools] em `$env:USERPROFILE\.grok\config.toml
2. Copia a skill para `$env:USERPROFILE\.grok\skills\grok-mcp-chrome\

  -DryRun      mostra o preview sem gravar
  -Uninstall   remove o bloco chrome-devtools e a skill (mantém [mcp])
  -Help        esta ajuda

Pré-requisitos (este script NÃO instala): Node.js + npx, Chrome 144+, Grok
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

function Strip-ChromeBlocks([string]$src) {
    return [regex]::Replace(
        $src,
        "(?ms)\n?\[mcp_servers\.chrome-devtools(?:\.[^\]]+)?\][\s\S]*?(?=\n\[|\z)",
        "`n"
    )
}

function Upsert-McpMax([string]$src, [string]$value) {
    $m = [regex]::Match($src, "(?m)^\[mcp\][ \t]*\n")
    if (-not $m.Success) {
        return "[mcp]`nmax_output_bytes = $value`n`n" + $src.TrimStart()
    }
    $start = $m.Index + $m.Length
    $n = [regex]::Match($src.Substring($start), "(?m)^\[")
    $end = if ($n.Success) { $start + $n.Index } else { $src.Length }
    $head = $src.Substring(0, $m.Index)
    $section = $src.Substring($m.Index, $end - $m.Index)
    $tail = $src.Substring($end)
    if ($section -match "(?m)^max_output_bytes\s*=") {
        $section = [regex]::Replace(
            $section,
            "(?m)^max_output_bytes\s*=\s*\S+",
            "max_output_bytes = $value",
            1
        )
    }
    else {
        $section = [regex]::Replace(
            $section,
            "(?m)^(\[mcp\][ \t]*\n)",
            "`$1max_output_bytes = $value`n",
            1
        )
    }
    return $head + $section.TrimEnd() + "`n`n" + $tail.TrimStart()
}

function Collapse-Blank([string]$src) {
    $text = [regex]::Replace($src, "`n{3,}", "`n`n")
    if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) {
        $text += "`n"
    }
    return $text
}

function Merge-Config([string]$src, [bool]$doUninstall) {
    $text = Strip-ChromeBlocks $src
    if ($doUninstall) {
        return (Collapse-Blank ($text.TrimEnd() + "`n"))
    }
    $text = Upsert-McpMax $text $MaxOutputBytes
    $text = $text.TrimEnd() + "`n`n" + $ChromeBlock.Trim() + "`n"
    return (Collapse-Blank $text)
}

function Find-Chrome {
    $candidates = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    $cmd = Get-Command chrome -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$grokHome = if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $env:USERPROFILE ".grok" }
$config = Join-Path $grokHome "config.toml"
$skillDst = Join-Path $grokHome "skills\grok-mcp-chrome"

Write-Host "==> grok-mcp-chrome installer (Windows)"
Write-Host "    config: $config"
Write-Host "    skill:  $skillDst"
Write-Host "    pacote: chrome-devtools-mcp@$PackageVersion"
Write-Host ""

$missing = $false
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Warning "node não encontrado no PATH."
    $missing = $true
}
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Warning "npx não encontrado no PATH."
    $missing = $true
}
$chrome = Find-Chrome
if ($chrome) {
    Write-Host "Chrome: $chrome"
}
else {
    Write-Warning "Chrome não encontrado. Precisa Chrome 144+ para --autoConnect."
    $missing = $true
}
Write-Host ""

$original = ""
if (Test-Path -LiteralPath $config) {
    $original = [System.IO.File]::ReadAllText($config)
}

$newText = Merge-Config $original $Uninstall.IsPresent
$configChanged = $original -ne $newText

if ($configChanged) {
    Write-Host "--- preview config.toml ---"
    Write-Host $newText
    Write-Host "--------------------------"
    Write-Host ""
}

if ($Uninstall) {
    Write-Host "Skill a remover: $skillDst"
}
else {
    Write-Host "Skill a copiar: $SkillSrc -> $skillDst"
}
Write-Host ""

if ($DryRun) {
    Write-Host "Dry-run: nenhuma escrita."
    exit 0
}

New-Item -ItemType Directory -Force -Path $grokHome | Out-Null
if ($configChanged) {
    if (Test-Path -LiteralPath $config) {
        $stamp = Get-Date -Format "yyyyMMddHHmmss"
        $bak = "$config.bak.$stamp"
        Copy-Item -LiteralPath $config -Destination $bak
        Write-Host "Backup: $bak"
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($config, $newText, $utf8NoBom)
    Write-Host "Gravado: $config"
}
else {
    Write-Host "config.toml já estava no estado pedido."
}

if ($Uninstall) {
    if (Test-Path -LiteralPath $skillDst) {
        Remove-Item -LiteralPath $skillDst -Recurse -Force
        Write-Host "Skill removida: $skillDst"
    }
    Write-Host "Reinicie o Grok (ou /mcps -> r)."
    exit 0
}

$skillsRoot = Join-Path $grokHome "skills"
New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null
if (Test-Path -LiteralPath $skillDst) {
    Remove-Item -LiteralPath $skillDst -Recurse -Force
}
Copy-Item -LiteralPath $SkillSrc -Destination $skillDst -Recurse
Write-Host "Skill gravada: $(Join-Path $skillDst 'SKILL.md')"
Write-Host ""

@"
Próximos passos (--autoConnect):
  1. Chrome 144+ aberto, poucas abas.
  2. chrome://inspect/#remote-debugging -> ligar Remote Debugging.
  3. Primeira tool do Grok -> Allow.
  4. Reiniciar o Grok, ou /mcps -> r.

Camadas instaladas: flags MCP (config.toml) + playbook do agente (skill).
O Grok no Windows resolve npx.cmd via PATHEXT; command = "npx" está correto.
"@

if ($missing) {
    Write-Host ""
    Write-Host "Há avisos de pré-requisito acima. Config/skill foram gravados mesmo assim."
}
exit 0

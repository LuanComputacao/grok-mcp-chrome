# Instala o Chrome DevTools MCP otimizado + skill no Grok (Windows).
# Não instala Node, Chrome nem o Grok. Não mexe em outros MCP servers.
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$PackageVersion = "1.8.0"
$MinChromeMajor = 144
$MinNodeMajor = 20
$MaxOutputBytes = "262144"
$DocsUrl = "https://github.com/LuanComputacao/grok-mcp-chrome#comece-aqui"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillSrc = Join-Path $ScriptDir "skill\grok-mcp-chrome"
$script:PreFail = $false

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
Uso: install.ps1 [-Check] [-DryRun] [-Force] [-Uninstall] [-Help]

1. Verifica pré-requisitos (Node ≥$MinNodeMajor, npx, Chrome ≥$MinChromeMajor, Grok)
2. Grava [mcp_servers.chrome-devtools] em `$env:USERPROFILE\.grok\config.toml
3. Copia a skill para `$env:USERPROFILE\.grok\skills\grok-mcp-chrome\

  -Check       só o preflight; não grava nada (exit 1 se faltar algo)
  -DryRun      preflight + preview, não grava
  -Force       grava mesmo se o preflight falhar
  -Uninstall   remove o bloco chrome-devtools e a skill (mantém [mcp])
  -Help        esta ajuda

Este script NÃO instala Node/Chrome/Grok. Instruções: README.md
  $DocsUrl
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

function Write-Ok([string]$msg) { Write-Host "  [ok]   $msg" }
function Write-Fail([string]$msg) {
    Write-Warning "  [FAIL] $msg"
    $script:PreFail = $true
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

function Get-ChromeMajor([string]$path) {
    try {
        $v = (Get-Item -LiteralPath $path).VersionInfo.ProductVersion
        if ($v) { return [int]($v.Split('.')[0]) }
    }
    catch { }
    return 0
}

function Find-Grok([string]$grokHome) {
    $cmd = Get-Command grok -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $grokHome "bin\grok.exe"),
        (Join-Path $grokHome "bin\grok"),
        (Join-Path $env:USERPROFILE ".grok\bin\grok.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

function Invoke-Preflight([string]$grokHome, [bool]$isUninstall) {
    $script:PreFail = $false
    Write-Host "==> Preflight (pré-requisitos)"
    Write-Host ""

    if ($isUninstall) {
        Write-Ok "PowerShell — merge TOML nativo (uninstall não exige Node/Chrome/Grok)"
        Write-Host ""
        Write-Host "Preflight OK (modo uninstall)."
        Write-Host ""
        return $true
    }

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nv = & node -v
        $major = [int](($nv -replace '[^0-9].*', ''))
        if ($major -ge $MinNodeMajor) {
            Write-Ok "node $nv ($($nodeCmd.Source))"
        }
        else {
            Write-Fail "node $nv — precisa major ≥ $MinNodeMajor (LTS 20/22)."
            Write-Host "         https://nodejs.org/  (Windows Installer LTS)"
        }
    }
    else {
        Write-Fail "node ausente no PATH."
        Write-Host "         https://nodejs.org/  → LTS → msiexec; reabra o terminal."
    }

    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
    if ($npxCmd) {
        Write-Ok "npx $($npxCmd.Source)"
    }
    else {
        Write-Fail "npx ausente (vem com o Node.js; o Grok spawna npx -y chrome-devtools-mcp@$PackageVersion)."
    }

    $chrome = Find-Chrome
    if ($chrome) {
        $cm = Get-ChromeMajor $chrome
        if ($cm -ge $MinChromeMajor) {
            Write-Ok "chrome $cm ($chrome) — autoConnect exige ≥ $MinChromeMajor"
        }
        else {
            Write-Fail "chrome $cm em $chrome — precisa ≥ $MinChromeMajor."
            Write-Host "         https://www.google.com/chrome/"
        }
    }
    else {
        Write-Fail "Google Chrome não encontrado."
        Write-Host "         https://www.google.com/chrome/"
    }

    $grokBin = Find-Grok $grokHome
    if ($grokBin) {
        $gv = ""
        try { $gv = (& $grokBin --version 2>$null | Select-Object -First 1) } catch { }
        Write-Ok "grok $(if ($gv) { $gv } else { 'ok' }) ($grokBin)"
    }
    else {
        Write-Fail "Grok CLI não encontrado (PATH nem $grokHome\bin\grok.exe)."
        Write-Host "         irm https://x.ai/cli/install.ps1 | iex"
    }

    Write-Host ""
    if ($script:PreFail) {
        Write-Host "Preflight FALHOU. Instale os itens [FAIL] (README) e rode de novo."
        Write-Host "Docs: $DocsUrl"
        Write-Host "Ou:   .\install.ps1 -Force   (grava mesmo assim — o MCP pode não subir)"
        Write-Host ""
        return $false
    }
    Write-Host "Preflight OK."
    Write-Host ""
    return $true
}

$grokHome = if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $env:USERPROFILE ".grok" }
$config = Join-Path $grokHome "config.toml"
$skillDst = Join-Path $grokHome "skills\grok-mcp-chrome"

Write-Host "==> grok-mcp-chrome installer (Windows)"
Write-Host "    config: $config"
Write-Host "    skill:  $skillDst"
Write-Host "    pacote: chrome-devtools-mcp@$PackageVersion"
Write-Host ""

$preOk = Invoke-Preflight $grokHome $Uninstall.IsPresent
if (-not $preOk) {
    if ($Check) { exit 1 }
    if (-not $Force) { exit 1 }
    Write-Host "-Force: seguindo mesmo com preflight falho."
    Write-Host ""
}

if ($Check) {
    Write-Host "Só -Check; nada gravado."
    exit 0
}

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
  1. Chrome $MinChromeMajor+ aberto, poucas abas.
  2. chrome://inspect/#remote-debugging -> ligar Remote Debugging.
  3. Primeira tool do Grok -> Allow.
  4. Reiniciar o Grok, ou /mcps -> r.

Camadas instaladas: flags MCP (config.toml) + playbook do agente (skill).
O Grok no Windows resolve npx.cmd via PATHEXT; command = "npx" está correto.
"@
exit 0

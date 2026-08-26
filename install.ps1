# Instala o Chrome DevTools MCP otimizado + skill no Grok (Windows).
# Merge TOML: o mesmo merge_grok_chrome_mcp.js do Linux (exige Node).
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
$WarnChromeMajor = 149
$MinNodeMajor = 20
$DocsUrl = "https://github.com/LuanComputacao/grok-mcp-chrome#comece-aqui"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Merger = Join-Path $ScriptDir "merge_grok_chrome_mcp.js"
$SkillSrc = Join-Path $ScriptDir "skill\grok-mcp-chrome"
$script:PreFail = $false

function Show-Usage {
    @"
Uso: install.ps1 [-Check] [-DryRun] [-Force] [-Uninstall] [-Help]

1. Verifica Node ≥$MinNodeMajor, npx, Google Chrome ≥$MinChromeMajor, Grok
2. Grava [mcp_servers.chrome-devtools] via node merge_grok_chrome_mcp.js
3. Copia a skill para `$env:USERPROFILE\.grok\skills\grok-mcp-chrome\

  -Check       só o preflight; exit 1 se faltar algo
  -DryRun      preflight + preview do bloco chrome; não grava
  -Force       grava mesmo com Chrome/Grok ausentes; ainda exige Node.
               exit 1 no fim (MCP não validado)
  -Uninstall   remove o bloco chrome-devtools e a skill (mantém [mcp])
  -Help        esta ajuda

README: $DocsUrl
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

function Write-Ok([string]$msg) { Write-Host "  [ok]   $msg" }
function Write-Fail([string]$msg) {
    Write-Warning "[FAIL] $msg"
    $script:PreFail = $true
}
function Write-WarnLine([string]$msg) { Write-Host "  [warn] $msg" }

function Find-Chrome {
    $candidates = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

function Get-ChromeMajor([string]$path) {
    try {
        $v = (Get-Item -LiteralPath $path).VersionInfo.ProductVersion
        if ($v -and ($v -match '^(\d+)')) { return [int]$Matches[1] }
    }
    catch { }
    return 0
}

function Get-NodeMajor {
    $nv = & node -v
    if ($nv -match '(\d+)') { return [int]$Matches[1] }
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

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nv = & node -v
        $major = Get-NodeMajor
        if ($major -ge $MinNodeMajor) {
            Write-Ok "node $nv — merge TOML + npx do MCP"
        }
        else {
            Write-Fail "node $nv — precisa major ≥ $MinNodeMajor (LTS 20/22)."
        }
    }
    else {
        Write-Fail "node ausente no PATH."
        Write-Host "         https://nodejs.org/  → LTS MSI; reabra o terminal."
    }

    if ($isUninstall) {
        Write-Host ""
        if ($script:PreFail) {
            Write-Host "Preflight FALHOU. -Uninstall precisa do Node para mesclar o TOML."
            return $false
        }
        Write-Host "Preflight OK (modo uninstall)."
        Write-Host ""
        return $true
    }

    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
    if ($npxCmd) {
        Write-Ok "npx $($npxCmd.Source)"
    }
    else {
        Write-Fail "npx ausente (vem com o Node.js)."
    }

    $chrome = Find-Chrome
    if ($chrome) {
        $cm = Get-ChromeMajor $chrome
        if ($cm -ge $MinChromeMajor) {
            Write-Ok "Google Chrome $cm ($chrome)"
            if ($cm -lt $WarnChromeMajor) {
                Write-WarnLine "Chrome $cm < $WarnChromeMajor: abas discarded podem dar timeout. Atualize o Chrome."
            }
        }
        else {
            Write-Fail "Chrome $cm — autoConnect precisa ≥ $MinChromeMajor."
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
        Write-Host "Preflight FALHOU. Instale os [FAIL] e rode de novo. Docs: $DocsUrl"
        Write-Host ""
        return $false
    }
    Write-Host "Preflight OK."
    Write-Host ""
    return $true
}

if (-not (Test-Path -LiteralPath $Merger)) {
    Write-Error "Merger ausente: $Merger"
    exit 1
}

$grokHome = if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $env:USERPROFILE ".grok" }
$config = Join-Path $grokHome "config.toml"
$skillDst = Join-Path $grokHome "skills\grok-mcp-chrome"

Write-Host "==> grok-mcp-chrome installer (Windows)"
Write-Host "    config: $config"
Write-Host "    skill:  $skillDst"
Write-Host "    pacote: chrome-devtools-mcp@$PackageVersion"
Write-Host ""

$dirty = $false
$preOk = Invoke-Preflight $grokHome $Uninstall.IsPresent
if (-not $preOk) {
    $dirty = $true
    if ($Check) { exit 1 }
    if (-not $Force) { exit 1 }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Error "-Force não dispensa Node (preciso dele para mesclar o TOML)."
        exit 1
    }
    Write-Host "-Force: gravando arquivos mesmo com preflight falho."
    Write-Host ""
}

if ($Check) {
    Write-Host "Só -Check; nada gravado."
    exit 0
}

$mergeArgs = @($Merger)
if ($Uninstall) { $mergeArgs += "--uninstall" }
if (Test-Path -LiteralPath $config) { $mergeArgs += $config }
$merged = if (Test-Path -LiteralPath $config) {
    & node @mergeArgs | Out-String
}
else {
    "" | & node $Merger | Out-String
}
$tmp = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tmp, $merged, $utf8NoBom)
$newText = [System.IO.File]::ReadAllText($tmp)
$original = ""
if (Test-Path -LiteralPath $config) {
    $original = [System.IO.File]::ReadAllText($config)
}
$configChanged = $original -ne $newText

if ($configChanged) {
    Write-Host "--- bloco chrome-devtools (não dumpa o resto do config) ---"
    & node $Merger --print-block
    Write-Host "----------------------------------------------------------------"
    Write-Host ""
}

if ($Uninstall) {
    Write-Host "Skill a remover: $skillDst"
}
else {
    Write-Host "Skill: $SkillSrc -> $skillDst"
}
Write-Host ""

if ($DryRun) {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    Write-Host "Dry-run: nenhuma escrita."
    exit 0
}

New-Item -ItemType Directory -Force -Path $grokHome | Out-Null
if ($configChanged) {
    if (Test-Path -LiteralPath $config) {
        $stamp = Get-Date -Format "yyyyMMddHHmmss"
        Copy-Item -LiteralPath $config -Destination "$config.bak.$stamp"
        Write-Host "Backup: $config.bak.$stamp"
    }
    Copy-Item -LiteralPath $tmp -Destination $config -Force
    Write-Host "Gravado: $config"
}
else {
    Write-Host "config.toml já estava no estado pedido."
}
Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue

if ($Uninstall) {
    if (Test-Path -LiteralPath $skillDst) {
        Remove-Item -LiteralPath $skillDst -Recurse -Force
        Write-Host "Skill removida: $skillDst"
    }
    Write-Host "Reinicie o Grok (MCP: /mcps -> r)."
    exit 0
}

$skillsRoot = Join-Path $grokHome "skills"
New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null
$srcSkill = Join-Path $SkillSrc "SKILL.md"
$dstSkill = Join-Path $skillDst "SKILL.md"
$skillSame = $false
if ((Test-Path -LiteralPath $srcSkill) -and (Test-Path -LiteralPath $dstSkill)) {
    $skillSame = (Get-FileHash $srcSkill).Hash -eq (Get-FileHash $dstSkill).Hash
}
if ($skillSame) {
    Write-Host "Skill já estava atualizada."
}
else {
    if (Test-Path -LiteralPath $dstSkill) {
        $stamp = Get-Date -Format "yyyyMMddHHmmss"
        Copy-Item -LiteralPath $dstSkill -Destination "$dstSkill.bak.$stamp"
    }
    if (Test-Path -LiteralPath $skillDst) {
        Remove-Item -LiteralPath $skillDst -Recurse -Force
    }
    Copy-Item -LiteralPath $SkillSrc -Destination $skillDst -Recurse
    Write-Host "Skill gravada: $dstSkill"
}
Write-Host ""

@"
Privacidade: --autoConnect vê o Chrome da sua vida. Tool results vão para a API xAI.
Feche banco/e-mail/gov se não forem o alvo.

Próximos passos:
  1. Chrome $MinChromeMajor+ aberto, poucas abas (nunca feche a última).
  2. chrome://inspect/#remote-debugging -> Remote Debugging.
  3. Primeira tool -> Allow (de novo após /mcps r).
  4. Restart do Grok. /mcps r recarrega MCP, não a skill já injetada neste turno.
"@

if ($dirty) {
    Write-Host ""
    Write-Host "INSTALOU ARQUIVOS; MCP NÃO VALIDADO (preflight falhou; -Force)."
    exit 1
}
exit 0

# grok-mcp-chrome

Configura o [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) no **Grok** (Linux ou Windows), com o perfil rápido para clicar, preencher, ler o DOM e tirar print de layout.

Este instalador **não baixa** Node, Chrome nem o Grok. Ele **confere** se eles existem e, se estiver tudo certo, grava:

1. o bloco MCP em `~/.grok/config.toml` (Windows: `%USERPROFILE%\.grok\config.toml`)
2. a skill em `~/.grok/skills/grok-mcp-chrome/`

## Comece aqui

Faça **nesta ordem**:

| Passo | O quê |
|---|---|
| **1** | Instale os pré-requisitos do seu sistema → [Linux](#1-pré-requisitos) ou [Windows](#windows--do-zero-até-funcionar) |
| **2** | Rode o instalador deste repositório (`./install.sh` ou `.\install.ps1`) |
| **3** | No Chrome: remote debugging + **Allow** na primeira tool do Grok |

Se o passo 2 imprimir `[FAIL]`, **não pule**. Instale o item que faltou e rode `--check` / `-Check` de novo.

**Privacidade:** `--autoConnect` liga o Grok no **Chrome da sua vida** (todas as abas). O que o MCP devolve (snapshot, print, Network) vai para a API xAI. Feche banco, e-mail e gov se não forem o alvo. O diálogo **Allow** do Chrome é o único clique de consentimento.

---

## Linux — do zero até funcionar

### 1. Pré-requisitos

Copie **na ordem**. Feche e abra o terminal depois do nvm e depois do Grok, se o comando não aparecer.

**Git** (Debian/Ubuntu):

```bash
sudo apt update
sudo apt install -y git
```

Fedora:

```bash
sudo dnf install -y git
```

**Node.js LTS** (não use o `nodejs` velho do `apt`):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
source ~/.bashrc    # zsh: source ~/.zshrc
nvm install --lts
nvm use --lts
```

**Google Chrome stable** (major **≥ 144**; Chromium antigo não serve):

```bash
cd /tmp
curl -fsSLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
```

Fedora:

```bash
sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager --set-enabled google-chrome
sudo dnf install -y google-chrome-stable
```

Ou baixe em https://www.google.com/chrome/

**Grok** ([documentação](https://docs.x.ai)):

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
source ~/.bashrc    # zsh: source ~/.zshrc
```

Na primeira vez, `grok` abre o browser para entrar em grok.com.

### 2. Conferir no Linux

```bash
node -v                    # v20.x ou v22.x (major ≥ 20)
npx -v
google-chrome-stable --version   # major ≥ 144
grok --version
```

### 3. Instalar este repositório (Linux)

```bash
git clone https://github.com/LuanComputacao/grok-mcp-chrome.git
cd grok-mcp-chrome
chmod +x install.sh

./install.sh --check       # só verifica; se sair [FAIL], volte ao passo 1
./install.sh               # grava config.toml + skill
```

Atualizar depois:

```bash
cd grok-mcp-chrome
git pull
./install.sh
```

Desinstalar (remove o MCP Chrome e a skill; **não** desfaz o cap `[mcp]`):

```bash
./install.sh --uninstall
```

Destino padrão: `~/.grok`. Outro diretório: `GROK_HOME=/caminho ./install.sh`.

### 4. Ligar o Chrome no Grok (Linux e Windows)

Isto **não** é automático. Sem estes passos o MCP existe mas não fala com o browser.

1. Abra o **Google Chrome** (poucas abas; dezenas de abas deixam o attach lento).
2. Na barra de endereço: `chrome://inspect/#remote-debugging`
3. Ligue **Remote Debugging**.
4. Reinicie o Grok (ou no TUI: `/mcps` e tecla `r`).
5. Peça qualquer ação no Chrome. No diálogo do Chrome, clique **Allow**.

---

## Windows — do zero até funcionar

Use o **PowerShell**. Se o sistema bloquear o script, rode **uma vez nesta janela**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

### 1. Pré-requisitos

Instale **nesta ordem**. Depois de Node e Grok, **feche o PowerShell e abra de novo**.

| Ordem | O quê | Como |
|---|---|---|
| 1 | Git | https://git-scm.com/download/win — instalador oficial, next/next |
| 2 | Node.js **LTS** | https://nodejs.org/ — *Windows Installer (.msi)* LTS (major ≥ 20) |
| 3 | Google Chrome **≥ 144** | https://www.google.com/chrome/ — instalador oficial |
| 4 | Grok | comando abaixo |

Grok:

```powershell
irm https://x.ai/cli/install.ps1 | iex
```

Isso coloca `%USERPROFILE%\.grok\bin` no PATH do usuário.

### 2. Conferir no Windows

No PowerShell **novo**:

```powershell
node -v          # v20.x ou v22.x
npx -v
grok --version
```

Chrome: abra o browser → `chrome://version` → o número grande no topo deve ser **144** ou mais.

O merge do TOML no Linux usa o **mesmo Node** do `npx`. No Windows o merge é PowerShell. Nenhum dos dois pede Python.

### 3. Instalar este repositório (Windows)

```powershell
git clone https://github.com/LuanComputacao/grok-mcp-chrome.git
cd grok-mcp-chrome

.\install.ps1 -Check      # só verifica; se sair [FAIL], volte ao passo 1
.\install.ps1             # grava config.toml + skill
```

Atualizar depois:

```powershell
cd grok-mcp-chrome
git pull
.\install.ps1
```

Desinstalar:

```powershell
.\install.ps1 -Uninstall
```

Destino padrão: `%USERPROFILE%\.grok`. Outro: `$env:GROK_HOME="D:\grok"; .\install.ps1`.

O Grok no Windows resolve `npx.cmd` sozinho. O `config.toml` usa `command = "npx"` igual ao Linux.

### 4. Ligar o Chrome no Grok

Mesmos 5 passos da [secção Linux](#4-ligar-o-chrome-no-grok-linux-e-windows).

---

## Se o preflight falhar

O instalador **não grava nada** enquanto houver `[FAIL]`. `--force` ainda **exige Node**, grava os arquivos e sai **exit 1** (`MCP NÃO VALIDADO`). Não é o caminho normal.

| Mensagem | O que fazer |
|---|---|
| `node ausente` / major &lt; 20 | Instale LTS (nvm no Linux, MSI no Windows). Reabra o terminal. |
| `npx ausente` | Reinstale o Node (o npx vem junto). |
| `Google Chrome não encontrado` / versão &lt; 144 | Instale o Chrome stable em https://www.google.com/chrome/ |
| `Grok CLI não encontrado` | Rode o installer da x.ai e reabra o terminal. Confira `grok --version`. |

Conferir de novo:

```bash
./install.sh --check          # Linux
```

```powershell
.\install.ps1 -Check          # Windows
```

---

## Flags do instalador

| Linux | Windows | O que faz |
|---|---|---|
| `--check` | `-Check` | Só preflight. Exit 1 se faltar algo. |
| `--dry-run` | `-DryRun` | Preflight + preview do **bloco chrome** (não dumpa o resto do TOML). Não grava. |
| `--force` | `-Force` | Grava mesmo com Chrome/Grok ausentes; **exige Node**. Exit **1** no fim. |
| `--uninstall` | `-Uninstall` | Remove o bloco `chrome-devtools` e a skill. Mantém `[mcp] max_output_bytes`. |
| `--help` | `-Help` | Ajuda. |

O `config.toml` existente ganha backup `config.toml.bak.<datahora>`. Stitch, GitHub e outros MCP **não** são alterados.

---

## O que a outra máquina ganha (otimizações)

**Sim:** depois do preflight OK, a outra máquina fica com o mesmo perfil rápido.

| Camada | Onde | Efeito |
|---|---|---|
| Servidor MCP | `config.toml` | JPEG limitado, cap 256 KB, pin `1.8.0`, sem traces/telemetria, `--autoConnect` |
| Agente | skill `grok-mcp-chrome` | curl/`fetch` vs browser; snapshot para achar elemento; **screenshot obrigatório** em QA de layout |

**Não viaja:** Node, Chrome, Grok, o diálogo **Allow**, nem o hábito de poucas abas.

`--slim` não é usado (quebra `click` / `fill` / `take_snapshot`).

Bloco gravado:

O bloco canônico (gerado por `node merge_grok_chrome_mcp.js --print-block`):

```toml
[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@1.8.0",
    "--autoConnect",
    "--page-id-routing",
    "--redact-network-headers",
    "--no-category-performance",
    "--no-performance-crux",
    "--no-usage-statistics",
    "--screenshot-format=jpeg",
    "--screenshot-quality=60",
    "--screenshot-max-width=1280",
    "--screenshot-max-height=768",
]
startup_timeout_sec = 45
tool_timeout_sec = 45
tool_timeouts = { take_screenshot = 30, wait_for = 25 }
enabled = true

[mcp_servers.chrome-devtools.env]
CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1"
CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1"
```

Também sobe `[mcp] max_output_bytes = 262144` (**global**, vale para todos os MCP). Writes do MCP ficam no temp do SO (sem `--allow-unrestricted-paths`). Headers de Authorization/Cookie são redigidos antes de ir ao modelo.

Perfil Chrome **dedicado** (`--browser-url` + outro `--user-data-dir`) evita attach no Chrome do dia-a-dia, mas **não** é o default — exige login de novo. Não misture com `--autoConnect`.

---

## Desenvolvimento

```bash
node test_merge.js
./install.sh --check
```

O Windows usa o **mesmo** `merge_grok_chrome_mcp.js` (não há segundo merger em PowerShell).

## Licença

MIT. O MCP em si é o pacote npm `chrome-devtools-mcp` (ChromeDevTools).

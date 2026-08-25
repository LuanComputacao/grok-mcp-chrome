# grok-mcp-chrome

Instalador do [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) no **Grok**, com o perfil rápido para tarefas no Chrome (clicar, preencher, ler DOM, screenshot de layout).

O instalador **verifica os pré-requisitos** e depois só configura o Grok (config.toml + skill). Ele **não** baixa Node, Chrome nem o Grok — essas instalações estão documentadas abaixo.

Linux (`install.sh`) e Windows (`install.ps1`).

## A pergunta essencial

**Se eu instalar isto em outra máquina, as ações no Chrome já saem otimizadas?**

**Sim**, desde que o preflight passe. As duas camadas viajam no `./install.sh` / `install.ps1`:

| Camada | O que vai para a outra máquina | Efeito |
|---|---|---|
| **Servidor MCP** | bloco em `~/.grok/config.toml` | JPEG pequeno, cap de 256 KB, pin `1.8.0`, sem traces/telemetria, timeouts curtos, `--autoConnect` |
| **Agente** | skill `~/.grok/skills/grok-mcp-chrome/` | probe de stack; curl/`fetch` vs browser; snapshot para achar elemento; **screenshot obrigatório** em QA de layout |

O que **não** viaja: Chrome 144+, Node/`npx` e Grok (têm de existir na máquina destino). Depois da instalação ainda falta ligar o remote debugging e clicar **Allow**.

`--slim` **não** é usado: tira `click` / `fill` / `take_snapshot`.

---

## Pré-requisitos

O instalador exige isto **antes** de gravar (use `--check` / `-Check` para só testar). `--force` / `-Force` ignora a falha (o MCP pode não subir).

| Item | Mínimo | Para quê |
|---|---|---|
| **Python 3** | 3.x no PATH (`python3`) | Só Linux: mesclar o TOML. Windows usa PowerShell. |
| **Node.js** | major **≥ 20** (LTS 20 ou 22) | O Grok spawna o MCP via `npx`. |
| **npx** | o que vem com o Node | `npx -y chrome-devtools-mcp@1.8.0`. |
| **Google Chrome** | **≥ 144** (canal stable) | `--autoConnect`. Chromium antigo não serve. |
| **Grok CLI/TUI** | `grok` no PATH ou `~/.grok/bin/grok` | Destino da config e da skill. |
| **Git** | qualquer | Só para `git clone` deste repo. |

`--uninstall` no Linux só exige Python 3.

---

## Instalar os pré-requisitos

### Linux

**Git** (Debian/Ubuntu / Fedora):

```bash
sudo apt update && sudo apt install -y git python3
# ou: sudo dnf install git python3
```

**Node.js LTS** (nvm — evita o Node velho do `apt`):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
# feche e abra o terminal, ou: source ~/.bashrc   (zsh: source ~/.zshrc)
nvm install --lts
nvm use --lts
node -v    # v20.x ou v22.x
npx -v
```

**Google Chrome stable** (Debian/Ubuntu amd64; o `.deb` já adiciona o apt do Google):

```bash
cd /tmp
curl -fsSLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
google-chrome-stable --version   # major ≥ 144
```

Fedora:

```bash
sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager --set-enabled google-chrome
sudo dnf install -y google-chrome-stable
```

Download oficial: https://www.google.com/chrome/

**Grok** ([docs](https://docs.x.ai)):

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
# garanta ~/.grok/bin no PATH (o installer costuma acrescentar)
grok --version
```

Na primeira execução, `grok` abre o browser para autenticar em grok.com.

### Windows

1. **Git for Windows** — https://git-scm.com/download/win (inclui Git Bash se quiser o fluxo Linux).
2. **Node.js LTS** — https://nodejs.org/ → *Windows Installer (.msi)* LTS → next/next. **Reabra** o PowerShell.
   ```powershell
   node -v
   npx -v
   ```
3. **Google Chrome** — https://www.google.com/chrome/ → instalador oficial.
   Confira em `chrome://version` (major ≥ 144).
4. **Grok** (PowerShell):
   ```powershell
   irm https://x.ai/cli/install.ps1 | iex
   grok --version
   ```
   O installer coloca `%USERPROFILE%\.grok\bin` no PATH do usuário. Reabra o terminal se `grok` não aparecer.

---

## Instalar o grok-mcp-chrome

### Linux

```bash
git clone https://github.com/LuanComputacao/grok-mcp-chrome.git
cd grok-mcp-chrome
chmod +x install.sh

./install.sh --check      # só preflight; exit 1 se faltar algo
./install.sh --dry-run    # preflight + diff do config.toml
./install.sh              # grava config + skill
```

Atualizar (já clonado):

```bash
git pull
./install.sh
```

Desinstalar:

```bash
./install.sh --uninstall
```

`$GROK_HOME` sobrescreve o destino (padrão `~/.grok`).

### Windows (PowerShell)

Pode ser necessário, nesta sessão:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

```powershell
git clone https://github.com/LuanComputacao/grok-mcp-chrome.git
cd grok-mcp-chrome

.\install.ps1 -Check
.\install.ps1 -DryRun
.\install.ps1
```

Atualizar: `git pull` e `.\install.ps1`.  
Desinstalar: `.\install.ps1 -Uninstall`.

`$env:GROK_HOME` sobrescreve o destino (padrão `%USERPROFILE%\.grok`).

O Grok no Windows resolve `npx.cmd` via `PATHEXT`; o TOML usa `command = "npx"` nos dois sistemas.

### Flags

| Linux | Windows | Efeito |
|---|---|---|
| `--check` | `-Check` | Só verifica pré-requisitos |
| `--dry-run` | `-DryRun` | Preflight + preview; não grava |
| `--force` | `-Force` | Grava mesmo com preflight falho |
| `--uninstall` | `-Uninstall` | Remove bloco chrome-devtools e a skill; **mantém** `[mcp] max_output_bytes` |
| `--help` | `-Help` | Ajuda |

Backup automático: `config.toml.bak.<timestamp>`. Outros MCP servers no arquivo não são alterados.

---

## Depois de instalar (obrigatório para `--autoConnect`)

1. Chrome 144+ aberto, **poucas abas** (dezenas de abas deixam o attach lento).
2. `chrome://inspect/#remote-debugging` → ligar Remote Debugging.
3. Primeira tool do Grok → **Allow**.
4. Reiniciar o Grok, ou `/mcps` → `r`.

Salvar `config.toml` já dispara hot-reload (respawna o MCP).

---

## O que o config grava

```toml
[mcp]
max_output_bytes = 262144

[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@1.8.0",
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
```

---

## Testes (desenvolvimento)

```bash
python3 test_merge.py
./install.sh --check
```

## Licença

MIT. O MCP em si é o pacote npm `chrome-devtools-mcp` (ChromeDevTools).

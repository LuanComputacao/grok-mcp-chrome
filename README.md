# grok-mcp-chrome

Instalador do [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) no **Grok**, com o perfil rápido usado para tarefas no Chrome (clicar, preencher, ler DOM, screenshot leve).

Linux e Windows. Não instala Node, Chrome nem o Grok — só configura o Grok e instala a skill de uso.

## A pergunta essencial

**Se eu instalar isto em outra máquina, as ações no Chrome já saem otimizadas?**

**Sim, as duas camadas viajam com o `./install.sh` / `install.ps1`:**

| Camada | O que vai para a outra máquina | Efeito |
|---|---|---|
| **Servidor MCP** | bloco em `~/.grok/config.toml` | JPEG pequeno, cap de 256 KB, pin `1.8.0`, sem traces/telemetria, timeouts curtos, `--autoConnect` |
| **Agente** | skill `~/.grok/skills/grok-mcp-chrome/` | 1 `search_tool`, `fill_form`, `waitForStableDom: false`, sem PNG/snapshot em todo click |

O que **não** viaja (é da máquina destino):

- Chrome 144+, Node/`npx`, Grok já instalados
- Remote debugging ligado (`chrome://inspect/#remote-debugging`) e o **Allow** na primeira conexão
- Poucas abas no Chrome (dezenas de abas deixam o `--autoConnect` lento, independente deste repo)

`--slim` **não** é usado: ele tira `click` / `fill` / `take_snapshot` e quebra o fluxo real.

## Pré-requisitos na máquina destino

- Grok CLI/TUI
- Node.js LTS + `npx`
- Chrome **144+** (stable)

## Instalar

```bash
git clone https://github.com/LuanComputacao/grok-mcp-chrome.git
cd grok-mcp-chrome
chmod +x install.sh
./install.sh --dry-run
./install.sh
```

Windows (PowerShell):

```powershell
git clone https://github.com/LuanComputacao/grok-mcp-chrome.git
cd grok-mcp-chrome
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1 -DryRun
.\install.ps1
```

`$GROK_HOME` / `$env:GROK_HOME` apontam o destino (padrão `~/.grok` ou `%USERPROFILE%\.grok`).

Desinstalar: `./install.sh --uninstall` (remove o bloco `chrome-devtools` e a skill; **mantém** `[mcp] max_output_bytes`).

## Depois de instalar

1. Chrome aberto, **poucas abas**.
2. `chrome://inspect/#remote-debugging` → Remote Debugging.
3. Primeira tool do Grok → **Allow**.
4. Reiniciar o Grok, ou `/mcps` → `r`.

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

Outros MCP servers no `config.toml` não são alterados. Backup: `config.toml.bak.<timestamp>`.

## Testes

```bash
python3 test_merge.py
```

## Licença

MIT. O MCP em si é o pacote npm `chrome-devtools-mcp` (ChromeDevTools).

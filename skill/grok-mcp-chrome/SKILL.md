---
name: grok-mcp-chrome
description: >
  Use when driving Chrome from Grok via chrome-devtools MCP — navigate, click,
  fill forms, read DOM, screenshot, console/network, LinkedIn capture, UI verify.
  Triggers: chrome MCP, chrome-devtools, autoConnect, take_snapshot, fill_form,
  tarefas no Chrome, /grok-mcp-chrome.
---

# grok-mcp-chrome

Como chamar o Chrome DevTools MCP **rápido**. O instalador já gravou as flags no `config.toml`; esta skill cobre o **uso**.

Servidor: `chrome-devtools` (`chrome-devtools__*`). Sempre `pageId`.

## Turnos

1. **Um** `search_tool` no início, query `chrome-devtools`.
2. Depois só `use_tool`. Não redescobrir schema por tool.
3. `list_pages` **1×**; guardar `pageId`. `new_page` já devolve id.
4. `select_page` só com `bringToFront` (humano olhando). `pageId` já roteia.

## Playbook

| Tarefa | Sequência |
|---|---|
| Abrir URL | aba útil → `navigate_page`; senão `new_page {url}` |
| Clicar | `take_snapshot` → `click {uid}` (`includeSnapshot` omitido) |
| Form ≥2 campos | 1 snapshot → 1 `fill_form` |
| Ler dados | 1 `evaluate_script` com `waitForStableDom: false`; `filePath` se o JSON for grande |
| Visual | `take_screenshot` jpeg + `filePath`; `uid` se for recorte. Nunca `fullPage` PNG |
| Esperar SPA | `wait_for` 3–5 s (já traz snapshot). Não encadear `take_snapshot` |

## Proibido neste fluxo

- `--slim` / pedir tools que não existem (`find`, `form_input`, `javascript_tool`, `get_page_text`)
- `isolatedContext` em site já logado (perde cookie)
- `verbose: true` no snapshot
- `includeSnapshot: true` em todo click
- `evaluate_script` de **leitura** sem `waitForStableDom: false` (LinkedIn nunca quieta)
- `lighthouse_audit` / `performance_*` / `take_heapsnapshot` para UI
- `npx`/`list_pages` de novo a cada ação
- Dezenas de abas no Chrome `--autoConnect`

`evaluate_script` **vê** o DOM e as cookies da página.

## Se truncar

O Grok capou o resultado: ler o spill em `~/.grok/sessions/.../mcp/call-*.txt`. Não repetir `take_snapshot`/`take_screenshot` no mesmo estado.

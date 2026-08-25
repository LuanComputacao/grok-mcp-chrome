---
name: grok-mcp-chrome
description: >
  Use when driving Chrome from Grok via chrome-devtools MCP, choosing curl vs
  browser, probing page tech stack, extracting APIs from Network, clicking or
  filling UI, or verifying design/layout with screenshots. Triggers: chrome MCP,
  chrome-devtools, autoConnect, take_snapshot, fill_form, curl vs navegador,
  stack da página, verificação de UI, /grok-mcp-chrome.
---

# grok-mcp-chrome

Como usar o Chrome DevTools MCP **rápido e no canal certo**. Flags já estão no `config.toml`; esta skill cobre o **uso**.

Servidor: `chrome-devtools` (`chrome-devtools__*`). Sempre `pageId`.

Antes de navegar como humano: **classificar o objetivo** e **sondar a stack**. Carregar a página inteira é o caminho caro.

## 0. Classificar o objetivo

| Objetivo | Canal |
|---|---|
| Ler dado, JSON, HTML, status HTTP, API já conhecida | `curl` / `fetch` — **não** renderizar a UI |
| SPA: dado vem de XHR depois do JS | Interceptar Network **ou** `fetch` com cookie da sessão |
| Clicar, preencher, login, hover, upload, scroll infinito sem API óbvia | Browser (snapshot → ação) |
| **Verificação de design / UI / layout** | Browser + **screenshot obrigatório** (secção 4) |

Regra de ouro (HTTP vs browser): faça `curl` (ou `evaluate_script` `fetch`) e procure no corpo uma frase que você **vê** na tela. Se estiver lá, não precisa de browser. Browser custa ~10× CPU e vários turnos de modelo.

## 1. Sondar a stack **antes** da metodologia

No primeiro contato com um host novo, um probe. Sem Wappalyzer externo.

**Público / sem login:** `curl -sI` + `curl -s` (primeiros KB do HTML).

**Já no Chrome (sessão, SSO):** um `evaluate_script` (`waitForStableDom: false`):

```js
() => ({
  url: location.href,
  title: document.title,
  generator: document.querySelector('meta[name="generator"]')?.content || null,
  shell: {
    root: !!document.querySelector('#root, #app, #__nuxt, [data-reactroot]'),
    bodyTextLen: (document.body?.innerText || '').trim().length,
  },
  markers: {
    next: !!(window.__NEXT_DATA__ || document.getElementById('__NEXT_DATA__')),
    nuxt: !!(window.__NUXT__ || document.getElementById('__nuxt')),
    react: !!(window.__REACT_DEVTOOLS_GLOBAL_HOOK__ || document.querySelector('[data-reactroot]')),
    vue: !!(window.__VUE__ || window.Vue),
    angular: !!document.querySelector('[ng-version]'),
    sveltekit: !!document.querySelector('[data-sveltekit]'),
  },
})
```

Complete com `list_network_requests` `{resourceTypes:["fetch","xhr","document"]}` e headers do documento (`x-powered-by`, `cf-ray`, `x-vercel-id`, `x-shopify-stage`).

| Sinal | O que implica |
|---|---|
| HTML já tem o texto/dado; WordPress/SSR Next/Nuxt/Astro | `curl` / GET basta |
| `#root`/`#app` vazio + XHR JSON | **Não** scrapar o DOM. Pegar o endpoint (Network) e `fetch`/`curl` |
| Cookie de sessão + CSRF/`Origin` exigidos | Abrir no Chrome logado; daí replay `fetch` **na página** (herda cookie) |
| Canvas, mapa, WebSocket, anti-bot, captcha | Browser de verdade |
| `ng-version`, Vue/React client-only sem API visível | Browser + snapshot; não curl cego |

A stack define o método: lista paginada em JSON → Network; formulário Blade/Laravel → HTML+POST; dashboard React → sessão + API.

## 2. Direto (curl / POST no DevTools) vs página carregada

**Mais rápido sem pintar a página**

- Documento, blog, CMS, HTML estático
- SSR em que o HTML da primeira resposta já traz o conteúdo
- REST/GraphQL descoberto no Network (replay GET/POST)
- `evaluate_script`: `async () => (await fetch(url, {credentials:'include'})).json()` — usa cookie da aba, melhor que `curl` anônimo em site logado
- Healthcheck, download de arquivo, OpenAPI conhecida

**Precisa do navegador carregado**

- Login, SSO, captcha, passo a passo com estado na UI
- Clique, hover, drag, `<input type=file>`, dialog nativo
- Conteúdo que só existe depois de JS e **não** aparece num XHR reutilizável
- Scroll/virtual list sem endpoint estável
- Anti-bot que recusa `curl` (TLS/JA3, App Check)
- **Qualquer checagem visual de layout** (secção 4)

Não faça: `navigate` → snapshot → 8 clicks para chegar num JSON que o Network já mostrou.

Replay de POST: copiar URL, method, headers relevantes (`Authorization`, `x-csrf`, `Content-Type`) de `get_network_request`. Preferir `fetch` no documento da origem (mesmo `Origin`/`Referer`). `curl` anônimo falha em CSRF/cookie.

## 3. Achar elemento: DevTools, não print

Para **encontrar** botão, campo, texto, href, estado:

1. `take_snapshot` (árvore a11y + `uid` para `click`/`fill`)
2. `evaluate_script` (`querySelector`, `innerText`, computed style pontual)
3. Console / Network se o “elemento” for na verdade um request

Screenshot para achar seletor é o caminho lento (pixels → achismo → retry). A a11y tree já traz nome acessível e `uid`.

Exceção: o alvo **é** o pixel (overlap, alinhamento, cor, breakpoint) → secção 4.

## 4. MUITO IMPORTANTE — verificação de design / UI / layout

Se o pedido for layout, CSS, espaçamento, overlap, responsivo, visual regression, “está feio”, “bate com o Figma”, “confere o header no mobile”:

**Screenshot é obrigatório.** Snapshot, HTML e a11y **não provam** pixel. Sem print, não declare a verificação visual concluída.

- `take_screenshot` jpeg (as flags do instalador já limitam tamanho); `filePath` se for arquivo
- Viewport real do problema; `emulate`/`resize_page` se pediram mobile **e** desktop — os dois
- Recorte com `uid` quando o bug é um componente, não a página inteira
- Evitar `fullPage` PNG no contexto; full-page só se o layout abaixo da dobra for o objeto da checagem, e em arquivo
- Opcional: um snapshot **além** do print se depois for clicar no mesmo fluxo — o print não substitui o `uid`

Dados/API **não** usam esta regra: aí print é desperdício.

## Turnos (quando o browser está no caminho)

1. **Um** `search_tool`, query `chrome-devtools`. Depois só `use_tool`.
2. `list_pages` **1×**; guardar `pageId`. `new_page` já devolve id.
3. `select_page` só com `bringToFront`.

| Tarefa | Sequência |
|---|---|
| Abrir URL | aba útil → `navigate_page`; senão `new_page {url}` |
| Clicar | `take_snapshot` → `click {uid}` (`includeSnapshot` omitido) |
| Form ≥2 campos | 1 snapshot → 1 `fill_form` |
| Ler dados na página | 1 `evaluate_script` (`waitForStableDom: false`); `filePath` se JSON grande |
| Esperar SPA | `wait_for` 3–5 s (já traz snapshot) |

## Proibido

- `--slim` / tools que não existem (`find`, `form_input`, `javascript_tool`, `get_page_text`)
- `isolatedContext` em site já logado
- `verbose: true` no snapshot; `includeSnapshot: true` em todo click
- `evaluate_script` de leitura sem `waitForStableDom: false`
- `lighthouse_audit` / `performance_*` / heap para UI
- `list_pages` de novo a cada ação; dezenas de abas no `--autoConnect`
- Declaração de QA visual **sem** screenshot

`evaluate_script` **vê** o DOM e as cookies da página.

## Se truncar

Ler o spill em `~/.grok/sessions/.../mcp/call-*.txt`. Não repetir a mesma captura no mesmo estado.

#!/usr/bin/env bash
# Instala o Chrome DevTools MCP otimizado + skill no Grok (Linux).
set -euo pipefail

PACKAGE_VERSION="1.8.0"
MIN_CHROME_MAJOR=144
WARN_CHROME_MAJOR=149
MIN_NODE_MAJOR=20
DOCS_URL="https://github.com/LuanComputacao/grok-mcp-chrome#comece-aqui"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGER="$SCRIPT_DIR/merge_grok_chrome_mcp.js"
SKILL_SRC="$SCRIPT_DIR/skill/grok-mcp-chrome"

usage() {
  cat <<EOF
Uso: $(basename "$0") [--check] [--dry-run] [--force] [--uninstall] [--help]

1. Verifica Node ≥${MIN_NODE_MAJOR}, npx, Google Chrome ≥${MIN_CHROME_MAJOR}, Grok
2. Grava [mcp_servers.chrome-devtools] em \$GROK_HOME/config.toml
3. Copia a skill para \$GROK_HOME/skills/grok-mcp-chrome/

  --check       só o preflight; exit 1 se faltar algo
  --dry-run     preflight + diff; não grava
  --force       grava mesmo com Chrome/Grok ausentes; ainda exige Node.
                exit 1 no fim (MCP não validado)
  --uninstall   remove o bloco chrome-devtools e a skill (mantém [mcp])
  --help        esta ajuda

Este script NÃO instala Node/Chrome/Grok. README: ${DOCS_URL}
EOF
}

DRY_RUN=0
UNINSTALL=0
CHECK_ONLY=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --check) CHECK_ONLY=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

GROK_HOME="${GROK_HOME:-$HOME/.grok}"
CONFIG="$GROK_HOME/config.toml"
SKILL_DST="$GROK_HOME/skills/grok-mcp-chrome"

have() { command -v "$1" >/dev/null 2>&1; }

find_chrome() {
  local c
  for c in google-chrome-stable google-chrome \
           /usr/bin/google-chrome-stable /usr/bin/google-chrome \
           /opt/google/chrome/google-chrome; do
    if have "$c"; then
      command -v "$c"
      return 0
    fi
    if [[ -x "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

chrome_major() {
  local bin="$1" line
  line=$("$bin" --product-version 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    line=$("$bin" --version 2>/dev/null || true)
  fi
  if [[ "$line" =~ ([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo 0
  fi
}

node_major() {
  local v
  v=$(node -v 2>/dev/null || echo v0)
  v="${v#v}"
  echo "${v%%.*}"
}

find_grok() {
  local c
  for c in grok "$GROK_HOME/bin/grok" "$HOME/.grok/bin/grok"; do
    if have "$c"; then
      command -v "$c"
      return 0
    fi
    if [[ -x "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

ok() { echo "  [ok]   $*"; }
fail() { echo "  [FAIL] $*" >&2; PRE_FAIL=1; }
warn() { echo "  [warn] $*"; PRE_WARN=1; }

preflight() {
  PRE_FAIL=0
  PRE_WARN=0
  echo "==> Preflight (pré-requisitos)"
  echo

  if have node; then
    local nm
    nm="$(node_major)"
    if [[ "$nm" -ge "$MIN_NODE_MAJOR" ]]; then
      ok "node $(node -v) — merge TOML + npx do MCP"
    else
      fail "node $(node -v) — precisa major ≥ ${MIN_NODE_MAJOR} (LTS 20/22)."
    fi
  else
    fail "node ausente no PATH."
    echo "         curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash"
    echo "         nvm install --lts && nvm use --lts"
  fi

  if have npx; then
    ok "npx $(command -v npx)"
  else
    fail "npx ausente (vem com o Node.js)."
  fi

  if [[ "$UNINSTALL" -eq 1 ]]; then
    echo
    if [[ "$PRE_FAIL" -eq 1 ]]; then
      echo "Preflight FALHOU. --uninstall precisa do Node para mesclar o TOML."
      return 1
    fi
    echo "Preflight OK (modo uninstall)."
    echo
    return 0
  fi

  local chrome_bin major
  if chrome_bin="$(find_chrome)"; then
    major="$(chrome_major "$chrome_bin")"
    if [[ "$major" -ge "$MIN_CHROME_MAJOR" ]]; then
      ok "Google Chrome $major ($chrome_bin)"
      if [[ "$major" -lt "$WARN_CHROME_MAJOR" ]]; then
        warn "Chrome $major < ${WARN_CHROME_MAJOR}: abas discarded podem dar timeout no autoConnect. Atualize o Chrome."
      fi
    else
      fail "Chrome $major em $chrome_bin — autoConnect precisa Google Chrome ≥ ${MIN_CHROME_MAJOR}."
      echo "         https://www.google.com/chrome/"
    fi
  else
    fail "Google Chrome stable não encontrado (não usamos Chromium)."
    echo "         https://www.google.com/chrome/"
  fi

  local grok_bin
  if grok_bin="$(find_grok)"; then
    local gv
    gv=$("$grok_bin" --version 2>/dev/null | head -1 || true)
    ok "grok ${gv:-ok} ($grok_bin)"
  else
    fail "Grok CLI não encontrado (PATH nem $GROK_HOME/bin/grok)."
    echo "         curl -fsSL https://x.ai/cli/install.sh | bash"
  fi

  local nchrome nmcp
  nchrome=$(pgrep -c -u "$USER" -x chrome 2>/dev/null || pgrep -c -u "$USER" chrome 2>/dev/null || echo 0)
  if [[ "${nchrome:-0}" -gt 40 ]]; then
    warn "muitos processos chrome (${nchrome}) — --autoConnect anexa todas as abas e fica lento. Feche ociosas."
  fi
  nmcp=$(pgrep -c -u "$USER" -f 'chrome-devtools-mcp' 2>/dev/null || echo 0)
  if [[ "${nmcp:-0}" -gt 2 ]]; then
    warn "${nmcp} processos chrome-devtools-mcp — cada respawn pede Allow de novo."
  fi
  if [[ -n "${chrome_bin:-}" ]] && [[ ! -f "$HOME/.config/google-chrome/DevToolsActivePort" ]]; then
    warn "sem DevToolsActivePort — ligue chrome://inspect/#remote-debugging com o Chrome aberto."
  fi

  echo
  if [[ "$PRE_FAIL" -eq 1 ]]; then
    echo "Preflight FALHOU. Instale os itens [FAIL] e rode de novo. Docs: $DOCS_URL"
    echo
    return 1
  fi
  echo "Preflight OK."
  echo
  return 0
}

if [[ ! -f "$MERGER" ]]; then
  echo "Erro: merger ausente: $MERGER" >&2
  exit 1
fi
if [[ "$UNINSTALL" -eq 0 && ! -f "$SKILL_SRC/SKILL.md" ]]; then
  echo "Erro: skill ausente: $SKILL_SRC/SKILL.md" >&2
  exit 1
fi

echo "==> grok-mcp-chrome installer (Linux)"
echo "    config: $CONFIG"
echo "    skill:  $SKILL_DST"
echo "    pacote: chrome-devtools-mcp@${PACKAGE_VERSION}"
echo

DIRTY=0
if ! preflight; then
  DIRTY=1
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    exit 1
  fi
  if [[ "$FORCE" -ne 1 ]]; then
    exit 1
  fi
  if ! have node; then
    echo "--force não dispensa Node (preciso dele para mesclar o TOML)." >&2
    exit 1
  fi
  echo "--force: gravando arquivos mesmo com preflight falho."
  echo
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "Só --check; nada gravado."
  exit 0
fi

merge_args=()
if [[ "$UNINSTALL" -eq 1 ]]; then
  merge_args+=(--uninstall)
fi

new_file="$(mktemp)"
trap 'rm -f "$new_file"' EXIT
if [[ -f "$CONFIG" ]]; then
  node "$MERGER" "${merge_args[@]}" "$CONFIG" > "$new_file"
else
  node "$MERGER" "${merge_args[@]}" </dev/null > "$new_file"
fi

config_changed=1
if [[ -f "$CONFIG" ]] && cmp -s "$CONFIG" "$new_file"; then
  config_changed=0
fi

if have diff && [[ "$config_changed" -eq 1 ]]; then
  echo "--- diff config.toml ---"
  old="$CONFIG"
  if [[ ! -f "$CONFIG" ]]; then
    old=/dev/null
  fi
  diff -u --label "$CONFIG" --label "${CONFIG}.new" "$old" "$new_file" || true
  echo "------------------------"
  echo
fi

if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Skill a remover: $SKILL_DST"
else
  echo "Skill: $SKILL_SRC -> $SKILL_DST"
fi
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry-run: nenhuma escrita."
  exit 0
fi

mkdir -p "$GROK_HOME"
if [[ "$config_changed" -eq 1 ]]; then
  if [[ -f "$CONFIG" ]]; then
    bak="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$CONFIG" "$bak"
    echo "Backup: $bak"
  fi
  cp "$new_file" "$CONFIG"
  echo "Gravado: $CONFIG"
else
  echo "config.toml já estava no estado pedido."
fi

if [[ "$UNINSTALL" -eq 1 ]]; then
  if [[ -d "$SKILL_DST" ]]; then
    rm -rf "$SKILL_DST"
    echo "Skill removida: $SKILL_DST"
  fi
  echo "Reinicie o Grok (MCP: /mcps → r). Skill some na próxima sessão."
  exit 0
fi

mkdir -p "$GROK_HOME/skills"
if [[ -f "$SKILL_DST/SKILL.md" ]] && cmp -s "$SKILL_SRC/SKILL.md" "$SKILL_DST/SKILL.md"; then
  echo "Skill já estava atualizada."
else
  if [[ -f "$SKILL_DST/SKILL.md" ]]; then
    cp -a "$SKILL_DST/SKILL.md" "$SKILL_DST/SKILL.md.bak.$(date +%Y%m%d%H%M%S)"
  fi
  rm -rf "$SKILL_DST"
  cp -a "$SKILL_SRC" "$SKILL_DST"
  echo "Skill gravada: $SKILL_DST/SKILL.md"
fi
echo

cat <<EOF
Privacidade: --autoConnect vê o Chrome da sua vida. Tool results vão para a API xAI.
Feche banco/e-mail/gov se não forem o alvo. Allow = CDP no perfil pessoal.

Próximos passos:
  1. Chrome ${MIN_CHROME_MAJOR}+ aberto, poucas abas (nunca feche a última).
  2. chrome://inspect/#remote-debugging → Remote Debugging.
  3. Primeira tool → Allow (de novo após /mcps r ou save do config).
  4. Restart do Grok. /mcps → r recarrega MCP, não a skill já injetada neste turno.

Camadas: flags MCP + skill.
EOF

if [[ "$DIRTY" -eq 1 ]]; then
  echo
  echo "INSTALOU ARQUIVOS; MCP NÃO VALIDADO (preflight falhou; --force)."
  exit 1
fi
exit 0

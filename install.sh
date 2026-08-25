#!/usr/bin/env bash
# Instala o Chrome DevTools MCP otimizado + skill no Grok (Linux).
# Não instala Node, Chrome nem o Grok. Não mexe em outros MCP servers.
set -euo pipefail

PACKAGE_VERSION="1.8.0"
MIN_CHROME_MAJOR=144
MIN_NODE_MAJOR=20
DOCS_URL="https://github.com/LuanComputacao/grok-mcp-chrome#pré-requisitos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGER="$SCRIPT_DIR/merge_grok_chrome_mcp.py"
SKILL_SRC="$SCRIPT_DIR/skill/grok-mcp-chrome"

usage() {
  cat <<EOF
Uso: $(basename "$0") [--check] [--dry-run] [--force] [--uninstall] [--help]

1. Verifica pré-requisitos (Python 3, Node ≥${MIN_NODE_MAJOR}, npx, Chrome ≥${MIN_CHROME_MAJOR}, Grok)
2. Grava [mcp_servers.chrome-devtools] em \$GROK_HOME/config.toml
3. Copia a skill para \$GROK_HOME/skills/grok-mcp-chrome/

  --check       só o preflight; não grava nada (exit 1 se faltar algo)
  --dry-run     preflight + mostra o diff, não grava
  --force       grava mesmo se o preflight falhar
  --uninstall   remove o bloco chrome-devtools e a skill (mantém [mcp])
  --help        esta ajuda

Este script NÃO instala Node/Chrome/Grok. Instruções: README.md
  ${DOCS_URL}
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
  for c in google-chrome-stable google-chrome chromium chromium-browser \
           /usr/bin/google-chrome /usr/bin/google-chrome-stable \
           /usr/bin/chromium /usr/bin/chromium-browser; do
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
  local bin="$1" line major
  line=$("$bin" --product-version 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    line=$("$bin" --version 2>/dev/null || true)
  fi
  major=$(printf '%s' "$line" | grep -oE '[0-9]+' | head -1 || true)
  printf '%s' "${major:-0}"
}

node_major() {
  local v
  v=$(node -v 2>/dev/null || echo "v0")
  printf '%s' "$v" | grep -oE '[0-9]+' | head -1
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
warn() { echo "  [warn] $*"; }

preflight() {
  PRE_FAIL=0
  echo "==> Preflight (pré-requisitos)"
  echo

  if have python3; then
    ok "python3 $(python3 -V 2>&1 | awk '{print $2}') — merge do config.toml"
  else
    fail "python3 ausente (necessário para mesclar o TOML)."
    echo "         Linux: sudo apt install python3    # Debian/Ubuntu"
    echo "                sudo dnf install python3    # Fedora"
  fi

  if [[ "$UNINSTALL" -eq 1 ]]; then
    echo
    if [[ "$PRE_FAIL" -eq 1 ]]; then
      echo "Preflight FALHOU (python3). --uninstall precisa dele para mesclar o TOML."
      return 1
    fi
    echo "Preflight OK (modo uninstall)."
    echo
    return 0
  fi

  if have node; then
    local nm
    nm="$(node_major)"
    if [[ "$nm" -ge "$MIN_NODE_MAJOR" ]]; then
      ok "node $(node -v) (npx: $(command -v npx 2>/dev/null || echo ausente))"
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
    fail "npx ausente (vem com o Node.js; o Grok spawna npx -y chrome-devtools-mcp@${PACKAGE_VERSION})."
  fi

  local chrome_bin major
  if chrome_bin="$(find_chrome)"; then
    major="$(chrome_major "$chrome_bin")"
    if [[ "$major" -ge "$MIN_CHROME_MAJOR" ]]; then
      ok "chrome $major ($chrome_bin) — autoConnect exige ≥ ${MIN_CHROME_MAJOR}"
    else
      fail "chrome $major em $chrome_bin — autoConnect precisa Chrome ≥ ${MIN_CHROME_MAJOR} (não Chromium antigo)."
      echo "         https://www.google.com/chrome/  ou  README.md § Chrome"
    fi
  else
    fail "Google Chrome não encontrado."
    echo "         https://www.google.com/chrome/  (pacote google-chrome-stable)"
  fi

  local grok_bin
  if grok_bin="$(find_grok)"; then
    local gv
    gv=$("$grok_bin" --version 2>/dev/null | head -1 || true)
    ok "grok ${gv:-ok} ($grok_bin)"
  else
    fail "Grok CLI não encontrado (PATH nem $GROK_HOME/bin/grok)."
    echo "         curl -fsSL https://x.ai/cli/install.sh | bash"
    echo "         depois: grok --version"
  fi

  echo
  if [[ "$PRE_FAIL" -eq 1 ]]; then
    echo "Preflight FALHOU. Instale os itens [FAIL] (instruções no README) e rode de novo."
    echo "Docs: $DOCS_URL"
    echo "Ou:   $0 --force   (grava config/skill mesmo assim — o MCP pode não subir)"
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

if ! preflight; then
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    exit 1
  fi
  if [[ "$FORCE" -ne 1 ]]; then
    exit 1
  fi
  echo "--force: seguindo mesmo com preflight falho."
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
  python3 "$MERGER" "${merge_args[@]}" "$CONFIG" > "$new_file"
else
  python3 "$MERGER" "${merge_args[@]}" </dev/null > "$new_file"
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
  echo "Skill a copiar: $SKILL_SRC -> $SKILL_DST"
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
  echo "Reinicie o Grok (ou /mcps → r)."
  exit 0
fi

mkdir -p "$GROK_HOME/skills"
rm -rf "$SKILL_DST"
cp -a "$SKILL_SRC" "$SKILL_DST"
echo "Skill gravada: $SKILL_DST/SKILL.md"
echo

cat <<EOF
Próximos passos (--autoConnect):
  1. Chrome ${MIN_CHROME_MAJOR}+ aberto, poucas abas.
  2. chrome://inspect/#remote-debugging → ligar Remote Debugging.
  3. Primeira tool do Grok → Allow.
  4. Reiniciar o Grok, ou /mcps → r.

Camadas instaladas: flags MCP (config.toml) + playbook do agente (skill).
EOF
exit 0

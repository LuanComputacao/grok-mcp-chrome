#!/usr/bin/env bash
# Instala o Chrome DevTools MCP otimizado + skill no Grok (Linux).
# Não instala Node nem Chrome. Não mexe em outros MCP servers.
set -euo pipefail

PACKAGE_VERSION="1.8.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGER="$SCRIPT_DIR/merge_grok_chrome_mcp.py"
SKILL_SRC="$SCRIPT_DIR/skill/grok-mcp-chrome"

usage() {
  cat <<EOF
Uso: $(basename "$0") [--dry-run] [--uninstall] [--help]

1. Grava [mcp_servers.chrome-devtools] (flags rápidas) em \$GROK_HOME/config.toml
2. Copia a skill para \$GROK_HOME/skills/grok-mcp-chrome/

  --dry-run     mostra o diff sem gravar
  --uninstall   remove o bloco chrome-devtools e a skill (mantém [mcp])
  --help        esta ajuda

Pré-requisitos (este script NÃO instala): Node.js + npx, Chrome 144+, Grok
EOF
}

DRY_RUN=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --uninstall) UNINSTALL=1 ;;
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
    if have "$c" || [[ -x "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

if [[ ! -f "$MERGER" ]]; then
  echo "Erro: merger ausente: $MERGER" >&2
  exit 1
fi
if ! have python3; then
  echo "Erro: python3 é necessário para mesclar o TOML com segurança." >&2
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

MISSING=0
if ! have node; then
  echo "AVISO: node não encontrado no PATH." >&2
  MISSING=1
fi
if ! have npx; then
  echo "AVISO: npx não encontrado no PATH." >&2
  MISSING=1
fi
if chrome_bin="$(find_chrome)"; then
  echo "Chrome: $chrome_bin"
else
  echo "AVISO: Chrome/Chromium não encontrado. Precisa Chrome 144+ para --autoConnect." >&2
  MISSING=1
fi
echo

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
  1. Chrome 144+ aberto, poucas abas.
  2. chrome://inspect/#remote-debugging → ligar Remote Debugging.
  3. Primeira tool do Grok → Allow.
  4. Reiniciar o Grok, ou /mcps → r.

Camadas instaladas: flags MCP (config.toml) + playbook do agente (skill).
EOF

if [[ "$MISSING" -eq 1 ]]; then
  echo
  echo "Há avisos de pré-requisito acima. Config/skill foram gravados mesmo assim."
fi
exit 0

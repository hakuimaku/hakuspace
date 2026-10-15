#!/usr/bin/env bash
set -euo pipefail

# Classic HakuMenu frontend. Menu providers keep their existing public
# basenames because Rofi script-mode resolves them from the flat deployment.

if [[ "${1:-}" == "--extend" || "${1:-}" == "-e" ]]; then
    shift
    EXTEND=("$@")
else
    EXTEND=()
fi

exec rofi -show "" \
    -p "Haku Menu - Search" \
    -i \
    "${EXTEND[@]}" \
    -modes ":~/.local/bin/hm_general.sh,:~/.local/bin/hm_theme.sh,:~/.local/bin/hm_setting.sh"

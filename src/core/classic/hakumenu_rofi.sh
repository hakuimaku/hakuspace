#!/usr/bin/env bash
set -euo pipefail

# Classic HakuMenu frontend. Menu providers keep their existing public
# basenames because Rofi script-mode resolves them from the flat deployment.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1

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
    -modes ":$HAKU_BIN_DIR/hm_general.sh,:$HAKU_BIN_DIR/hm_theme.sh,:$HAKU_BIN_DIR/hm_setting.sh"

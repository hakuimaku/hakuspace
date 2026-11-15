#!/usr/bin/env bash
set -euo pipefail

# Preserve the public basename for Classic callers.
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
exec python3 "$HAKU_BIN_DIR/hm_general_rofi.py" "$@"

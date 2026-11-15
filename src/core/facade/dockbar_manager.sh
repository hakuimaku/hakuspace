#!/usr/bin/env bash

# Expose compact Dockbar control through the installed public facade.
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
exec bash "$HAKU_BIN_DIR/dockbar_ctl.sh" "$@"

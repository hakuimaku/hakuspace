#!/usr/bin/env bash
set -euo pipefail

# Stable HakuMenu entrypoint. Classic opens the Rofi frontend; Hikai opens the
# native Quickshell HakuMenu through IPC.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
HAKUMENU_ROFI="$HAKU_BIN_DIR/hakumenu_rofi.sh"

if haku_backend_is "classic"; then
    exec "$HAKUMENU_ROFI" "$@"
fi

# Hikai owns its menu presentation. Classic-only positioning arguments are not
# interpreted by the native surface.
haku_qs_ipc hakumenu openDefault

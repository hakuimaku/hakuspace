#!/usr/bin/env bash
set -euo pipefail

# Stable HakuMenu entrypoint. Classic opens the Rofi frontend; Hikai opens the
# native Quickshell HakuMenu through IPC.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1"
    local source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'hakumenu.sh: unable to resolve %s\n' "$name" >&2
    return 1
}

HAKU_BACKEND_LIB="$(resolve_script haku_backend_lib.sh ../lib/haku_backend_lib.sh)" || exit 1
HAKUMENU_ROFI="$(resolve_script hakumenu_rofi.sh ../frontend/classic/hakumenu_rofi.sh)" || exit 1

# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

if haku_backend_is "classic"; then
    exec "$HAKUMENU_ROFI" "$@"
fi

# Hikai owns its menu presentation. Classic-only positioning arguments are not
# interpreted by the native surface.
haku_qs_ipc hakumenu openDefault

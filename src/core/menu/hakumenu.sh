#!/usr/bin/env bash
set -euo pipefail

# Stable HakuMenu entrypoint. Hikai currently opens its native HakuMenu through
# its own trigger path, so this command preserves the existing Classic Rofi
# behavior without embedding the Rofi invocation in the routing script.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_frontend() {
    local candidate
    for candidate in \
        "$SCRIPT_DIR/hakumenu_rofi.sh" \
        "$SCRIPT_DIR/../frontend/classic/hakumenu_rofi.sh" \
        "$HOME/.local/bin/hakumenu_rofi.sh"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'hakumenu.sh: unable to resolve hakumenu_rofi.sh\n' >&2
    return 1
}

exec "$(resolve_frontend)" "$@"

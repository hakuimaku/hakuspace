#!/usr/bin/env bash

# Public compatibility facade for Niri animation selection.
# No-arg behavior remains the Classic Rofi UI; explicit state commands are
# delegated to the headless controller.

set -euo pipefail

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
NIRI_ANIMATION_CTL="$HAKU_BIN_DIR/niri_animation_ctl.sh"
NIRI_ANIMATION_ROFI="$HAKU_BIN_DIR/niri_animation_rofi.sh"

print_help() {
    cat <<'EOF_HELP'
Usage: niri_animation_switcher.sh [OPTION]
Manage Niri animation transitions.

No arguments:
    Classic             Open the Classic Niri animation picker
    Hikai               Open the native centered Niri animation action layer

Options:
    --list [--json]       List mode/option/active state
    --get MODE            Print active option id for MODE
    --set MODE OPTION     Select OPTION for MODE
    -h, --help            Show this help message

Legacy script-mode calls of the form <Mode> [Option] remain supported.
EOF_HELP
}

case "${1:-}" in
    ''|menu|--menu)
        if haku_backend_is "classic"; then
            exec "$NIRI_ANIMATION_ROFI" menu
        fi
        haku_qs_ipc actionMenu openDefault niriAnimation
        ;;
    --list|list)
        shift
        exec "$NIRI_ANIMATION_CTL" list "${1:-}"
        ;;
    --get|get)
        exec "$NIRI_ANIMATION_CTL" get "${2:-}"
        ;;
    --set|set)
        exec "$NIRI_ANIMATION_CTL" set "${2:-}" "${3:-}"
        ;;
    -h|--help)
        print_help
        ;;
    *)
        # Preserve the old Rofi script-mode handler entry point.
        exec "$NIRI_ANIMATION_ROFI" handler "$1" "${2:-}"
        ;;
esac

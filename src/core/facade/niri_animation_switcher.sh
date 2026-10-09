#!/usr/bin/env bash

# Public compatibility facade for Niri animation selection.
# No-arg behavior remains the Classic Rofi UI; explicit state commands are
# delegated to the headless controller.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2"
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
    printf 'niri_animation_switcher.sh: required script not found: %s\n' "$name" >&2
    return 1
}

NIRI_ANIMATION_CTL="$(resolve_script niri_animation_ctl.sh ../backend/wm/niri_animation_ctl.sh)" || exit 1
NIRI_ANIMATION_ROFI="$(resolve_script niri_animation_rofi.sh ../frontend/classic/niri_animation_rofi.sh)" || exit 1

print_help() {
    cat <<'EOF_HELP'
Usage: niri_animation_switcher.sh [OPTION]
Open the Classic Niri animation picker or use the headless animation API.

Options:
    --list [--json]       List mode/option/active state
    --get MODE            Print active option id for MODE
    --set MODE OPTION     Select OPTION for MODE
    -h, --help            Show this help message

Legacy script-mode calls of the form <Mode> [Option] remain supported.
EOF_HELP
}

case "${1:-}" in
    '')
        exec "$NIRI_ANIMATION_ROFI" menu
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

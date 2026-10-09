#!/usr/bin/env bash

# Public compatibility facade for Waybar management.
# Keep this basename/CLI stable for keybinds, startup files and user configs.
# Domain mutation lives in waybar_ctl.sh; Classic picker UI lives in
# waybar_rofi.sh.

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
    printf 'waybar_manager.sh: required script not found: %s\n' "$name" >&2
    return 1
}

source_core_lib() {
    local name="$1"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/../lib/$name" \
        "$HOME/.local/bin/$name"; do
        if [[ -f "$candidate" ]]; then
            # shellcheck source=/dev/null
            source "$candidate"
            return 0
        fi
    done
    printf 'waybar_manager.sh: required library not found: %s\n' "$name" >&2
    return 1
}

WAYBAR_CTL="$(resolve_script waybar_ctl.sh ../backend/desktop/waybar_ctl.sh)" || exit 1
WAYBAR_ROFI="$(resolve_script waybar_rofi.sh ../frontend/classic/waybar_rofi.sh)" || exit 1
source_core_lib haku_backend_lib.sh || exit 1

print_help() {
    cat <<'EOF_HELP'
Usage: waybar_manager.sh [OPTION]
Select and manage the active Waybar mode.

Options:
    --cycle             Switch to the next Waybar mode
    --select            Select a Waybar mode with the Classic picker
    --reload            Reload Waybar
    --toggle            Toggle Waybar on or off
    -h, --help          Show this help message
EOF_HELP
}

if haku_qs_mode; then
    case "${1:-}" in
        --toggle)
            exec "$WAYBAR_CTL" toggle
            ;;
        --cycle|--select)
            notify-send -a "HakuSpace" -i "info" "Quickshell Mode" "Only 'top' variant is supported in quickshell right now."
            exit 0
            ;;
        --reload|'')
            exit 0
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
fi

case "${1:-}" in
    '')
        exec "$WAYBAR_CTL" startup
        ;;
    --cycle)
        exec "$WAYBAR_CTL" cycle
        ;;
    --select)
        exec "$WAYBAR_ROFI" select
        ;;
    --reload)
        exec "$WAYBAR_CTL" reload
        ;;
    --toggle)
        exec "$WAYBAR_CTL" toggle
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

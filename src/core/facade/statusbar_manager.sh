#!/usr/bin/env bash

# Public compatibility facade for status bar management (Classic Waybar and Hikai Topbar/Leftbar).
# Keep this basename/CLI stable for keybinds, startup files and user configs.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
WAYBAR_CTL="$HAKU_BIN_DIR/waybar_ctl.sh"
WAYBAR_ROFI="$HAKU_BIN_DIR/waybar_rofi.sh"
TASKBAR_CTL="$HAKU_BIN_DIR/taskbar_ctl.sh"

print_help() {
    cat <<'EOF_HELP'
Usage: statusbar_manager.sh [OPTION]
Select and manage the active status bar mode.

Options:
    --cycle             Switch to the next status bar mode
    --select            Select a status bar mode with the Classic picker
    --reload            Reload status bar
    --toggle            Toggle status bar on or off
    -h, --help          Show this help message
EOF_HELP
}

if haku_qs_mode; then
    case "${1:-}" in
        --toggle)
            exec "$WAYBAR_CTL" toggle
            ;;
        --cycle)
            exec "$TASKBAR_CTL" --layout cycle
            ;;
        --select)
            notify-send -a "HakuSpace" -i "info" "Quickshell Mode" "Status bar selection is managed via Settings / HakuMenu in Hikai mode."
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

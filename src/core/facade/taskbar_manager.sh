#!/usr/bin/env bash

# Public compatibility facade for Taskbar management.
# Keep this basename/CLI stable for keybinds, startup files and user configs.
# Domain mutation lives in taskbar_ctl.sh; Classic picker UI lives in
# taskbar_rofi.sh.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
TASKBAR_CTL="$HAKU_BIN_DIR/taskbar_ctl.sh"
TASKBAR_ROFI="$HAKU_BIN_DIR/taskbar_rofi.sh"

print_help() {
    cat <<'EOF_HELP'
Usage: taskbar_manager.sh [OPTION]
Manage the taskbar behavior.

Options:
    --startup           Restore previous state at boot
    --reload            Reload the taskbar
    --layout TARGET     Set topbar, leftbar, taskbar or cycle explicitly
    --set STATE         Set enabled or disabled explicitly
    --toggle            Toggle the taskbar on/off
    --status            Print enabled or disabled
    --app-name          Toggle app name format
    --icon-size         Change the icon size
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    --layout|--set)
        exec "$TASKBAR_CTL" "$@"
        ;;
    --startup|--reload|--toggle|--status)
        exec "$TASKBAR_CTL" "$1"
        ;;
    --app-name)
        exec "$TASKBAR_CTL" --toggle-app-name
        ;;
    --icon-size)
        exec "$TASKBAR_ROFI" icon-size
        ;;
    -h|--help)
        print_help
        ;;
    *)
        echo "Invalid option. Use --help for usage information."
        exit 0
        ;;
esac

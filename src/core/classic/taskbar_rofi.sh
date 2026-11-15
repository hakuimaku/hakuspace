#!/usr/bin/env bash

# Classic Taskbar presentation adapter. Picker/UI belongs here; all mutation is
# delegated to the headless taskbar_ctl.sh backend.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
TASKBAR_CTL="$HAKU_BIN_DIR/taskbar_ctl.sh"

pick_icon_size() {
    local current_size new_size
    current_size="$("$TASKBAR_CTL" --get-icon-size)" || return 1

    new_size="$(rofi -dmenu -p "Icon size (current: $current_size):" <<< "$current_size" -theme option-menu.rasi)"
    if [[ -z "$new_size" ]]; then
        return 0
    fi

    if [[ ! "$new_size" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    "$TASKBAR_CTL" --set-icon-size "$new_size"
}

print_help() {
    cat <<'EOF_HELP'
Usage: taskbar_rofi.sh COMMAND
Classic Taskbar picker frontend.

Commands:
    icon-size       Pick and apply Taskbar icon size
    -h, --help      Show this help message
EOF_HELP
}

case "${1:-}" in
    icon-size)
        pick_icon_size
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

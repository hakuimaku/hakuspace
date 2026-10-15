#!/usr/bin/env bash

# Classic Taskbar presentation adapter. Picker/UI belongs here; all mutation is
# delegated to the headless taskbar_ctl.sh backend.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_taskbar_ctl() {
    local candidate
    for candidate in \
        "$SCRIPT_DIR/taskbar_ctl.sh" \
        "$SCRIPT_DIR/../../backend/desktop/taskbar_ctl.sh" \
        "$HOME/.local/bin/taskbar_ctl.sh"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'taskbar_rofi.sh: taskbar_ctl.sh not found.\n' >&2
    return 1
}

TASKBAR_CTL="$(resolve_taskbar_ctl)" || exit 1

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

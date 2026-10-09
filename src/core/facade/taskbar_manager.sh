#!/usr/bin/env bash

# Public compatibility facade for Taskbar management.
# Keep this basename/CLI stable for keybinds, startup files and user configs.
# Domain mutation lives in taskbar_ctl.sh; Classic picker UI lives in
# taskbar_rofi.sh.

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
    printf 'taskbar_manager.sh: required script not found: %s\n' "$name" >&2
    return 1
}

TASKBAR_CTL="$(resolve_script taskbar_ctl.sh ../backend/desktop/taskbar_ctl.sh)" || exit 1
TASKBAR_ROFI="$(resolve_script taskbar_rofi.sh ../frontend/classic/taskbar_rofi.sh)" || exit 1

print_help() {
    cat <<'EOF_HELP'
Usage: taskbar_manager.sh [OPTION]
Manage the taskbar behavior.

Options:
    --startup           Restore previous state at boot
    --reload            Reload the taskbar
    --toggle            Toggle the taskbar on/off
    --app-name          Toggle app name format
    --icon-size         Change the icon size
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    --startup|--reload|--toggle)
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

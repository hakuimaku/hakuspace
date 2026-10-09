#!/usr/bin/env bash

# Classic Waybar selector frontend. It owns only presentation/selection and
# delegates all state/process mutation to the headless waybar controller.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_waybar_ctl() {
    local candidate
    for candidate in \
        "$SCRIPT_DIR/waybar_ctl.sh" \
        "$SCRIPT_DIR/../../backend/desktop/waybar_ctl.sh" \
        "$HOME/.local/bin/waybar_ctl.sh"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'waybar_rofi.sh: waybar_ctl.sh not found.\n' >&2
    return 1
}

WAYBAR_CTL="$(resolve_waybar_ctl)" || exit 1

select_mode() {
    local current choice
    [[ "$("$WAYBAR_CTL" status)" == "enabled" ]] || return 0
    current="$("$WAYBAR_CTL" current)" || return 1
    choice="$("$WAYBAR_CTL" list | rofi -dmenu -p "Waybar" -i -theme option-menu.rasi)"
    [[ -z "$choice" ]] && return 0
    [[ "$choice" == "$current" ]] && return 0
    "$WAYBAR_CTL" set "$choice"
}

print_help() {
    cat <<'EOF_HELP'
Usage: waybar_rofi.sh COMMAND
Classic Waybar selector frontend.

Commands:
    select              Pick and apply a Waybar mode
    -h, --help          Show this help message
EOF_HELP
}

case "${1:-}" in
    select|--select)
        select_mode
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

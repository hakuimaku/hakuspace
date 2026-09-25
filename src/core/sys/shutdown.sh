#!/usr/bin/env bash

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -e, --extend <ARG>       Set the position of the rofi window
    -v, --vertical           Use the vertical shutdown theme
    -h, --help               Show this help message
EOF
}

EXTEND=()
THEME="shutdown.rasi"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--extend)
            shift
            EXTEND=("$@")
            break
            ;;
        -v|--vertical)
            THEME="shutdown-vert.rasi"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# List options
options="󰒲

󰤆
󰤁
󱅞
󰩈"

# Design rofi
chosen=$(printf '%s\n' "$options" | rofi -dmenu -p "Shutdown" -i -theme "$THEME" "${EXTEND[@]}")

# List action
case "$chosen" in 
    *"󰒲"*)
        systemctl suspend
        ;;
    *""*)
        systemctl reboot
        ;;
    *"󰤆"*)
        systemctl poweroff
        ;;
    *"󰤁"*)
        systemctl hibernate
        ;;
    *"󱅞"*)
        ~/.local/bin/lock.sh
        ;;
    *"󰩈"*)
        ~/.local/bin/exit.sh
        ;;
esac
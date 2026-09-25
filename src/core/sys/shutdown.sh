#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -p, --position LOCATION  Set the rofi window position
  -v, --vertical           Use the vertical shutdown theme
  -h, --help               Show this help message
EOF
}

POSITION_ARGS=()
THEME="shutdown.rasi"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--position)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        printf 'Error: %s requires a location.\n' "$1" >&2
        usage >&2
        exit 2
      fi
      POSITION_ARGS=(-location "$2")
      shift 2
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
      printf 'Error: unknown option: %s\n' "$1" >&2
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
chosen=$(printf '%s\n' "$options" | rofi -dmenu -p "Shutdown" "${POSITION_ARGS[@]}" -i -theme "$THEME")

# List action
case $chosen in 
    *"󰒲"*) systemctl suspend ;;
    *""*) systemctl reboot ;;
    *"󰤆"*) systemctl poweroff ;;
    *"󰤁"*) systemctl hibernate ;;
    *"󱅞"*) ~/.local/bin/lock.sh ;;
    *"󰩈"*) ~/.local/bin/exit.sh ;;
esac
#!/usr/bin/env bash

# This script manages the clipboard history using cliphist and rofi.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: clipboard_menu.sh [OPTION]
Manage clipboard history with cliphist and rofi.

Options:
    --wipe              Clear all clipboard history
    -h, --help          Show this help message
EOF
        exit 0
fi

# Clear clipboard by adding argument "wipe"
if [ "$1" = "--wipe" ]; then
    cliphist wipe
    notify-send "Clipboard" "Clear All History" -t 2000
    exit 0
fi

# Check if wl-paste is running, if not, start it with cliphist store
if ! pgrep -x "wl-paste" > /dev/null; then
    wl-paste --type text --watch cliphist store &
    wl-paste --type image --watch cliphist store &
fi

# Show clipboard history using rofi and allow user to select an entry
result=$(cliphist list | rofi -dmenu \
    -p "󰅌 Clipboard" \
    -theme-str "window { width: 50%; } \
                listview { lines: 10; }")

if [ ! -z "$result" ]; then
    echo "$result" | cliphist decode | wl-copy
    notify-send "Clipboard" "Copied to clipboard" -t 2000
fi

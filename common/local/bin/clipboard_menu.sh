#!/bin/bash

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

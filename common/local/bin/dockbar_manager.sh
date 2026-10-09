#!/usr/bin/env bash

DOCKBAR_BIN="$HOME/.local/bin/dockbar"
DOCKBAR_DIR="$HOME/.config/waybar/dockbar"

if [ ! -L "$DOCKBAR_BIN" ]; then
    if [ ! -f "/usr/bin/waybar" ]; then
        echo "Waybar binary not found in /usr/bin/waybar. Please install Waybar first."
        notify-send "Dockbar" "Waybar binary not found in /usr/bin/waybar. Please install Waybar first."
        exit 1
    fi

    mkdir -p "$HOME/.local/bin"
    ln -s /usr/bin/waybar "$DOCKBAR_BIN"
fi

# Reload the dockbar
if [[ $1 == "--reload" ]]; then
    pkill -x "dockbar"
    "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
    disown
    exit 0
fi

# Toggle the dockbar
if [[ $1 == "--toggle" ]]; then
    if pgrep -x "dockbar" >/dev/null; then
        pkill -x "dockbar"
    else
        "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
        disown
    fi
    exit 0
fi
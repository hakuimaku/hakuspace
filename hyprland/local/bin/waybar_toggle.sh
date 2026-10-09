#!/bin/bash

DIR_LEFT="$HOME/.config/waybar/waybarleft"
DIR_TOP="$HOME/.config/waybar/waybartop"
STATE_FILE="/tmp/waybar_current_mode"

if [ $1 == "--reset" ]; then
    rm "$STATE_FILE"
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "top" > "$STATE_FILE"
fi

CURRENT_STATE=$(cat "$STATE_FILE")

killall waybar
while pgrep -x waybar >/dev/null; do sleep 0.1; done

if [ "$CURRENT_STATE" == "top" ]; then
    # Link configuration Waybar Left to root (waybar/) and run
    ln -sf "$DIR_LEFT/config" "$HOME/.config/waybar/config"
    ln -sf "$DIR_LEFT/style.css" "$HOME/.config/waybar/style.css"
    waybar &
    echo "left" > "$STATE_FILE"
else
    # Link configuration Waybar Top to root and run
    ln -sf "$DIR_TOP/config" "$HOME/.config/waybar/config"
    ln -sf "$DIR_TOP/style.css" "$HOME/.config/waybar/style.css"
    waybar & 
    echo "top" > "$STATE_FILE"
fi
#!/bin/bash

DIR_LEFT="$HOME/.config/waybar/waybarleft"
DIR_TOP="$HOME/.config/waybar/waybartop"
STATE_FILE="/tmp/waybar_current_mode"
CURRENT_STATE=$(cat "$STATE_FILE")

# Reset Waybar mode to top by removing the state file
if [ $1 == "--reset" ]; then
    echo "Remove state file ($STATE_FILE) to reset Waybar mode to top"
    sudo rm "$STATE_FILE"
fi

# Create the state file if it doesn't exist and set the default mode to top
if [ ! -f "$STATE_FILE" ]; then
    echo "top" > "$STATE_FILE"
fi

# Start Waybar with the current mode
if [ $1 == "--start" ]; then
    if [ "$CURRENT_STATE" == "top" ]; then
        ln -sf "$DIR_TOP/config" "$HOME/.config/waybar/config"
        ln -sf "$DIR_TOP/style.css" "$HOME/.config/waybar/style.css"
    else
        ln -sf "$DIR_LEFT/config" "$HOME/.config/waybar/config"
        ln -sf "$DIR_LEFT/style.css" "$HOME/.config/waybar/style.css"
    fi
    waybar &
    exit 0
fi

# Toggle Waybar mode between top and left
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
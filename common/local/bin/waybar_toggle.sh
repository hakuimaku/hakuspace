#!/bin/bash

DIR_LEFT="$HOME/.config/waybar/waybarleft"
DIR_TOP="$HOME/.config/waybar/waybartop"
STATE_FILE="/tmp/waybar_current_mode"
CURRENT_STATE=$(cat "$STATE_FILE")

link_top() {
    ln -sf "$DIR_TOP/config" "$HOME/.config/waybar/config"
    ln -sf "$DIR_TOP/style.css" "$HOME/.config/waybar/style.css"
}

link_left() {
    ln -sf "$DIR_LEFT/config" "$HOME/.config/waybar/config"
    ln -sf "$DIR_LEFT/style.css" "$HOME/.config/waybar/style.css"
}

run_waybar() {
    if [ "$CURRENT_STATE" == "top" ]; then
        link_top
    elif [ "$CURRENT_STATE" == "left" ]; then
        link_left
    else
        notify-send "Waybar Toggle" "Error: Invalid state in $STATE_FILE"
        exit 1
    fi
    waybar &
}

# Create the state file if it doesn't exist and set the default mode to top
if [ ! -f "$STATE_FILE" ]; then
    echo "top" > "$STATE_FILE"
    CURRENT_STATE="top"
fi

# Check if there is no config or style file in the root
if [ ! -f "$HOME/.config/waybar/config" ] || [ ! -f "$HOME/.config/waybar/style.css" ]; then
    link_top
fi

# Check if Waybar is not running (for auto start)
if ! pgrep -x waybar >/dev/null; then
    run_waybar
    exit 0
fi


# Main logic to toggle Waybar mode between top and left
killall waybar

if [ "$CURRENT_STATE" == "top" ]; then
    echo "left" > "$STATE_FILE"
    CURRENT_STATE="left"
    run_waybar
else
    echo "top" > "$STATE_FILE"
    CURRENT_STATE="top"
    run_waybar
fi

# In Niri, kill cava underbar when changing waybar mode
if [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    if cat /tmp/cava_underbar_status 2>/dev/null | grep -q "1"; then
        ~/.local/bin/cava_manager.sh --toggle
    fi
fi
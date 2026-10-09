#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/rofi"
CONFIG_FILE="$CONFIG_DIR/config.rasi"

# Get available theme files (.rasi) except config.rasi
themes=$(find "$CONFIG_DIR" -maxdepth 1 -name "*.rasi" ! -name "config.rasi" -exec basename {} .rasi \;)

if [ -z "$themes" ]; then
    echo "No theme files found in $CONFIG_DIR"
    notify-send "Rofi Theme Switcher" "No theme files found in $CONFIG_DIR"
    exit 1
fi

# Select theme using rofi
selected_theme=$(echo "$themes" | rofi -dmenu -p "Select Theme:" -theme-str 'window
{
    width: 30%;
    height: 50%;
}')

# Update @theme line in config.rasi if selection is not empty
if [ -n "$selected_theme" ]; then
    sed -i -E "s|@theme \".*\"|@theme \"$selected_theme\"|" "$CONFIG_FILE"
fi
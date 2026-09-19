#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/rofi"
CONFIG_FILE="$CONFIG_DIR/config.rasi"

STATE_DIR="$HOME/.local/state/hakuspace"
STATE_FILE="$STATE_DIR/rofi-theme.rasi"

THEME_DIR="$CONFIG_DIR/themes"
USER_THEME_DIR="$HOME/hakucfg/config/rofi"

# Check and build available theme list
themes_default=""
themes_user=""

if [ -d "$THEME_DIR" ]; then
    themes_default=$(find "$THEME_DIR" -maxdepth 1 -name "*.rasi" ! -name "config.rasi" -exec basename {} .rasi \;)
fi

if [ -d "$USER_THEME_DIR" ]; then
    themes_user=$(find "$USER_THEME_DIR" -maxdepth 1 -name "*.rasi" -exec basename {} .rasi \;)
fi

# Merge list and remove duplicates
themes=$(printf "%s\n%s" "$themes_default" "$themes_user" | sed '/^$/d' | sort -u)

if [ -z "$themes" ]; then
    echo "No theme files found!"
    notify-send "Rofi Theme Switcher" "No theme files found in default or user directory."
    exit 1
fi

# Select theme using rofi
selected_theme=$(echo "$themes" | rofi -dmenu -p "Select Theme:" -theme-str 'mainbox { children: [ inputbar, content-area]; } window { width: 35%; height: 35%; }' -i)

# Link theme if selected and update config.rasi
if [ -n "$selected_theme" ]; then
    # Prioritize user custom theme over default if it exists in USER_THEME_DIR
    if [ -f "$USER_THEME_DIR/$selected_theme.rasi" ]; then
        ln -sf "$USER_THEME_DIR/$selected_theme.rasi" "$CONFIG_DIR/$selected_theme.rasi"
    fi

    # Update @theme line in config.rasi
    if [ -f "$CONFIG_FILE" ]; then
        cat > "$STATE_FILE" <<EOF
@theme "$selected_theme"
EOF
    else
        notify-send "Rofi Theme Switcher" "Config file not found: $STATE_FILE"
    fi
fi
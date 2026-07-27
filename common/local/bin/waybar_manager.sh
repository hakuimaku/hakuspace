#!/usr/bin/env bash

# Manage Waybar modes via symlinks and Rofi selection.

WAYBAR_DIR="$HOME/.config/waybar"
STATE_FILE="$HOME/.local/state/haku_theme/waybar_current_mode"
CURRENT_STATE="top"
MODES=("top" "left" "coredge" "minimal")

# Init state file if missing
if [[ -f "$STATE_FILE" ]]; then
    CURRENT_STATE=$(cat "$STATE_FILE")
else
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "top" > "$STATE_FILE"
fi

# Link selected mode files to main config directory
link_mode() {
    local mode="$1"
    local target_dir="$WAYBAR_DIR/$mode"

    if [[ ! -d "$target_dir" ]]; then
        notify-send "Waybar Error" "Mode directory not found: $target_dir"
        exit 1
    fi

    ln -sf "$target_dir/config" "$WAYBAR_DIR/config"
    ln -sf "$target_dir/style.css" "$WAYBAR_DIR/style.css"
    echo "$mode" > "$STATE_FILE"
    CURRENT_STATE="$mode"
}

# Start or restart Waybar
restart_waybar() {
    if [[ "$XDG_CURRENT_DESKTOP" == "niri" ]]; then
        if grep -q "1" /tmp/cava_underbar_status 2>/dev/null; then
            $HOME/.local/bin/cava_manager.sh --toggle
        fi
    fi

    if pgrep -x waybar >/dev/null; then
        pkill -x waybar
        sleep 0.2
    fi

    waybar &
}

# Handle --select argument via Rofi
if [[ "$1" == "--select" ]]; then
    choice=$(printf "%s\n" "${MODES[@]}" | rofi -dmenu -p "Waybar" -i -theme-str 'window {width: 25%; height: 40%;} entry { placeholder: " Select Mode"; }')
    [[ -z "$choice" ]] && exit 0

    if [[ "$choice" != "$CURRENT_STATE" ]]; then
        link_mode "$choice"
        restart_waybar
    fi
    exit 0
fi

# Ensure symlinks exist
if [[ ! -f "$WAYBAR_DIR/config" ]] || [[ ! -f "$WAYBAR_DIR/style.css" ]]; then
    link_mode "$CURRENT_STATE"
fi

# Auto-start Waybar if not running
if ! pgrep -x waybar >/dev/null; then
    waybar &
fi
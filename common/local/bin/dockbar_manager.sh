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

# Help message
if [[ $1 == "--help" ]]; then
    cat <<'EOF'
Usage: dockbar_manager.sh [OPTION]
Options:
  --reload          Reload the dockbar
  --toggle          Toggle the dockbar on/off
  --exclusive       Toggle exclusive mode in the dockbar configuration
  --icon-size       Change the icon size in the dockbar configuration
  --help            Display this help message
EOF
    exit 0
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

# Change the exclusive mode
if [[ $1 == "--exclusive" ]]; then
    if grep -q '"exclusive": true' "$DOCKBAR_DIR/config"; then
        sed -i 's/"exclusive": true/"exclusive": false/' "$DOCKBAR_DIR/config"
    else
        sed -i 's/"exclusive": false/"exclusive": true/' "$DOCKBAR_DIR/config"
    fi
    $HOME/.local/bin/dockbar_manager.sh --reload
    exit 0
fi

# Change icon size by rofi menu
if [[ $1 == "--icon-size" ]]; then
    current_size=$(grep -oP '"icon-size": \K\d+' "$DOCKBAR_DIR/config")
    new_size=$(rofi -dmenu -p "Icon size (current: $current_size):" <<< "$current_size" -theme-str 'window {width: 40%; height: 40%;}' -theme-str 'entry { placeholder: "Type new size"; }')
    if [[ -n "$new_size" && "$new_size" =~ ^[0-9]+$ ]]; then
        sed -i "s/\"icon-size\": $current_size/\"icon-size\": $new_size/" "$DOCKBAR_DIR/config"
        $HOME/.local/bin/dockbar_manager.sh --reload
    fi
    exit 0
fi
#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/haku_theme"
AUTOHIDE_STATE="$STATE_DIR/dockbar_autohide_state"
MANUAL_STATE="$STATE_DIR/dockbar_manual_state"

DOCKBAR_BIN="$HOME/.local/bin/dockbar"
DOCKBAR_DIR="$HOME/.config/waybar/dockbar"
AUTOHIDE_SCRIPT="$HOME/.local/bin/autohide-dock.py"

mkdir -p "$STATE_DIR"

# Ensure state files exist and contain valid values (0 or 1)
for state_file in "$AUTOHIDE_STATE" "$MANUAL_STATE"; do
    if [[ ! -f "$state_file" ]] || ! grep -qxE '0|1' "$state_file"; then
        echo "0" > "$state_file"
    fi
done

# Check dependencies
if [ ! -L "$DOCKBAR_BIN" ]; then
    if [ ! -f "/usr/bin/waybar" ]; then
        echo "Waybar binary not found in /usr/bin/waybar. Please install Waybar first."
        notify-send "Dockbar" "Waybar binary not found in /usr/bin/waybar. Please install Waybar first."
        exit 1
    fi
    mkdir -p "$HOME/.local/bin"
    ln -s /usr/bin/waybar "$DOCKBAR_BIN"
fi

# Display help message
if [[ $1 == "--help" ]]; then
    cat <<'EOF'
Usage: dockbar_manager.sh [OPTION]
Options:
    --startup         Restore previous state at boot (add to your autostart)
    --reload          Reload the dockbar
    --toggle          Toggle the dockbar on/off (Manual mode)
    --exclusive       Toggle exclusive mode in the dockbar configuration
    --icon-size       Change the icon size in the dockbar configuration
    --auto-hide       Toggle auto-hide mode
    --trigger-show    Internal use: Show dockbar (Triggered by Python)
    --trigger-hide    Internal use: Hide dockbar (Triggered by Python)
    --help            Display this help message
EOF
    exit 0
fi

# Startup (Restore previous state)
if [[ $1 == "--startup" ]]; then
    if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
        pkill -f "$AUTOHIDE_SCRIPT"
        "$AUTOHIDE_SCRIPT" &
    elif [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        if ! pgrep -x "dockbar" >/dev/null; then
            "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
            disown
        fi
    fi
    exit 0
fi

# Trigger from Python (Does not change state)
if [[ $1 == "--trigger-show" ]]; then
    if ! pgrep -x "dockbar" >/dev/null; then
        "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
        disown
    fi
    exit 0
fi

if [[ $1 == "--trigger-hide" ]]; then
    pkill -x "dockbar"
    exit 0
fi

# Reload the dockbar
if [[ $1 == "--reload" ]]; then
    pkill -x "dockbar"
    if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
        pkill -f "$AUTOHIDE_SCRIPT"
        "$AUTOHIDE_SCRIPT" &
    elif [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
        disown
    fi
    exit 0
fi

# Manual Toggle (Toggle the dockbar on/off)
if [[ $1 == "--toggle" ]]; then
    if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
        echo "0" > "$AUTOHIDE_STATE"
        pkill -f "$AUTOHIDE_SCRIPT"
        
        echo "1" > "$MANUAL_STATE"
        pkill -x "dockbar"
        "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
        disown
    else
        if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
            echo "0" > "$MANUAL_STATE"
            pkill -x "dockbar"
        else
            echo "1" > "$MANUAL_STATE"
            pkill -x "dockbar"
            "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
            disown
        fi
    fi
    exit 0
fi

# Exclusive Mode Toggle (Toggle exclusive mode in the dockbar configuration)
if [[ $1 == "--exclusive" ]]; then
    if grep -q '"exclusive": true' "$DOCKBAR_DIR/config"; then
        sed -i 's/"exclusive": true/"exclusive": false/' "$DOCKBAR_DIR/config"
    else
        sed -i 's/"exclusive": false/"exclusive": true/' "$DOCKBAR_DIR/config"
    fi
    $HOME/.local/bin/dockbar_manager.sh --reload
    exit 0
fi

# Change Icon Size (Change the icon size in the dockbar configuration)
if [[ $1 == "--icon-size" ]]; then
    current_size=$(grep -oP '"icon-size":\s*\K\d+' "$DOCKBAR_DIR/config" | head -n 1)
    [[ -z "$current_size" ]] && current_size=52

    new_size=$(rofi -dmenu -p "Icon size (current: $current_size):" <<< "$current_size" -theme-str 'window {width: 40%; height: 40%;}' -theme-str 'entry { placeholder: "Type new size"; }')
    
    if [[ -n "$new_size" && "$new_size" =~ ^[0-9]+$ ]]; then
        sed -i -E "s/\"icon-size\": *[0-9]+/\"icon-size\": $new_size/g" "$DOCKBAR_DIR/config"
        echo "Icon size updated to $new_size."
        
        sed -i -E "s/\"size\": *[0-9]+/\"size\": $new_size/g" "$DOCKBAR_DIR/config"
        echo "Pinned app icon sizes updated to $new_size."
        
        "$HOME/.local/bin/dockbar_manager.sh" --reload
    fi
    exit 0
fi

# Auto-hide Toggle
if [[ $1 == "--auto-hide" ]]; then
    if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
        echo "0" > "$AUTOHIDE_STATE"
        pkill -f "$AUTOHIDE_SCRIPT"
        
        if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
            if ! pgrep -x "dockbar" >/dev/null; then
                "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
                disown
            fi
        else
            pkill -x "dockbar"
        fi
    else
        echo "1" > "$AUTOHIDE_STATE"
        pkill -x "dockbar"
        pkill -f "$AUTOHIDE_SCRIPT"
        "$AUTOHIDE_SCRIPT" &
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information."
#!/usr/bin/env bash

# This script manages the state of the dockbar
# Toggle it on/off, reload it, toggle auto-hide, or restore the previous state at startup.

STATE_DIR="$HOME/.local/state/haku_theme"
AUTOHIDE_STATE="$STATE_DIR/dockbar_autohide_state"
MANUAL_STATE="$STATE_DIR/dockbar_manual_state"

DOCKBAR_BIN="$HOME/.local/bin/dockbar"
DOCKBAR_DIR="$HOME/.config/waybar/dockbar"
DOCKBAR_PIN_APPS="$HOME/hakuspace-control/dockbar_pin_apps"
AUTOHIDE_SCRIPT="$HOME/.local/bin/dockbar_autohide.py"

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
    # Note: Autohide script ONLY runs if Manual mode is ON
    if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
            pkill -f "$AUTOHIDE_SCRIPT"
            "$AUTOHIDE_SCRIPT" &
        else
            if ! pgrep -x "dockbar" >/dev/null; then
                "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
                disown
            fi
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
    pkill -f "$AUTOHIDE_SCRIPT"
    
    # Note: Reload respects the master switch (MANUAL_STATE)
    if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
            "$AUTOHIDE_SCRIPT" &
        else
            "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
            disown
        fi
    fi
    exit 0
fi

# Manual Toggle (Toggle the dockbar on/off)
# Master switch: Controls whether dockbar (and its autohide script) is allowed to run.
if [[ $1 == "--toggle" ]]; then
    if [[ $(cat "$MANUAL_STATE") == "0" ]]; then
        # Turn ON manual mode
        echo "1" > "$MANUAL_STATE"
        
        if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
            # If autohide is enabled, start the python script
            pkill -x "dockbar"
            pkill -f "$AUTOHIDE_SCRIPT"
            "$AUTOHIDE_SCRIPT" &
        else
            # If autohide is disabled, just show the static dockbar
            pkill -x "dockbar"
            "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
            disown
        fi
    else
        # Turn OFF manual mode
        echo "0" > "$MANUAL_STATE"
        pkill -x "dockbar"
        
        # If autohide is enabled, kill the python script too
        if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
            pkill -f "$AUTOHIDE_SCRIPT"
        fi
    fi
    exit 0
fi

# Exclusive Mode Toggle
if [[ $1 == "--exclusive" ]]; then
    if grep -q '"exclusive": true' "$DOCKBAR_DIR/config"; then
        sed -i 's/"exclusive": true/"exclusive": false/' "$DOCKBAR_DIR/config"
    else
        sed -i 's/"exclusive": false/"exclusive": true/' "$DOCKBAR_DIR/config"
    fi
    "$HOME/.local/bin/dockbar_manager.sh" --reload
    exit 0
fi

# Change Icon Size
if [[ $1 == "--icon-size" ]]; then
    current_size=$(grep -oP '"icon-size":\s*\K\d+' "$DOCKBAR_DIR/config" | head -n 1)
    [[ -z "$current_size" ]] && current_size=52

    new_size=$(rofi -dmenu -p "Icon size (current: $current_size):" <<< "$current_size" -theme-str 'window {width: 40%; height: 40%;}' -theme-str 'entry { placeholder: "Type new size"; }')
    
    if [[ -n "$new_size" && "$new_size" =~ ^[0-9]+$ ]]; then
        sed -i -E "s/\"icon-size\": *[0-9]+/\"icon-size\": $new_size/g" "$DOCKBAR_DIR/config"
        echo "Icon size updated to $new_size."
        
        if [[ -f "$DOCKBAR_PIN_APPS" ]]; then
            sed -i -E "s/\"size\": *[0-9]+/\"size\": $new_size/g" "$DOCKBAR_PIN_APPS"
            echo "Pinned app icon sizes updated to $new_size."
        fi
        
        "$HOME/.local/bin/dockbar_manager.sh" --reload
    fi
    exit 0
fi

# Auto-hide Toggle
# Sub-switch: Independent state, but action only takes effect if Manual mode is ON.
if [[ $1 == "--auto-hide" ]]; then
    if [[ $(cat "$AUTOHIDE_STATE") == "1" ]]; then
        # Turn OFF autohide
        echo "0" > "$AUTOHIDE_STATE"
        pkill -f "$AUTOHIDE_SCRIPT"
        
        # If manual mode is ON, fallback to static dockbar
        if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
            if ! pgrep -x "dockbar" >/dev/null; then
                "$DOCKBAR_BIN" -c "$DOCKBAR_DIR/config" -s "$DOCKBAR_DIR/style.css" >/dev/null 2>&1 &
                disown
            fi
        else
            pkill -x "dockbar"
        fi
    else
        # Turn ON autohide
        echo "1" > "$AUTOHIDE_STATE"
        
        # Only run the script if manual mode is ON
        if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
            pkill -x "dockbar"
            pkill -f "$AUTOHIDE_SCRIPT"
            "$AUTOHIDE_SCRIPT" &
        fi
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information."
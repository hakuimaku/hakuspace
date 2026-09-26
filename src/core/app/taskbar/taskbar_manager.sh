#!/usr/bin/env bash

# This script manages the state of the taskbar
# Toggle it on/off, reload it, or restore the previous state at startup.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

MANUAL_STATE="$STATE_DIR/taskbar_manual_state"

TASKBAR_REAL_DIR="$HOME/.config/waybar/taskbar"
TASKBAR_LINK_DIR="$HOME/.config/waybar"
TASKBAR_CONFIG="$TASKBAR_LINK_DIR/config-taskbar"
TASKBAR_STYLE="$TASKBAR_LINK_DIR/style-taskbar.css"

TASKBAR_PIN_APPS="$HOME/hakucfg/config/taskbar-pin-apps"
THEME_FILE="$THEME_ROOT/taskbar-theme"

mkdir -p "$STATE_DIR"

if [[ ! -f "$THEME_FILE" ]]; then
    echo "Warning: Taskbar theme file not found."
    notify-send "Taskbar" "Warning: Taskbar theme file not found."
fi

# Ensure state file exists and contain valid values (0 or 1)
if [[ ! -f "$MANUAL_STATE" ]] || ! grep -qxE '0|1' "$MANUAL_STATE"; then
    echo "0" > "$MANUAL_STATE"
fi

# Check dependencies
WAYBAR_BIN=$(command -v waybar)
TASKBAR_BIN="$HOME/.local/bin/taskbar"

if [[ -z "$WAYBAR_BIN" ]]; then
    echo "Waybar binary not found in PATH. Please install Waybar first."
    notify-send "Taskbar" "Waybar binary not found in PATH. Please install Waybar first."
    exit 1
fi

# Ensure symlink exists so we can run waybar as 'taskbar'
if [[ ! -L "$TASKBAR_BIN" || "$(readlink -f "$TASKBAR_BIN")" != "$(readlink -f "$WAYBAR_BIN")" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$WAYBAR_BIN" "$TASKBAR_BIN"
fi

ensure_symlink() {
    local target="$1" link="$2"
    if [[ ! -L "$link" || "$(readlink -f "$link")" != "$(readlink -f "$target")" ]]; then
        ln -sf "$target" "$link"
    fi
}
ensure_symlink "$TASKBAR_REAL_DIR/config" "$TASKBAR_CONFIG"
ensure_symlink "$TASKBAR_REAL_DIR/style.css" "$TASKBAR_STYLE"

launch_taskbar() {
    "$TASKBAR_BIN" -c "$TASKBAR_CONFIG" -s "$TASKBAR_STYLE" >/dev/null 2>&1 &
    disown
}

is_taskbar_running() {
    pgrep -x "taskbar" >/dev/null
}

kill_taskbar() {
    pkill -x "taskbar"
}

if [[ $1 == "--reload" ]]; then
    kill_taskbar
    
    if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        launch_taskbar
    fi
    exit 0
fi

# Display help message
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'INNEREOF'
Usage: taskbar_manager.sh [OPTION]
Manage the taskbar behavior.

Options:
    --startup           Restore previous state at boot
    --reload            Reload the taskbar
    --toggle            Toggle the taskbar on/off
    --app-name          Toggle app name format
    --icon-size         Change the icon size
    -h, --help          Show this help message
INNEREOF
    exit 0
fi

# Startup (Restore previous state)
if [[ $1 == "--startup" ]]; then
    if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        if ! is_taskbar_running; then
            launch_taskbar
        fi
    fi
    exit 0
fi

# Reload the taskbar
if [[ $1 == "--reload" ]]; then
    if [[ $(cat "$MANUAL_STATE") == "1" ]]; then
        reload_taskbar
    else
        kill_taskbar
    fi
    exit 0
fi

# Manual Toggle (Toggle the taskbar on/off)
if [[ $1 == "--toggle" ]]; then
    if [[ $(cat "$MANUAL_STATE") == "0" ]]; then
        echo "1" > "$MANUAL_STATE"
        kill_taskbar
        launch_taskbar
    else
        echo "0" > "$MANUAL_STATE"
        kill_taskbar
    fi
    exit 0
fi

# Format Toggle (App Name ON/OFF)
if [[ $1 == "--app-name" ]]; then
    if grep -qE '"format":\s*"\{icon\} \{name\}"' "$THEME_FILE"; then
        sed -i -E 's/"format":\s*"\{icon\} \{name\}"/"format": "{icon}"/' "$THEME_FILE"
        echo "Taskbar App Name disabled."
    else
        sed -i -E 's/"format":\s*"\{icon\}"/"format": "{icon} {name}"/' "$THEME_FILE"
        echo "Taskbar App Name enabled."
    fi
    "$0" --reload
    exit 0
fi

# Change Icon Size
if [[ $1 == "--icon-size" ]]; then
    current_size=$(grep -oP '"icon-size":\s*\K\d+' "$THEME_FILE" | head -n 1)
    [[ -z "$current_size" ]] && current_size=40

    new_size=$(rofi -dmenu -p "Icon size (current: $current_size):" <<< "$current_size" -theme-str 'window {width: 40%; height: 40%;}' -theme-str 'entry { placeholder: "Type new size"; }')
    
    if [[ -n "$new_size" && "$new_size" =~ ^[0-9]+$ ]]; then
        sed -i -E "s/\"icon-size\": *[0-9]+/\"icon-size\": $new_size/g" "$THEME_FILE"
        echo "Icon size updated to $new_size."
        
        if [[ -f "$TASKBAR_PIN_APPS" ]]; then
            sed -i -E "s/\"size\": *[0-9]+/\"size\": $new_size/g" "$TASKBAR_PIN_APPS"
            echo "Pinned app icon sizes updated to $new_size."
        fi
        
        "$HOME/.local/bin/taskbar_manager.sh" --reload
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information."
#!/usr/bin/env bash

# This script manages the state of rounded screen
# Toggle it on/off, reload it, or restore the previous state at startup.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"
ROUNDED_SCREEN_STATE="$STATE_DIR/rounded_screen_state"
ROUNDED_SCREEN_DYNAMIC_STATE="$STATE_DIR/rounded_screen_dynamic_state"

ROUNDED_SCREEN_BIN="$HOME/.local/bin/rounded_screen.py"
CONF_FILE="$HOME/hakucfg/config/rounded-screen.conf"

mkdir -p "$STATE_DIR"

# Ensure state file exists and contains valid values (0 or 1)
if [[ ! -f "$ROUNDED_SCREEN_STATE" ]] || ! grep -qxE '0|1' "$ROUNDED_SCREEN_STATE"; then
    echo "0" > "$ROUNDED_SCREEN_STATE"
fi

if [[ ! -f "$ROUNDED_SCREEN_DYNAMIC_STATE" ]] || ! grep -qxE '0|1' "$ROUNDED_SCREEN_DYNAMIC_STATE"; then
    echo "1" > "$ROUNDED_SCREEN_DYNAMIC_STATE"
fi

launch_app() {
    python3 "$ROUNDED_SCREEN_BIN" &
}

kill_app() {
    pkill -f "$ROUNDED_SCREEN_BIN"
}

# Display help message
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: rounded_screen_manager.sh [OPTION]
Manage rounded screen app.

Options:
    --startup           Restore previous state at boot (called by WMs)
    --toggle            Toggle rounded screen on/off
    --toggle-dynamic    Toggle rounded screen dynamic position (affected by panels)
    --reload            Reload rounded screen
    -h, --help          Show this help message
EOF
    exit 0
fi

# Toggle dynamic mode
if [[ $1 == "--toggle-dynamic" ]]; then
    if [[ $(cat "$ROUNDED_SCREEN_DYNAMIC_STATE") == "1" ]]; then
        echo "0" > "$ROUNDED_SCREEN_DYNAMIC_STATE"
        if [[ -f "$CONF_FILE" ]]; then
            sed -i 's/^[#]*\s*dynamic_position.*/dynamic_position = False/g' "$CONF_FILE"
        fi
        echo "Rounded screen dynamic position disabled"
    else
        echo "1" > "$ROUNDED_SCREEN_DYNAMIC_STATE"
        if [[ -f "$CONF_FILE" ]]; then
            sed -i 's/^[#]*\s*dynamic_position.*/dynamic_position = True/g' "$CONF_FILE"
        fi
        echo "Rounded screen dynamic position enabled"
    fi
    if pgrep -f "$ROUNDED_SCREEN_BIN" >/dev/null; then
        kill_app
        launch_app
    fi
    exit 0
fi

# Toggle rounded screen on/off
if [[ $1 == "--toggle" ]]; then
    if [[ $(cat "$ROUNDED_SCREEN_STATE") == "1" ]]; then
        echo "0" > "$ROUNDED_SCREEN_STATE"
        kill_app
        echo "Rounded screen disabled"
    else
        echo "1" > "$ROUNDED_SCREEN_STATE"
        launch_app
        echo "Rounded screen enabled"
    fi
    exit 0
fi

# Reload rounded screen if running
if [[ $1 == "--reload" ]]; then
    if pgrep -f "$ROUNDED_SCREEN_BIN" >/dev/null; then
        kill_app
        launch_app
        echo "Rounded screen reloaded"
    else
        echo "Rounded screen is not running. Use --toggle to enable it."
    fi
    exit 0
fi

# Auto-start rounded screen if enabled (usually called by WM with --startup)
if [[ "${1:-}" == "--startup" || -z "${1:-}" ]]; then
    if [[ $(cat "$ROUNDED_SCREEN_STATE") == "1" ]]; then
        if ! pgrep -f "$ROUNDED_SCREEN_BIN" >/dev/null; then
            launch_app
        fi
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information."


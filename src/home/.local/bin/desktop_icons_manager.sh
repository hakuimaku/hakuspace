#!/usr/bin/env bash

# This script manages the state of desktop icons
# Toggle them on/off, reload them, or restore the previous state at startup.

STATE_DIR="$HOME/.local/state/haku_theme"
DESKTOP_ICONS_STATE="$STATE_DIR/desktop_icons_state"

DESKTOP_MANAGER_BIN="$HOME/.local/bin/desktop_icons.py"

mkdir -p "$STATE_DIR"

# Ensure state file exists and contains valid values (0 or 1)
if [[ ! -f "$DESKTOP_ICONS_STATE" ]] || ! grep -qxE '0|1' "$DESKTOP_ICONS_STATE"; then
    echo "0" > "$DESKTOP_ICONS_STATE"
fi

launch_desktop_icons() {
    export GI_TYPELIB_PATH="/run/current-system/sw/lib/girepository-1.0:$GI_TYPELIB_PATH"
    python3 "$DESKTOP_MANAGER_BIN" &
}

kill_desktop_icons() {
    pkill -f "$DESKTOP_MANAGER_BIN"
}

# Display help message
if [[ $1 == "--help" ]]; then
    cat <<'EOF'
Usage: desktop_manager.sh [OPTION]
Options:
    --startup         Restore previous state at boot (add to your autostart)
    --toggle          Toggle desktop icons on/off
    --reload          Reload desktop icons
    --help            Display this help message
EOF
    exit 0
fi

# Toggle desktop icons on/off
if [[ $1 == "--toggle" ]]; then
    if [[ $(cat "$DESKTOP_ICONS_STATE") == "1" ]]; then
        echo "0" > "$DESKTOP_ICONS_STATE"
        kill_desktop_icons
        echo "Desktop icons disabled"
    else
        echo "1" > "$DESKTOP_ICONS_STATE"
        launch_desktop_icons
        echo "Desktop icons enabled"
    fi
    exit 0
fi

# Reload desktop icons if running
if [[ $1 == "--reload" ]]; then
    if pgrep -f "$DESKTOP_MANAGER_BIN" >/dev/null; then
        kill_desktop_icons
        launch_desktop_icons
        echo "Desktop icons reloaded"
    else
        echo "Desktop icons are not running. Use --toggle to enable them."
    fi
    exit 0
fi

# Auto-start desktop icons if enabled
if [[ $(cat "$DESKTOP_ICONS_STATE") == "1" ]]; then
    if ! pgrep -f "$DESKTOP_MANAGER_BIN" >/dev/null; then
        launch_desktop_icons
    fi
fi

echo "Invalid option. Use --help for usage information."
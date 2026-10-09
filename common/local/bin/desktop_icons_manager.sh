#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/haku_theme"
DESKTOP_ICONS_STATE="$STATE_DIR/desktop_icons_state"

DESKTOP_MANAGER_BIN="$HOME/.local/bin/desktop_icons.py"

mkdir -p "$STATE_DIR"

# Ensure state file exists and contains valid values (0 or 1)
if [[ ! -f "$DESKTOP_ICONS_STATE" ]] || ! grep -qxE '0|1' "$DESKTOP_ICONS_STATE"; then
    echo "0" > "$DESKTOP_ICONS_STATE"
fi

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
        pkill -f "$DESKTOP_MANAGER_BIN"
        echo "Desktop icons disabled"
    else
        echo "1" > "$DESKTOP_ICONS_STATE"
        "$DESKTOP_MANAGER_BIN" &
        echo "Desktop icons enabled"
    fi
    exit 0
fi

# Reload desktop icons if running
if [[ $1 == "--reload" ]]; then
    if pgrep -f "$DESKTOP_MANAGER_BIN" >/dev/null; then
        pkill -f "$DESKTOP_MANAGER_BIN"
        "$DESKTOP_MANAGER_BIN" &
        echo "Desktop icons reloaded"
    else
        echo "Desktop icons are not running. Use --toggle to enable them."
    fi
    exit 0
fi

# Auto-start desktop icons if enabled
if [[ $(cat "$DESKTOP_ICONS_STATE") == "1" ]]; then
    if ! pgrep -f "$DESKTOP_MANAGER_BIN" >/dev/null; then
        "$DESKTOP_MANAGER_BIN" &
        disown
    fi
fi

echo "Invalid option. Use --help for usage information."
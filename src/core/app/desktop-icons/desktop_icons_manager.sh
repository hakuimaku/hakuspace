#!/usr/bin/env bash

# This script manages the state of desktop icons
# Toggle them on/off, reload them, or restore the previous state at startup.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Load canonical paths without initializing state during status queries.
if [[ -f "$SCRIPT_DIR/haku_state.sh" ]]; then
    source "$SCRIPT_DIR/haku_state.sh"
else
    source "$SCRIPT_DIR/../../lib/haku_state.sh"
fi
if [[ "${1:-}" == "--status" ]]; then
    if [[ "$(cat "$(haku_state_path desktop.icons.enabled)" 2>/dev/null)" == "1" ]]; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
    exit 0
fi

source "$SCRIPT_DIR/haku_theme.sh"
source "$SCRIPT_DIR/haku_backend_lib.sh"
DESKTOP_ICONS_STATE="$(haku_state_path desktop.icons.enabled)"

DESKTOP_MANAGER_BIN="$HOME/.local/bin/desktop_icons.py"

mkdir -p "$STATE_DIR"

# Ensure state file exists and contains valid values (0 or 1)
if [[ ! -f "$DESKTOP_ICONS_STATE" ]] || ! grep -qxE '0|1' "$DESKTOP_ICONS_STATE"; then
    echo "0" > "$DESKTOP_ICONS_STATE"
fi

launch_desktop_icons() {
    python3 "$DESKTOP_MANAGER_BIN" &
}

kill_desktop_icons() {
    pkill -f "$DESKTOP_MANAGER_BIN"
}

# Display help message
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: desktop_icons_manager.sh [OPTION]
Manage desktop icons.

Options:
    --startup           Restore previous state at boot
    --toggle            Toggle desktop icons on/off
    --status            Print enabled or disabled
    --reload            Reload desktop icons
    -h, --help          Show this help message
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
if [[ "${1:-}" == "--startup" || -z "${1:-}" ]]; then
    if [[ $(cat "$DESKTOP_ICONS_STATE") == "1" ]]; then
        if ! pgrep -f "$DESKTOP_MANAGER_BIN" >/dev/null; then
            launch_desktop_icons
        fi
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information."

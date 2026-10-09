#!/usr/bin/env bash

# This script manages the state of edge trigger
# Toggle it on/off, reload it, or restore the previous state at startup.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"
EDGE_TRIGGER_STATE="$STATE_DIR/edge_trigger_state"

EDGE_TRIGGER_BIN="$HOME/.local/bin/edge_trigger.py"

mkdir -p "$STATE_DIR"

# Ensure state file exists and contains valid values (0 or 1)
if [[ ! -f "$EDGE_TRIGGER_STATE" ]] || ! grep -qxE '0|1' "$EDGE_TRIGGER_STATE"; then
    echo "0" > "$EDGE_TRIGGER_STATE"
fi

launch_app() {
    python3 "$EDGE_TRIGGER_BIN" &
}

kill_app() {
    pkill -f "$EDGE_TRIGGER_BIN"
}

# Display help message
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: edge_trigger_manager.sh [OPTION]
Manage edge trigger app.

Options:
    --startup           Restore previous state at boot (called by WMs)
    --toggle            Toggle edge trigger on/off
    --reload            Reload edge trigger
    -h, --help          Show this help message
EOF
    exit 0
fi

# Toggle edge trigger on/off
if [[ $1 == "--toggle" ]]; then
    if [[ $(cat "$EDGE_TRIGGER_STATE") == "1" ]]; then
        echo "0" > "$EDGE_TRIGGER_STATE"
        kill_app
        echo "Edge trigger disabled"
    else
        echo "1" > "$EDGE_TRIGGER_STATE"
        launch_app
        echo "Edge trigger enabled"
    fi
    exit 0
fi

# Reload edge trigger if running
if [[ $1 == "--reload" ]]; then
    if pgrep -f "$EDGE_TRIGGER_BIN" >/dev/null; then
        kill_app
        launch_app
        echo "Edge trigger reloaded"
    else
        echo "Edge trigger is not running. Use --toggle to enable it."
    fi
    exit 0
fi

# Auto-start edge trigger if enabled (usually called by WM with --startup)
if [[ "${1:-}" == "--startup" || -z "${1:-}" ]]; then
    if [[ $(cat "$EDGE_TRIGGER_STATE") == "1" ]]; then
        if ! pgrep -f "$EDGE_TRIGGER_BIN" >/dev/null; then
            launch_app
        fi
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information."

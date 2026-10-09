#!/usr/bin/env bash

# Library for Quickshell backend management

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/haku_theme.sh"
elif [[ -f "$SCRIPT_DIR/../lib/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/../lib/haku_theme.sh"
else
    source "$HOME/.local/bin/haku_theme.sh"
fi

BACKEND_STATE_FILE="$STATE_DIR/shell_backend"
QS_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace"

QS_BACKEND_NAME="hikai"

# Initialize state file if it doesn't exist
if [[ ! -f "$BACKEND_STATE_FILE" ]] || ! grep -qxE "classic|$QS_BACKEND_NAME" "$BACKEND_STATE_FILE"; then
    echo "classic" > "$BACKEND_STATE_FILE"
fi

# Get current backend
haku_backend_get() {
    cat "$BACKEND_STATE_FILE" 2>/dev/null || echo "classic"
}

# Check if backend matches argument
haku_backend_is() {
    local target="$1"
    [[ "$(haku_backend_get)" == "$target" ]]
}

# Unified check for quickshell mode
haku_qs_mode() {
    [[ "$(haku_backend_get)" == "$QS_BACKEND_NAME" ]]
}

# Check if quickshell is running
haku_qs_alive() {
    pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1
}

# Get runtime dir
haku_runtime_dir() {
    mkdir -p "$QS_RUNTIME_DIR"
    echo "$QS_RUNTIME_DIR"
}

# Call quickshell IPC
haku_qs_ipc() {
    local target="$1"
    local fn="$2"
    shift 2
    
    mkdir -p "$QS_RUNTIME_DIR"
    
    # We use quickshell's IPC
    if ! qs -c hakuspace ipc call "$target" "$fn" "$@" 2>>"$QS_RUNTIME_DIR/qs.log"; then
        echo "Error calling quickshell IPC: $target $fn" >> "$QS_RUNTIME_DIR/qs.log"
        return 1
    fi
    return 0
}

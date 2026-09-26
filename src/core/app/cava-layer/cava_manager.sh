#!/usr/bin/env bash

# This script is a simple wrapper around cava-layer.py to manage its lifecycle (start/stop/toggle)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

SCRIPT_PATH="${CAVA_LAYER_PATH:-$HOME/.local/bin/cava_layer.py}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="/tmp/cava-layer.pid"
LOGFILE="/tmp/cava-layer.log"

TOP_STATE_FILE="$STATE_DIR/cava_top_state"
DYNAMIC_STATE_FILE="$STATE_DIR/cava_dynamic_state"
 
log() { echo "[cava-layer-toggle] $*"; }
err() { echo "[cava-layer-toggle] $*" >&2; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: cava_manager.sh [COMMAND] [OPTION]
Manage the cava layer process.

Commands:
    start               Start the cava layer
    stop                Stop the cava layer
    toggle              Toggle the cava layer
    reload              Live-reload font/colors from the kitty config
                        (no restart, no interruption to cava itself)
    -t, --top           Toggle the top mode (saves state and restarts)
    -d, --toggle-dynamic Toggle dynamic position (affected by panels)
    -c, --color-switch  Toggle foreground color between black and white

Options:
    -p, --config PATH       Forward configuration to cava_layer.py
    -H, --height VALUE      Forward layer height to cava_layer.py
    -F, --font-size N       Forward font size to cava_layer.py (default: 5)
    -n, --app-name NAME     Forward application name to cava_layer.py
    -h, --help              Show this help message
EOF
        exit 0
fi
 
check_dependencies() {
    local missing=()
 
    command -v python3 >/dev/null 2>&1 || missing+=("python3")
    command -v cava    >/dev/null 2>&1 || missing+=("cava")
 
    if [ ! -f "$SCRIPT_PATH" ]; then
        missing+=("cava-layer.py not found at $SCRIPT_PATH (set CAVA_LAYER_PATH to override)")
    fi
 
    # PyGObject itself
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import gi" >/dev/null 2>&1 || missing+=("python3-gi (PyGObject)")
 
        # GtkLayerShell typelib
        python3 -c "
import gi
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import GtkLayerShell
" >/dev/null 2>&1 || missing+=("gtk-layer-shell (GtkLayerShell GObject Introspection typelib)")
 
        # Vte typelib
        python3 -c "
import gi
gi.require_version('Vte', '2.91')
from gi.repository import Vte
" >/dev/null 2>&1 || missing+=("vte3 (Vte-2.91 GObject Introspection typelib)")
    fi
 
    if [ "${#missing[@]}" -ne 0 ]; then
        err "Missing dependencies:"
        for m in "${missing[@]}"; do
            err "  - $m"
        done
        exit 1
    fi
}
 
is_running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
}
 
start() {
    if is_running; then
        log "Already running (pid=$(cat "$PIDFILE"))."
        return 0
    fi
 
    check_dependencies
 
    local top_flag=""
    if [[ "$(cat "$TOP_STATE_FILE" 2>/dev/null || echo "0")" == "1" ]]; then
        top_flag="--top"
    fi

    local dynamic_flag=""
    if [[ "$(cat "$DYNAMIC_STATE_FILE" 2>/dev/null || echo "0")" == "1" ]]; then
        dynamic_flag="--dynamic"
    fi

    log "Starting: python3 $SCRIPT_PATH $top_flag $dynamic_flag $*"
    nohup python3 "$SCRIPT_PATH" $top_flag $dynamic_flag "$@" >"$LOGFILE" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    echo "$pid" > "$PIDFILE"
 
    sleep 0.3
    if ! kill -0 "$pid" 2>/dev/null; then
        err "cava-layer exited immediately. Last log lines:"
        tail -n 20 "$LOGFILE" >&2 2>/dev/null
        rm -f "$PIDFILE"
        exit 1
    fi
 
    log "Started (pid=$pid). Log: $LOGFILE"
}
 
stop() {
    if ! is_running; then
        log "Not running."
        rm -f "$PIDFILE"
        return 0
    fi
 
    local pid
    pid="$(cat "$PIDFILE")"
    log "Stopping (pid=$pid)..."
    kill "$pid" 2>/dev/null
 
    for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
 
    if kill -0 "$pid" 2>/dev/null; then
        err "Process didn't exit gracefully, force killing."
        kill -9 "$pid" 2>/dev/null
    fi
 
    rm -f "$PIDFILE"
    log "Stopped."
}
 
toggle() {
    if is_running; then
        stop
    else
        start "$@"
    fi
}

toggle_top() {
    mkdir -p "$STATE_DIR"
    local current_state=$(cat "$TOP_STATE_FILE" 2>/dev/null || echo "0")
    if [[ "$current_state" == "1" ]]; then
        echo "0" > "$TOP_STATE_FILE"
        log "Top mode disabled."
    else
        echo "1" > "$TOP_STATE_FILE"
        log "Top mode enabled."
    fi
    if is_running; then
        stop
        start
    fi
}

toggle_dynamic() {
    mkdir -p "$STATE_DIR"
    local current_state=$(cat "$DYNAMIC_STATE_FILE" 2>/dev/null || echo "0")
    if [[ "$current_state" == "1" ]]; then
        echo "0" > "$DYNAMIC_STATE_FILE"
        log "Dynamic mode disabled."
    else
        echo "1" > "$DYNAMIC_STATE_FILE"
        log "Dynamic mode enabled."
    fi
    if is_running; then
        stop
        start
    fi
}

toggle_color() {
    mkdir -p "$STATE_DIR"
    local COLOR_STATE_FILE="$STATE_DIR/cava_color_state"
    local CAVA_CONFIG="$HOME/hakucfg/config/cava-layer"

    if [[ ! -f "$CAVA_CONFIG" ]]; then
        err "Cava config file not found at $CAVA_CONFIG"
        return 1
    fi

    if grep -qE '^foreground\s*=\s*white' "$CAVA_CONFIG"; then
        sed -i -E 's/^foreground\s*=\s*white/foreground = black/' "$CAVA_CONFIG"
        echo "0" > "$COLOR_STATE_FILE"
        log "Cava color changed to black."
    elif grep -qE '^foreground\s*=\s*black' "$CAVA_CONFIG"; then
        sed -i -E 's/^foreground\s*=\s*black/foreground = white/' "$CAVA_CONFIG"
        echo "1" > "$COLOR_STATE_FILE"
        log "Cava color changed to white."
    else
        # Fallback if neither is active (e.g., commented out)
        sed -i -E 's/^#*\s*foreground\s*=\s*black/foreground = white/' "$CAVA_CONFIG"
        echo "1" > "$COLOR_STATE_FILE"
        log "Cava color forced to white."
    fi

    if is_running; then
        stop
        start
    fi
}

reload() {
    if ! is_running; then
        log "Not running; nothing to reload."
        return 0
    fi

    local pid
    pid="$(cat "$PIDFILE")"
    if kill -USR1 "$pid" 2>/dev/null; then
        log "Sent reload signal (pid=$pid)."
    else
        err "Failed to signal pid=$pid."
        return 1
    fi
}
 
case "${1:-}" in
    start)
        shift
        start "$@"
        ;;
    stop)
        stop
        ;;
    toggle)
        shift
        toggle "$@"
        ;;
    reload)
        reload
        ;;
    -t|--top)
        toggle_top
        ;;
    -d|--toggle-dynamic)
        toggle_dynamic
        ;;
    -c|--color-switch)
        toggle_color
        ;;
    *)
        # No explicit subcommand: treat everything (including -p/-H/-F flags,
        # or nothing at all) as arguments to a plain toggle.
        toggle "$@"
        ;;
esac
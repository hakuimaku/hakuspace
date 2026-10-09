#!/usr/bin/env bash

# This script is a simple wrapper around cava-layer.py to manage its lifecycle (start/stop/toggle)
 
SCRIPT_PATH="${CAVA_LAYER_PATH:-$HOME/.local/bin/cava_layer.py}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="/tmp/cava-layer.pid"
LOGFILE="/tmp/cava-layer.log"
 
log() { echo "[cava-layer-toggle] $*"; }
err() { echo "[cava-layer-toggle] $*" >&2; }
 
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
        err ""
        err "Install hints:"
        err "  Arch/Hyprland: sudo pacman -S cava python-gobject gtk-layer-shell vte3"
        err "  Debian/Ubuntu: sudo apt install cava python3-gi gir1.2-gtklayershell-0.1 gir1.2-vte-2.91"
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
 
    log "Starting: python3 $SCRIPT_PATH $*"
    nohup python3 "$SCRIPT_PATH" "$@" >"$LOGFILE" 2>&1 &
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
    *)
        # No explicit subcommand: treat everything (including -p/-H/-F flags,
        # or nothing at all) as arguments to a plain toggle.
        toggle "$@"
        ;;
esac

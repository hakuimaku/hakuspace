#!/usr/bin/env bash

# This script is a simple wrapper around cava-layer.py to manage its lifecycle (start/stop/toggle)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Load canonical paths without initializing state during status queries.
if [[ -f "$SCRIPT_DIR/haku_state.sh" ]]; then
    source "$SCRIPT_DIR/haku_state.sh"
else
    source "$SCRIPT_DIR/../../lib/haku_state.sh"
fi
if [[ "${1:-}" == "--status" || "${1:-}" == "status" ]]; then
    _backend="$(cat "$(haku_state_path shell.backend)" 2>/dev/null || echo "classic")"
    if [[ "$_backend" == "hikai" ]]; then
        if [[ "$(cat "$(haku_state_path cava.enabled)" 2>/dev/null || echo "0")" == "1" ]]; then
            printf 'enabled\n'
        else
            printf 'disabled\n'
        fi
    elif [[ -f "${CAVA_PIDFILE:-/tmp/cava-layer.pid}" ]] && kill -0 "$(cat "${CAVA_PIDFILE:-/tmp/cava-layer.pid}")" 2>/dev/null; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
    exit 0
fi
if [[ -f "$SCRIPT_DIR/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/haku_theme.sh"
elif [[ -f "$SCRIPT_DIR/../../lib/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/../../lib/haku_theme.sh"
elif [[ -f "$HOME/.local/bin/haku_theme.sh" ]]; then
    source "$HOME/.local/bin/haku_theme.sh"
fi

if [[ -f "$SCRIPT_DIR/haku_backend_lib.sh" ]]; then
    source "$SCRIPT_DIR/haku_backend_lib.sh"
elif [[ -f "$SCRIPT_DIR/../../lib/haku_backend_lib.sh" ]]; then
    source "$SCRIPT_DIR/../../lib/haku_backend_lib.sh"
elif [[ -f "$HOME/.local/bin/haku_backend_lib.sh" ]]; then
    source "$HOME/.local/bin/haku_backend_lib.sh"
fi

SCRIPT_PATH="${CAVA_LAYER_PATH:-$HOME/.local/bin/cava_layer.py}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="${CAVA_PIDFILE:-/tmp/cava-layer.pid}"
LOGFILE="${CAVA_LOGFILE:-/tmp/cava-layer.log}"

POSITION_STATE_FILE="$(haku_state_path cava.position)"
DYNAMIC_STATE_FILE="$(haku_state_path cava.dynamic-position)"
CAVA_LAYER_STATE="$(haku_state_path cava.enabled)"
 
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
    --position [POS]    Toggle or set screen position (top or bottom, Hikai)
    -d, --toggle-dynamic Toggle dynamic position (affected by panels)
    -c, --color-switch  Toggle foreground color between black and white
    --startup           Restore previous state at boot (if enabled)
    --status            Print enabled or disabled

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

kill_classic_process() {
    if ! is_running; then
        rm -f "$PIDFILE"
        return 0
    fi
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null)"
    log "Stopping classic cava-layer (pid=$pid)..."
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
}

start() {
    mkdir -p "$STATE_DIR"
    if haku_qs_mode; then
        echo "1" > "$CAVA_LAYER_STATE"
        if is_running; then
            kill_classic_process
        fi
        log "Started (Hikai native)."
        return 0
    fi

    if is_running; then
        log "Already running."
        echo "1" > "$CAVA_LAYER_STATE"
        return 0
    fi

    check_dependencies
 
    local dynamic_flag=""
    if haku_qs_mode || [[ "$(cat "$DYNAMIC_STATE_FILE" 2>/dev/null || echo "0")" == "1" ]]; then
        dynamic_flag="--dynamic"
    fi

    local height_flag=""
    local custom_h=$(cat "$(haku_state_path cava.height)" 2>/dev/null || echo "")
    if [[ -n "$custom_h" && "$custom_h" =~ ^[0-9]+$ ]]; then
        height_flag="-H $custom_h"
    fi

    log "Starting: python3 $SCRIPT_PATH $dynamic_flag $height_flag $*"
    setsid python3 "$SCRIPT_PATH" $dynamic_flag $height_flag "$@" </dev/null >"$LOGFILE" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    echo "$pid" > "$PIDFILE"
 
    sleep 0.3
    if ! kill -0 "$pid" 2>/dev/null; then
        err "cava-layer exited immediately. Last log lines:"
        tail -n 20 "$LOGFILE" >&2 2>/dev/null
        rm -f "$PIDFILE"
        echo "0" > "$CAVA_LAYER_STATE"
        exit 1
    fi
 
    echo "1" > "$CAVA_LAYER_STATE"
    log "Started (pid=$pid). Log: $LOGFILE"
}
 
stop() {
    mkdir -p "$STATE_DIR"
    echo "0" > "$CAVA_LAYER_STATE"

    if haku_qs_mode; then
        if is_running; then
            kill_classic_process
        fi
        log "Stopped (Hikai native)."
        return 0
    fi

    kill_classic_process
    log "Stopped."
}
 
toggle() {
    if haku_qs_mode; then
        if [[ "$(cat "$CAVA_LAYER_STATE" 2>/dev/null || echo "0")" == "1" ]]; then
            stop
        else
            start "$@"
        fi
        return 0
    fi

    if is_running; then
        stop
    else
        start "$@"
    fi
}

startup() {
    if haku_qs_mode; then
        if is_running; then
            echo "1" > "$CAVA_LAYER_STATE"
            kill_classic_process
        fi
        return 0
    fi

    if [[ "$(cat "$CAVA_LAYER_STATE" 2>/dev/null || echo "0")" == "1" ]]; then
        if ! is_running; then
            start "$@"
        fi
    fi
}

sync_dynamic_position() {
    if ! haku_qs_mode; then return 0; fi
    mkdir -p "$STATE_DIR"
    local is_dynamic="$(cat "$DYNAMIC_STATE_FILE" 2>/dev/null || echo "0")"
    if [[ "$is_dynamic" == "1" ]]; then
        local is_taskbar="$(cat "$(haku_state_path desktop.taskbar.requested)" 2>/dev/null || echo "0")"
        if [[ "$is_taskbar" == "1" ]]; then
            set_position "bottom" "--sync"
        else
            set_position "top" "--sync"
        fi
    fi
}

set_position() {
    if ! haku_qs_mode; then
        log "Position switching is only available in Hikai mode."
        return 0
    fi
    local pos="${1:-}"
    local from_sync="${2:-}"
    mkdir -p "$STATE_DIR"
    if [[ "$pos" == "top" || "$pos" == "1" ]]; then
        echo "1" > "$POSITION_STATE_FILE"
        [[ "$from_sync" != "--sync" ]] && echo "0" > "$DYNAMIC_STATE_FILE"
        log "Position set to top."
    elif [[ "$pos" == "bottom" || "$pos" == "0" ]]; then
        echo "0" > "$POSITION_STATE_FILE"
        [[ "$from_sync" != "--sync" ]] && echo "0" > "$DYNAMIC_STATE_FILE"
        log "Position set to bottom."
    else
        toggle_position
        return $?
    fi
}

toggle_position() {
    if ! haku_qs_mode; then
        log "Position switching is only available in Hikai mode."
        return 0
    fi
    mkdir -p "$STATE_DIR"
    local current_state=$(cat "$POSITION_STATE_FILE" 2>/dev/null || echo "1")
    if [[ "$current_state" == "0" || "$current_state" == "bottom" ]]; then
        set_position "top"
    else
        set_position "bottom"
    fi
}

toggle_dynamic() {
    if ! haku_qs_mode; then
        log "Dynamic position is only available in Hikai mode."
        return 0
    fi
    mkdir -p "$STATE_DIR"
    local current_state=$(cat "$DYNAMIC_STATE_FILE" 2>/dev/null || echo "0")
    if [[ "$current_state" == "1" ]]; then
        echo "0" > "$DYNAMIC_STATE_FILE"
        log "Dynamic position disabled."
    else
        echo "1" > "$DYNAMIC_STATE_FILE"
        log "Dynamic position enabled."
        sync_dynamic_position
    fi
}

set_dynamic_position() {
    local mode="${1:-}"
    if ! haku_qs_mode; then
        log "Dynamic position is only available in Hikai mode."
        return 0
    fi
    mkdir -p "$STATE_DIR"
    if [[ "$mode" == "1" || "$mode" == "on" || "$mode" == "true" ]]; then
        echo "1" > "$DYNAMIC_STATE_FILE"
        log "Dynamic position enabled."
        sync_dynamic_position
    elif [[ "$mode" == "0" || "$mode" == "off" || "$mode" == "false" ]]; then
        echo "0" > "$DYNAMIC_STATE_FILE"
        log "Dynamic position disabled."
    else
        toggle_dynamic
    fi
}

set_color_mode() {
    local mode="${1:-}"
    mkdir -p "$STATE_DIR"
    local COLOR_STATE_FILE="$(haku_state_path cava.color-mode)"
    local CAVA_CONFIG="$HOME/hakucfg/config/cava-layer"

    if [[ "$mode" == "surface" || "$mode" == "0" || "$mode" == "black" ]]; then
        if [[ -f "$CAVA_CONFIG" ]]; then
            if grep -qE '^foreground\s*=' "$CAVA_CONFIG"; then
                sed -i -E 's/^foreground\s*=.*/foreground = black/' "$CAVA_CONFIG"
            elif grep -qE '^\[color\]' "$CAVA_CONFIG"; then
                sed -i -E '/^\[color\]/a foreground = black' "$CAVA_CONFIG"
            else
                printf '\n[color]\nforeground = black\n' >> "$CAVA_CONFIG"
            fi
        fi
        echo "0" > "$COLOR_STATE_FILE"
        log "Cava color mode set to surface (black)."
    elif [[ "$mode" == "accent" || "$mode" == "1" || "$mode" == "white" ]]; then
        if [[ -f "$CAVA_CONFIG" ]]; then
            if grep -qE '^foreground\s*=' "$CAVA_CONFIG"; then
                sed -i -E 's/^foreground\s*=.*/foreground = white/' "$CAVA_CONFIG"
            elif grep -qE '^\[color\]' "$CAVA_CONFIG"; then
                sed -i -E '/^\[color\]/a foreground = white' "$CAVA_CONFIG"
            else
                printf '\n[color]\nforeground = white\n' >> "$CAVA_CONFIG"
            fi
        fi
        echo "1" > "$COLOR_STATE_FILE"
        log "Cava color mode set to accent (white)."
    else
        toggle_color
        return $?
    fi

    if is_running; then
        stop
        start
    fi
}

set_height() {
    local h="${1:-}"
    mkdir -p "$STATE_DIR"
    local HEIGHT_STATE_FILE="$(haku_state_path cava.height)"
    if [[ "$h" =~ ^[0-9]+$ ]] && (( h >= 32 && h <= 300 )); then
        echo "$h" > "$HEIGHT_STATE_FILE"
        log "Layer height set to ${h}px."
    else
        err "Invalid height: $h (expected 32-300)"
        return 1
    fi
    if ! haku_qs_mode && is_running; then
        stop
        start
    fi
}

toggle_color() {
    mkdir -p "$STATE_DIR"
    local COLOR_STATE_FILE="$(haku_state_path cava.color-mode)"
    local current="$(cat "$COLOR_STATE_FILE" 2>/dev/null || echo "1")"
    if [[ "$current" == "0" || "$current" == "surface" || "$current" == "black" ]]; then
        set_color_mode "accent"
    else
        set_color_mode "surface"
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
 
generate_hikai_conf() {
    local source_conf="${1:-$HOME/hakucfg/config/cava-layer}"
    local target_conf="${2:-${XDG_RUNTIME_DIR:-/tmp}/hakuspace-cava-hikai.conf}"

    mkdir -p "$(dirname "$target_conf")"
    if [[ ! -f "$source_conf" ]]; then
        mkdir -p "$(dirname "$source_conf")"
        cat <<'EOF' > "$source_conf"
[general]
bar_width = 6
bar_spacing = 1

[output]
method = ncurses
orientation = top

[color]
foreground = white
EOF
    fi

    python3 -c "
import sys

source_path = sys.argv[1]
target_path = sys.argv[2]

try:
    with open(source_path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
except OSError:
    lines = []

new_lines = []
in_output = False
output_seen = False

for line in lines:
    stripped = line.strip()
    if stripped.startswith('[') and stripped.endswith(']'):
        if stripped == '[output]':
            in_output = True
            output_seen = True
            new_lines.append(line)
            new_lines.append('method = raw\n')
            new_lines.append('raw_target = /dev/stdout\n')
            new_lines.append('data_format = ascii\n')
            new_lines.append('ascii_max_range = 1000\n')
            new_lines.append('bar_delimiter = 59\n')
            new_lines.append('frame_delimiter = 10\n')
            new_lines.append('channels = stereo\n')
            continue
        else:
            in_output = False
    if in_output:
        if any(stripped.startswith(k) for k in ('method', 'raw_target', 'data_format', 'ascii_max_range', 'bar_delimiter', 'frame_delimiter', 'channels', 'orientation')):
            continue
    new_lines.append(line)

if not output_seen:
    new_lines.append('\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\nchannels = stereo\n')

with open(target_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
" "$source_conf" "$target_conf"
}

run_hikai() {
    local target_conf="${XDG_RUNTIME_DIR:-/tmp}/hakuspace-cava-hikai.conf"
    generate_hikai_conf "$HOME/hakucfg/config/cava-layer" "$target_conf"
    exec cava -p "$target_conf"
}

case "${1:-}" in
    --run-hikai)
        run_hikai
        ;;
    --generate-hikai-conf)
        generate_hikai_conf "${2:-$HOME/hakucfg/config/cava-layer}" "${3:-${XDG_RUNTIME_DIR:-/tmp}/hakuspace-cava-hikai.conf}"
        ;;
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
    --startup)
        shift
        startup "$@"
        ;;
    reload)
        reload
        ;;
    --position)
        shift
        set_position "${1:-}"
        ;;
    -d|--toggle-dynamic)
        toggle_dynamic
        ;;
    --sync-dynamic)
        sync_dynamic_position
        ;;
    --dynamic-position)
        shift
        set_dynamic_position "${1:-}"
        ;;
    -c|--color-switch)
        toggle_color
        ;;
    --color-mode)
        shift
        set_color_mode "${1:-}"
        ;;
    -H|--height)
        shift
        set_height "${1:-}"
        ;;
    *)
        # No explicit subcommand: treat everything (including -p/-H/-F flags,
        # or nothing at all) as arguments to a plain toggle.
        toggle "$@"
        ;;
esac

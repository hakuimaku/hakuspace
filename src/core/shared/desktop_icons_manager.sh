#!/usr/bin/env bash

# This script manages the state of desktop icons
# Toggle them on/off, reload them, or restore the previous state at startup.

# Load canonical paths without initializing state during status queries.
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
if [[ "${1:-}" == "--status" ]]; then
    if [[ "$(cat "$(haku_state_path desktop.icons.enabled)" 2>/dev/null)" == "1" ]]; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
    exit 0
fi

source "$HAKU_BIN_DIR/haku_backend_lib.sh" || exit 1
DESKTOP_ICONS_STATE="$(haku_state_path desktop.icons.enabled)"

DESKTOP_MANAGER_BIN="$HAKU_BIN_DIR/desktop_icons.py"
RUNTIME_DIR="$(haku_runtime_dir)"
PID_FILE="$RUNTIME_DIR/desktop-icons.pid"
LOG_FILE="$RUNTIME_DIR/desktop-icons.log"

mkdir -p "$STATE_DIR"

# Ensure state file exists and contains valid values (0 or 1)
if [[ ! -f "$DESKTOP_ICONS_STATE" ]] || ! grep -qxE '0|1' "$DESKTOP_ICONS_STATE"; then
    echo "0" > "$DESKTOP_ICONS_STATE"
fi

desktop_icons_pids() {
    pgrep -f "$DESKTOP_MANAGER_BIN" 2>/dev/null || true
}

desktop_icons_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    [[ -n "$(desktop_icons_pids)" ]]
}

wait_for_exit() {
    local i
    for ((i = 0; i < 50; i++)); do
        if [[ -z "$(desktop_icons_pids)" ]]; then
            return 0
        fi
        sleep 0.05
    done
    return 1
}

launch_desktop_icons() {
    if [[ ! -f "$DESKTOP_MANAGER_BIN" ]]; then
        printf 'desktop_icons_manager.sh: missing %s\n' "$DESKTOP_MANAGER_BIN" >&2
        return 1
    fi
    if desktop_icons_running; then
        return 0
    fi
    : > "$LOG_FILE" || return 1
    setsid -f python3 "$DESKTOP_MANAGER_BIN" </dev/null >> "$LOG_FILE" 2>&1
    local deadline=$((SECONDS + 5)) pid=""
    while (( SECONDS < deadline )); do
        pid="$(desktop_icons_pids | head -n 1)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && grep -q 'Desktop icons configured' "$LOG_FILE" 2>/dev/null; then
            printf '%s\n' "$pid" > "$PID_FILE"
            return 0
        fi
        sleep 0.05
    done
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        printf '%s\n' "$pid" > "$PID_FILE"
        return 0
    fi
    printf 'desktop_icons_manager.sh: failed to start %s; see %s\n' "$DESKTOP_MANAGER_BIN" "$LOG_FILE" >&2
    return 1
}

kill_desktop_icons() {
    local pid="" pids=""
    if [[ -f "$PID_FILE" ]]; then
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    pids="$(desktop_icons_pids)"
    if [[ -n "$pids" ]]; then
        pkill -f "$DESKTOP_MANAGER_BIN" 2>/dev/null || true
    fi
    if ! wait_for_exit; then
        pkill -KILL -f "$DESKTOP_MANAGER_BIN" 2>/dev/null || true
        wait_for_exit || true
    fi
}

reload_style() {
    local pid="" pids=""
    if [[ -f "$PID_FILE" ]]; then
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -USR1 "$pid" 2>/dev/null || true
            return 0
        fi
    fi
    pids="$(desktop_icons_pids)"
    if [[ -n "$pids" ]]; then
        # shellcheck disable=SC2086
        kill -USR1 $pids 2>/dev/null || true
        return 0
    fi
    return 1
}

# Display help message
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: desktop_icons_manager.sh [OPTION]
Manage desktop icons.

Options:
    --startup           Restore previous state at boot
    --toggle            Toggle desktop icons on/off
    --set STATE         Set desktop icons enabled or disabled explicitly
    --status            Print enabled or disabled
    --reload            Hot-reload desktop icons config, style, and files
    reload-style        Hot-reload desktop icons CSS/config via SIGUSR1
    --restart           Stop and restart desktop icons process
    -h, --help          Show this help message
EOF
    exit 0
fi

# Toggle desktop icons on/off
if [[ "${1:-}" == "--toggle" ]]; then
    if desktop_icons_running || [[ "$(cat "$DESKTOP_ICONS_STATE")" == "1" ]]; then
        echo "0" > "$DESKTOP_ICONS_STATE"
        kill_desktop_icons
        echo "Desktop icons disabled"
    else
        launch_desktop_icons || exit 1
        echo "1" > "$DESKTOP_ICONS_STATE"
        echo "Desktop icons enabled"
    fi
    exit 0
fi

# Set desktop icons explicitly
if [[ "${1:-}" == "--set" || "${1:-}" == "set" ]]; then
    case "${2:-}" in
        enabled|1)
            launch_desktop_icons || exit 1
            echo "1" > "$DESKTOP_ICONS_STATE"
            echo "Desktop icons enabled"
            ;;
        disabled|0)
            echo "0" > "$DESKTOP_ICONS_STATE"
            kill_desktop_icons
            echo "Desktop icons disabled"
            ;;
        *)
            printf 'desktop_icons_manager.sh: --set requires enabled or disabled.\n' >&2
            exit 2
            ;;
    esac
    exit 0
fi

# Hot-reload style/config if running
if [[ "${1:-}" == "reload-style" || "${1:-}" == "--reload-style" ]]; then
    reload_style || true
    exit 0
fi

# Hot-reload desktop icons if running
if [[ "${1:-}" == "--reload" || "${1:-}" == "reload" ]]; then
    if reload_style; then
        echo "Desktop icons reloaded"
    else
        echo "Desktop icons are not running. Use --toggle to enable them."
    fi
    exit 0
fi

# Full process restart when explicitly requested
if [[ "${1:-}" == "--restart" || "${1:-}" == "restart" ]]; then
    if desktop_icons_running || [[ "$(cat "$DESKTOP_ICONS_STATE")" == "1" ]]; then
        kill_desktop_icons
        launch_desktop_icons || exit 1
        echo "Desktop icons restarted"
    else
        echo "Desktop icons are not running. Use --toggle to enable them."
    fi
    exit 0
fi

# Auto-start desktop icons if enabled
if [[ "${1:-}" == "--startup" || -z "${1:-}" ]]; then
    if [[ "$(cat "$DESKTOP_ICONS_STATE")" == "1" ]]; then
        if ! desktop_icons_running; then
            launch_desktop_icons || exit 1
        fi
    fi
    exit 0
fi

echo "Invalid option. Use --help for usage information." >&2
exit 2

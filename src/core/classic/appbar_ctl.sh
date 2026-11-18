#!/usr/bin/env bash

# Headless Classic AppBar controller API.
# Owns desktop.appbar.enabled state and appbar_layer.py process lifecycle.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1

if [[ ${1:-} == --status || ${1:-} == status ]]; then
    if [[ "$(cat "$(haku_state_path desktop.appbar.enabled)" 2>/dev/null || printf '1')" == "1" ]]; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
    exit 0
fi

# shellcheck source=/dev/null
source "$HAKU_BIN_DIR/haku_backend_lib.sh" || exit 1

APPBAR_BIN="$HAKU_BIN_DIR/appbar_layer.py"
STATUS_FILE="$(haku_state_path desktop.appbar.enabled)"
RUNTIME_DIR="$(haku_runtime_dir)"
PID_FILE="$RUNTIME_DIR/appbar-layer.pid"
LOG_FILE="$RUNTIME_DIR/appbar.log"
mkdir -p "$STATE_DIR"

ensure_state() {
    if [[ ! -f "$STATUS_FILE" ]] || ! grep -qxE '0|1' "$STATUS_FILE"; then
        printf '1\n' > "$STATUS_FILE"
    fi
}

appbar_enabled() {
    [[ "$(cat "$STATUS_FILE" 2>/dev/null || printf '1')" == "1" ]]
}

appbar_pids() {
    pgrep -f "$APPBAR_BIN" 2>/dev/null || true
}

appbar_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    [[ -n "$(appbar_pids)" ]]
}

stop_appbar() {
    local pids
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    pids="$(appbar_pids)"
    if [[ -n "$pids" ]]; then
        pkill -f "$APPBAR_BIN" 2>/dev/null || true
        sleep 0.15
    fi
}

start_appbar() {
    if haku_qs_mode; then
        return 0
    fi
    if [[ ! -f "$APPBAR_BIN" ]]; then
        printf 'appbar_ctl.sh: missing %s\n' "$APPBAR_BIN" >&2
        return 1
    fi
    if appbar_running; then
        return 0
    fi
    : > "$LOG_FILE" || return 1
    setsid -f python3 "$APPBAR_BIN" </dev/null >> "$LOG_FILE" 2>&1
    local deadline=$((SECONDS + 5)) pid=""
    while (( SECONDS < deadline )); do
        pid="$(appbar_pids | head -n 1)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && grep -q 'AppBar configured' "$LOG_FILE" 2>/dev/null; then
            printf '%s\n' "$pid" > "$PID_FILE"
            return 0
        fi
        sleep 0.05
    done
    printf 'appbar_ctl.sh: failed to start %s; see %s\n' "$APPBAR_BIN" "$LOG_FILE" >&2
    return 1
}

reload_appbar() {
    if haku_qs_mode; then
        return 0
    fi
    appbar_enabled || return 0
    stop_appbar
    start_appbar
}

reload_style() {
    if haku_qs_mode; then
        return 0
    fi
    local pid pids
    if [[ -f "$PID_FILE" ]]; then
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -USR1 "$pid" 2>/dev/null || true
            return 0
        fi
    fi
    pids="$(appbar_pids)"
    if [[ -n "$pids" ]]; then
        # shellcheck disable=SC2086
        kill -USR1 $pids 2>/dev/null || true
    fi
}

startup_appbar() {
    if haku_qs_mode; then
        return 0
    fi
    if appbar_enabled; then
        start_appbar
    fi
}

toggle_appbar() {
    if haku_qs_mode; then
        return 0
    fi
    if appbar_running; then
        stop_appbar
        printf '0\n' > "$STATUS_FILE"
    else
        start_appbar || return 1
        printf '1\n' > "$STATUS_FILE"
    fi
}

set_appbar() {
    if haku_qs_mode; then
        return 0
    fi
    case "${1:-}" in
        enabled|1)
            start_appbar || return 1
            printf '1\n' > "$STATUS_FILE"
            ;;
        disabled|0)
            stop_appbar
            printf '0\n' > "$STATUS_FILE"
            ;;
        *)
            printf 'appbar_ctl.sh: --set requires enabled or disabled.\n' >&2
            return 2
            ;;
    esac
}

print_help() {
    cat <<'EOF_HELP'
Usage: appbar_ctl.sh COMMAND [ARG]
Headless Classic AppBar control API.

Commands:
    start               Start AppBar if not already running
    stop                Stop running AppBar process
    toggle              Toggle AppBar on/off and persist state
    set enabled|disabled
                        Set AppBar state explicitly
    reload              Restart AppBar when enabled
    reload-style        Hot-reload AppBar CSS/theme without restarting
    startup             Restore AppBar at session startup
    status              Print enabled or disabled
    -h, --help          Show this help message
EOF_HELP
}

if haku_qs_mode && [[ "${1:-}" == "toggle" || "${1:-}" == "--toggle" ]]; then
    exit 0
fi
ensure_state

case "${1:-}" in
    start|--start)
        start_appbar
        ;;
    stop|--stop)
        stop_appbar
        ;;
    toggle|--toggle)
        toggle_appbar
        ;;
    set|--set)
        set_appbar "${2:-}"
        ;;
    reload|--reload)
        reload_appbar
        ;;
    reload-style|--reload-style)
        reload_style
        ;;
    startup|--startup)
        startup_appbar
        ;;
    status|--status)
        if appbar_enabled; then printf 'enabled\n'; else printf 'disabled\n'; fi
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

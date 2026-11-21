#!/usr/bin/env bash

# Headless Waybar controller API.
# Owns Waybar config presence checks and process lifecycle.
# Presentation/selection UI belongs outside this backend.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

WAYBAR_DIR="$HOME/.config/waybar"
STATUS_FILE="$(haku_state_path desktop.waybar.requested)"
mkdir -p "$STATE_DIR"

ensure_state() {
    if [[ ! -f "$STATUS_FILE" ]] || ! grep -qxE '0|1' "$STATUS_FILE"; then
        printf '1\n' > "$STATUS_FILE"
    fi
}

waybar_enabled() {
    [[ "$(cat "$STATUS_FILE" 2>/dev/null || printf '1')" == "1" ]]
}

ensure_config() {
    if [[ ( ! -f "$WAYBAR_DIR/config.jsonc" && ! -f "$WAYBAR_DIR/config" ) || ! -f "$WAYBAR_DIR/style.css" ]]; then
        printf 'waybar_ctl.sh: missing Waybar config or style.css in %s\n' "$WAYBAR_DIR" >&2
        return 1
    fi
}

stop_waybar() {
    if pgrep -fx waybar >/dev/null 2>&1; then
        pkill -fx waybar
        sleep 0.2
    fi
}

# Wait for Waybar's configure event before callers reveal the Classic desktop.
start_waybar() {
    local log_file="$(haku_runtime_dir)/waybar.log" pid deadline=$((SECONDS + 10))
    # Clear old readiness before forking the new Waybar process.
    : > "$log_file" || return 1
    (
        trap '' HUP
        exec waybar </dev/null >> "$log_file" 2>&1
    ) &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if grep -q 'Bar configured (width: .* for output: ' "$log_file"; then
            return 0
        fi
        (( SECONDS < deadline )) || break
        sleep 0.05
    done
    printf 'waybar_ctl.sh: Waybar did not configure a bar; see %s\n' "$log_file" >&2
    kill "$pid" 2>/dev/null || true
    return 1
}

start_cmd() {
    if haku_qs_mode; then
        return 0
    fi
    ensure_config || return 1
    if ! pgrep -x waybar >/dev/null 2>&1; then
        start_waybar || return 1
    fi
}

stop_cmd() {
    if haku_qs_mode; then
        return 0
    fi
    stop_waybar
}

reanchor_appbar_if_running() {
    if [[ -x "$HAKU_BIN_DIR/appbar_ctl.sh" ]] && pgrep -f "$HAKU_BIN_DIR/appbar_layer.py" >/dev/null 2>&1; then
        "$HAKU_BIN_DIR/appbar_ctl.sh" reload >/dev/null 2>&1 || true
    fi
}

reload_waybar() {
    if haku_qs_mode; then
        return 0
    fi
    waybar_enabled || return 0
    ensure_config || return 1
    stop_waybar
    start_waybar || return 1
    reanchor_appbar_if_running
}

startup_waybar() {
    if haku_qs_mode; then
        return 0
    fi
    ensure_config || return 1
    if waybar_enabled && ! pgrep -x waybar >/dev/null 2>&1; then
        start_waybar
    fi
}

toggle_waybar() {
    if haku_qs_mode; then
        return 0
    fi

    if pgrep -x waybar >/dev/null 2>&1; then
        pkill -x waybar
        printf '0\n' > "$STATUS_FILE"
    else
        ensure_config || return 1
        start_waybar || return 1
        printf '1\n' > "$STATUS_FILE"
        reanchor_appbar_if_running
    fi
}

print_help() {
    cat <<'EOF_HELP'
Usage: waybar_ctl.sh COMMAND
Headless Waybar control API.

Commands:
    start               Start Waybar if not already running
    stop                Stop running Waybar process
    toggle              Toggle Waybar on/off
    reload              Reload Waybar when enabled
    startup             Restore Waybar at session startup
    status              Print enabled or disabled
    -h, --help          Show this help message
EOF_HELP
}

# A Hikai toggle must also preserve absent or malformed Classic preferences.
if haku_qs_mode && [[ "${1:-}" == "toggle" || "${1:-}" == "--toggle" ]]; then
    exit 0
fi
ensure_state

case "${1:-}" in
    start|--start)
        start_cmd
        ;;
    stop|--stop)
        stop_cmd
        ;;
    toggle|--toggle)
        toggle_waybar
        ;;
    reload|--reload)
        reload_waybar
        ;;
    startup|--startup)
        startup_waybar
        ;;
    status|--status)
        if waybar_enabled; then printf 'enabled\n'; else printf 'disabled\n'; fi
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

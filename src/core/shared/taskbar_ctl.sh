#!/usr/bin/env bash

# Headless Taskbar/AppBar domain/controller API.
#
# In Hikai mode, HakuSpace manages the native QML Taskbar via
# desktop.taskbar.requested and hikai_chrome_state_ctl.py.
# In Classic mode, startup/reload/toggle/set/status route to Classic AppBar
# (appbar_ctl.sh, desktop.appbar.enabled), keeping Hikai and Classic state separate.

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1

if [[ ${1:-} == --status ]]; then
    if [[ "$(cat "$(haku_state_path shell.backend)" 2>/dev/null || printf 'classic')" != "hikai" ]]; then
        if [[ -x "$HAKU_BIN_DIR/appbar_ctl.sh" ]]; then
            exec "$HAKU_BIN_DIR/appbar_ctl.sh" --status
        fi
        printf 'disabled\n'
        exit 0
    fi
    if [[ "$(cat "$(haku_state_path desktop.taskbar.requested)" 2>/dev/null)" == "1" ]]; then
        printf 'enabled\n'
    else
        printf 'disabled\n'
    fi
    exit 0
fi

source "$HAKU_BIN_DIR/haku_backend_lib.sh" || exit 1

MANUAL_STATE="$(haku_state_path desktop.taskbar.requested)"

ensure_manual_state() {
    if [[ ! -f "$MANUAL_STATE" ]] || ! grep -qxE '0|1' "$MANUAL_STATE"; then
        echo "0" > "$MANUAL_STATE"
    fi
}

set_layout() {
    case "${1:-}" in
        topbar|leftbar|disabled|taskbar|enabled|cycle) ;;
        *) printf 'Invalid layout target\n' >&2; return 2 ;;
    esac
    if ! haku_qs_mode; then
        printf 'Taskbar is available in Hikai only.\n' >&2
        return 2
    fi
    local result
    result="$(python3 "$HAKU_BIN_DIR/hikai_chrome_state_ctl.py" layout "$1")" || return $?
    if [[ "$(cat "$(haku_state_path cava.dynamic-position)" 2>/dev/null)" == 1 ]]; then
        local edge is_tb
        edge="$(grep -oP '"statusEdge":\s*"\K[^"]+' <<< "$result" 2>/dev/null || true)"
        is_tb="$(grep -oP '"taskbar":\s*\K(true|false)' <<< "$result" 2>/dev/null || true)"
        if [[ "$is_tb" == "true" ]]; then
            printf 'bottom\n' > "$(haku_state_path cava.position)"
        elif [[ "$edge" == "left" ]]; then
            printf 'left\n' > "$(haku_state_path cava.position)"
        else
            printf 'top\n' > "$(haku_state_path cava.position)"
        fi
    fi
}

toggle_taskbar() {
    if ! haku_qs_mode; then
        if [[ -x "$HAKU_BIN_DIR/appbar_ctl.sh" ]]; then
            exec "$HAKU_BIN_DIR/appbar_ctl.sh" --toggle
        fi
        return 0
    fi
    if [[ "$(cat "$MANUAL_STATE")" == 1 ]]; then set_layout disabled; else set_layout taskbar; fi
}

print_help() {
    cat <<'EOF_HELP'
Usage: taskbar_ctl.sh COMMAND [ARG]
Headless Taskbar control API (Hikai).

Commands:
    --startup               No-op in Classic; Hikai restores from state
    --reload                No-op in Classic
    --layout topbar|leftbar|taskbar|cycle  Set the layout explicitly or cycle status bars
    --set enabled|disabled  Set Taskbar explicitly
    --toggle                Toggle the taskbar on/off
    --status                Print enabled or disabled
    -h, --help              Show this help message
EOF_HELP
}

mkdir -p "$STATE_DIR"
ensure_manual_state

case "${1:-}" in
    --startup|--reload)
        if ! haku_qs_mode && [[ -x "$HAKU_BIN_DIR/appbar_ctl.sh" ]]; then
            exec "$HAKU_BIN_DIR/appbar_ctl.sh" "$1"
        fi
        exit 0
        ;;
    --layout)
        [[ -n "${2:-}" ]] || { printf 'taskbar_ctl.sh: --layout requires a target.\n' >&2; exit 2; }
        set_layout "$2"
        ;;
    --set)
        case "${2:-}" in
            enabled|disabled)
                if ! haku_qs_mode; then
                    if [[ -x "$HAKU_BIN_DIR/appbar_ctl.sh" ]]; then
                        exec "$HAKU_BIN_DIR/appbar_ctl.sh" --set "$2"
                    fi
                    exit 0
                fi
                set_layout "$2"
                ;;
            *) printf 'taskbar_ctl.sh: --set requires enabled or disabled.\n' >&2; exit 2 ;;
        esac
        ;;
    --toggle)
        toggle_taskbar
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

#!/usr/bin/env bash
# HakuSpace Runtime Service Reload Module
# Reloads active runtime components (e.g. Waybar).

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

reload_waybar() {
    local waybar_mgr="$DEST_BIN/statusbar_manager.sh"
    if [[ -x "$waybar_mgr" ]]; then
        "$waybar_mgr" --reload >/dev/null 2>&1 || true
        log_ok "Status bar reloaded."
    else
        log_skip "Status bar manager not executable at $(shorten_path "$waybar_mgr"). Skipping reload."
    fi
}

reload_quickshell() {
    local qs_pattern='^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)'
    if ! pgrep -f "$qs_pattern" >/dev/null 2>&1 && ! pgrep -f qs_supervisor.sh >/dev/null 2>&1; then
        log_skip "Quickshell is not running. Skipping reload."
        return 0
    fi

    if command -v qs >/dev/null 2>&1; then
        timeout 2s qs -c hakuspace kill >/dev/null 2>&1 || true
    fi
    if pgrep -f "$qs_pattern" >/dev/null 2>&1; then
        pkill -f "$qs_pattern" >/dev/null 2>&1 || true
    fi

    if pgrep -f qs_supervisor.sh >/dev/null 2>&1; then
        log_ok "Quickshell reload requested (managed by qs_supervisor)."
    elif [[ -x "$DEST_BIN/qs_supervisor.sh" ]]; then
        (
            trap '' HUP
            exec "$DEST_BIN/qs_supervisor.sh" </dev/null >/dev/null 2>&1
        ) &
        log_ok "Quickshell reloaded."
    else
        log_skip "Quickshell supervisor not executable at $(shorten_path "$DEST_BIN/qs_supervisor.sh")."
    fi
}

TARGET="${1:-waybar}"

case "$TARGET" in
    waybar)
        reload_waybar
        ;;
    quickshell)
        reload_quickshell
        ;;
    all)
        reload_waybar
        reload_quickshell
        ;;
    --help|-h)
        echo "Usage: $0 [waybar | quickshell | all]"
        exit 0
        ;;
    *)
        log_warn "Unknown reload target: $TARGET"
        exit 0
        ;;
esac

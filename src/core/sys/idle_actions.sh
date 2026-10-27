#!/usr/bin/env bash

# Serialize reversible idle effects and retain recovery markers across shell crashes.
set -eu
IDLE_ACTION_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IDLE_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace"
mkdir -p "$IDLE_RUNTIME"
exec 7>"$IDLE_RUNTIME/idle-actions.lock"
flock -w 10 7

# Restore only effects acquired by native idle, leaving secure locks untouched.
recover() {
    local failed=0
    if [[ -f "$IDLE_RUNTIME/idle-display-off" ]]; then
        if display_power on; then rm -f "$IDLE_RUNTIME/idle-display-off"; else failed=1; fi
    fi
    if [[ -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
        if brightnessctl -r; then rm -f "$IDLE_RUNTIME/idle-dimmed"; else failed=1; fi
    fi
    return "$failed"
}

# Keep compositor routing in the existing DPMS owner.
display_power() {
    "$IDLE_ACTION_DIR/dpms_handler.sh" "$1"
}

case "${1:-}" in
    dim)
        [[ "${2:-}" =~ ^[0-9]{1,3}$ ]] && (( 10#$2 >= 1 && 10#$2 <= 100 )) || exit 2
        if [[ ! -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
            brightnessctl -s >/dev/null
            touch "$IDLE_RUNTIME/idle-dimmed"
        fi
        brightnessctl set "$2%"
        ;;
    restore)
        if [[ -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
            brightnessctl -r
            rm -f "$IDLE_RUNTIME/idle-dimmed"
        fi
        ;;
    off) touch "$IDLE_RUNTIME/idle-display-off"; display_power off ;;
    on)
        if [[ -f "$IDLE_RUNTIME/idle-display-off" ]]; then
            display_power on
            rm -f "$IDLE_RUNTIME/idle-display-off"
        fi
        ;;
    recover) recover ;;
    *) echo "Usage: $0 {dim PERCENT|restore|off|on|recover}" >&2; exit 2 ;;
esac

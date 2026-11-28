#!/usr/bin/env bash

# Serialize reversible idle effects and retain recovery markers across shell crashes.
set -eu
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
IDLE_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace"
mkdir -p "$IDLE_RUNTIME"
exec 7<>"$IDLE_RUNTIME/idle-actions.lock"
flock -w 10 7

# Fence stale commands using the existing runtime lock file, never a preference file.
IDLE_OWNER=""
if [[ "${1:-}" == --owner ]]; then
    IDLE_OWNER="${2:-}"
    [[ "$IDLE_OWNER" =~ ^[a-zA-Z0-9._-]{1,100}$ ]] || exit 2
    shift 2
    if [[ "${1:-}" != claim && $(cat "$IDLE_RUNTIME/idle-actions.lock") != "$IDLE_OWNER" ]]; then
        exit 3
    fi
fi

# Target only backlight devices so LED class devices are never saved or dimmed.
backlight_ctl() {
    brightnessctl -c backlight "$@"
}

# Keep compositor routing in the existing DPMS owner.
display_power() {
    "$HAKU_BIN_DIR/dpms_handler.sh" "$1"
}

# Restore only effects acquired by idle actions, leaving secure locks untouched.
recover() {
    local failed=0 woke_display=0
    if [[ -f "$IDLE_RUNTIME/idle-display-off" ]]; then
        if display_power on; then
            rm -f "$IDLE_RUNTIME/idle-display-off"
            woke_display=1
        else
            failed=1
        fi
    fi
    if [[ -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
        if (( woke_display )); then
            # Let the display backlight driver finish waking before restoring brightness.
            sleep 0.5
        fi
        if backlight_ctl -r >/dev/null; then
            rm -f "$IDLE_RUNTIME/idle-dimmed"
        else
            failed=1
        fi
    fi
    return "$failed"
}

# Power monitors on unconditionally (e.g. after suspend/DPMS) and restore dim state.
wake() {
    local failed=0
    if display_power on; then
        rm -f "$IDLE_RUNTIME/idle-display-off"
    else
        failed=1
    fi
    if [[ -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
        sleep 0.5
        if backlight_ctl -r >/dev/null; then
            rm -f "$IDLE_RUNTIME/idle-dimmed"
        else
            failed=1
        fi
    fi
    return "$failed"
}

case "${1:-}" in
    claim)
        [[ -n "$IDLE_OWNER" ]] || exit 2
        recover
        printf '%s\n' "$IDLE_OWNER" > "$IDLE_RUNTIME/idle-actions.lock"
        ;;
    dim)
        [[ "${2:-}" =~ ^[0-9]{1,3}$ ]] && (( 10#$2 >= 1 && 10#$2 <= 100 )) || exit 2
        if [[ ! -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
            backlight_ctl -s >/dev/null
            touch "$IDLE_RUNTIME/idle-dimmed"
        fi
        backlight_ctl set "$2%" >/dev/null
        ;;
    restore)
        # Keep the dim marker while the display is still off so DPMS-on/wake restores after panel wake.
        if [[ -f "$IDLE_RUNTIME/idle-display-off" ]]; then
            exit 0
        fi
        if [[ -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
            backlight_ctl -r >/dev/null
            rm -f "$IDLE_RUNTIME/idle-dimmed"
        fi
        ;;
    off) touch "$IDLE_RUNTIME/idle-display-off"; display_power off ;;
    on)
        if [[ -f "$IDLE_RUNTIME/idle-display-off" ]]; then
            display_power on
            rm -f "$IDLE_RUNTIME/idle-display-off"
            if [[ -f "$IDLE_RUNTIME/idle-dimmed" ]]; then
                sleep 0.5
                if backlight_ctl -r >/dev/null; then
                    rm -f "$IDLE_RUNTIME/idle-dimmed"
                fi
            fi
        fi
        ;;
    wake) wake ;;
    recover) recover ;;
    *) echo "Usage: $0 [--owner TOKEN] {claim|dim PERCENT|restore|off|on|wake|recover}" >&2; exit 2 ;;
esac

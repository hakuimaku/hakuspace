#!/usr/bin/env bash

# This script toggles the night light mode
# hyprsunset (hyprland) or gammastep (other WM)

if [[ -f "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" ]]; then
    source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
else
    source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/haku_state.sh" || exit 1
fi
STATE_FILE="$(haku_state_path system.nightlight.enabled)" || exit 1

# Include NIGHT_LIGHT_TEMPERATURE variable from setting.sh
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

# Fallback temperature if NIGHT_LIGHT_TEMPERATURE is not set
NIGHT_LIGHT_TEMPERATURE=${NIGHT_LIGHT_TEMPERATURE:-4000}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: nightlight_toggle.sh [OPTION]
Toggle the night light for the current window manager.

Options:
    --check             Report whether night light is enabled
    --on                Enable or re-apply night light
    --off               Disable night light
    --restore           Re-apply night light only if currently enabled
    --startup           Start night light if saved state is enabled
    -h, --help          Show this help message
EOF
        exit 0
fi

save_state() {
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$1" > "$STATE_FILE"
}

is_nightlight_running() {
    pgrep -x "hyprsunset" >/dev/null 2>&1 || pgrep -x "gammastep" >/dev/null 2>&1
}

stop_nightlight() {
    pkill -x hyprsunset >/dev/null 2>&1 || true
    pkill -x gammastep >/dev/null 2>&1 || true
    # Wait for the outgoing gamma client to release zwlr_gamma_control_manager_v1 before starting a replacement.
    local i=0
    while (( i < 20 )) && is_nightlight_running; do
        sleep 0.05
        (( i++ ))
    done
}

run_nightlight() {
    local desktop="${XDG_CURRENT_DESKTOP,,}"
    if [[ "$desktop" == "hyprland" ]]; then
        nohup hyprsunset --temperature "$NIGHT_LIGHT_TEMPERATURE" </dev/null >/dev/null 2>&1 &
        echo "Night light mode enabled with hyprsunset at $NIGHT_LIGHT_TEMPERATURE K"
    else
        nohup gammastep -O "$NIGHT_LIGHT_TEMPERATURE" </dev/null >/dev/null 2>&1 &
        echo "Night light mode enabled with gammastep at $NIGHT_LIGHT_TEMPERATURE K"
    fi
}

check_status() {
    if is_nightlight_running; then
        echo "Night light mode is currently enabled"
        exit 0
    else
        echo "Night light mode is currently disabled"
        exit 1
    fi
}

case "${1:-}" in
    --check)
        check_status
        ;;
    --on)
        stop_nightlight
        run_nightlight
        save_state 1
        exit 0
        ;;
    --off)
        stop_nightlight
        save_state 0
        echo "Night light mode disabled"
        exit 0
        ;;
    --restore)
        if is_nightlight_running; then
            stop_nightlight
            run_nightlight
        fi
        exit 0
        ;;
    --startup)
        if [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "1" ]]; then
            if ! is_nightlight_running; then
                run_nightlight
            fi
        fi
        exit 0
        ;;
esac

# Toggle
if is_nightlight_running; then
    stop_nightlight
    save_state 0
    echo "Night light mode disabled"
else
    run_nightlight
    save_state 1
    echo "Night light mode enabled"
fi
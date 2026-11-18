#!/usr/bin/env bash

# This script manages Haku Space Mode (Cava dynamic mode).

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_theme.sh" || exit 1


SHELL_MODE_STATE="$(haku_state_path shell.haku-space.enabled)"

if [[ ! -f "$SHELL_MODE_STATE" ]] || ! grep -qxE '0|1' "$SHELL_MODE_STATE"; then
    echo "0" > "$SHELL_MODE_STATE"
fi


turn_on() {
    if [[ "$(cat "$(haku_state_path cava.dynamic-position)" 2>/dev/null || echo "0")" != "1" ]]; then
        "$HAKU_BIN_DIR/cava_manager.sh" --toggle-dynamic
    fi

    echo "1" > "$SHELL_MODE_STATE"
    echo "Haku Space Mode enabled."
}

turn_off() {
    if [[ "$(cat "$(haku_state_path cava.dynamic-position)" 2>/dev/null || echo "0")" == "1" ]]; then
        "$HAKU_BIN_DIR/cava_manager.sh" --toggle-dynamic
    fi

    echo "0" > "$SHELL_MODE_STATE"
    echo "Haku Space Mode disabled."
}

toggle() {
    local current_state=$(cat "$SHELL_MODE_STATE" 2>/dev/null || echo "0")
    if [[ "$current_state" == "1" ]]; then
        turn_off
    else
        turn_on
    fi
}

case "${1:-}" in
    -t|--toggle)
        toggle
        ;;
    on)
        turn_on
        ;;
    off)
        turn_off
        ;;
    -c|--check)
        current_state=$(cat "$SHELL_MODE_STATE" 2>/dev/null || echo "0")
        if [[ "$current_state" == "1" ]]; then
            echo "Haku Space Mode is currently ENABLED."
        else
            echo "Haku Space Mode is currently DISABLED."
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|--toggle|--check]"
        exit 1
        ;;
esac

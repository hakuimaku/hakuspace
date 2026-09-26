#!/usr/bin/env bash

# This script manages Haku Shell Mode (combining Rounded Screen dynamic, Cava dynamic, Opaque Theme and Edge Trigger).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/haku_theme.sh"
elif [[ -f "$SCRIPT_DIR/../lib/haku_theme.sh" ]]; then
    source "$SCRIPT_DIR/../lib/haku_theme.sh"
else
    source "$HOME/.local/bin/haku_theme.sh"
fi

SHELL_MODE_STATE="$STATE_DIR/haku_shell_state"

if [[ ! -f "$SHELL_MODE_STATE" ]] || ! grep -qxE '0|1' "$SHELL_MODE_STATE"; then
    echo "0" > "$SHELL_MODE_STATE"
fi


turn_on() {
    # 1. Rounded screen
    if [[ "$(cat "$STATE_DIR/rounded_screen_dynamic_state" 2>/dev/null || echo "0")" != "1" ]]; then
        ~/.local/bin/rounded_screen_manager.sh --toggle-dynamic
    fi
    if [[ "$(cat "$STATE_DIR/rounded_screen_state" 2>/dev/null || echo "0")" != "1" ]]; then
        ~/.local/bin/rounded_screen_manager.sh --toggle
    fi

    # 2. Opaque Theme
    if [[ "$(cat "$STATE_DIR/opaque_theme_state" 2>/dev/null || echo "0")" != "1" ]]; then
        ~/.local/bin/opaque_theme.sh --toggle
    fi

    # 3. Cava
    if [[ "$(cat "$STATE_DIR/cava_dynamic_state" 2>/dev/null || echo "0")" != "1" ]]; then
        ~/.local/bin/cava_manager.sh --toggle-dynamic
    fi

    # 4. Edge Trigger
    if [[ "$(cat "$STATE_DIR/edge_trigger_state" 2>/dev/null || echo "0")" != "1" ]]; then
        ~/.local/bin/edge_trigger_manager.sh --toggle
    fi

    echo "1" > "$SHELL_MODE_STATE"
    echo "Haku Shell Mode enabled."
}

turn_off() {
    # 1. Rounded screen
    if [[ "$(cat "$STATE_DIR/rounded_screen_state" 2>/dev/null || echo "0")" == "1" ]]; then
        ~/.local/bin/rounded_screen_manager.sh --toggle
    fi

    # 2. Cava
    if [[ "$(cat "$STATE_DIR/cava_dynamic_state" 2>/dev/null || echo "0")" == "1" ]]; then
        ~/.local/bin/cava_manager.sh --toggle-dynamic
    fi

    # 3. Opaque Theme
    if [[ "$(cat "$STATE_DIR/opaque_theme_state" 2>/dev/null || echo "0")" == "1" ]]; then
        ~/.local/bin/opaque_theme.sh --toggle
    fi

    # 4. Edge Trigger
    if [[ "$(cat "$STATE_DIR/edge_trigger_state" 2>/dev/null || echo "0")" == "1" ]]; then
        ~/.local/bin/edge_trigger_manager.sh --toggle
    fi

    echo "0" > "$SHELL_MODE_STATE"
    echo "Haku Shell Mode disabled."
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
            echo "Haku Shell Mode is currently ENABLED."
        else
            echo "Haku Shell Mode is currently DISABLED."
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|--toggle|--check]"
        exit 1
        ;;
esac

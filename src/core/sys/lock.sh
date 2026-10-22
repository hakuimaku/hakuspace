#!/usr/bin/env bash

# This script locks the screen using Hikai native session lock in Hikai mode,
# and hyprlock (with resolution-aware configuration) in Classic mode or as a fail-closed fallback.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_backend_lib.sh" ]]; then
    source "$SCRIPT_DIR/haku_backend_lib.sh"
elif [[ -f "$SCRIPT_DIR/../lib/haku_backend_lib.sh" ]]; then
    source "$SCRIPT_DIR/../lib/haku_backend_lib.sh"
elif [[ -f "$HOME/.local/bin/haku_backend_lib.sh" ]]; then
    source "$HOME/.local/bin/haku_backend_lib.sh"
fi

request_hikai_native_lock() {
    command -v qs >/dev/null 2>&1 || return 1
    declare -F haku_qs_alive >/dev/null 2>&1 && haku_qs_alive || return 1

    local runtime_dir resp status_json attempt
    runtime_dir="$(haku_runtime_dir)"
    resp="$(timeout 2s qs -c hakuspace ipc call lock lock 2>>"$runtime_dir/qs.log")" || return 1
    [[ "$resp" == "ok" ]] || return 1

    # Wait until the Wayland compositor confirms all outputs are securely locked.
    for (( attempt = 0; attempt < 60; attempt++ )); do
        status_json="$(timeout 1s qs -c hakuspace ipc call lock status 2>/dev/null)" || return 1
        if [[ "$status_json" == *'"locked":true'* && "$status_json" == *'"secure":true'* ]]; then
            return 0
        fi
        sleep 0.025
    done
    return 1
}

if declare -F haku_qs_mode >/dev/null 2>&1 && haku_qs_mode; then
    if request_hikai_native_lock; then
        exit 0
    fi
    echo "Warning: Hikai native lock unavailable; falling back to hyprlock." >&2
fi

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

WIDTH=""
HEIGHT=""

# Check dependencies
if ! command -v hyprlock &> /dev/null; then
    echo "hyprlock is not installed. Please install it to use this script."
    notify-send "Lock screen" "hyprlock is not installed. Please install it to use this script."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Warning: jq is not installed"
    notify-send "Lock screen" "Warning: jq is not installed"
fi

if ! command -v wlr-randr &> /dev/null; then
    echo "wlr-randr is not installed. Some WMs may use sysfs detection instead."
fi

fallback_resolution() {
    read -r WIDTH HEIGHT <<< $(wlr-randr | grep -i "current" | head -n 1 | sed -E 's/.* ([0-9]+)x([0-9]+) px.*/\1 \2/')
    if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
        for mode_file in /sys/class/drm/card*-*/modes; do
            if [ -f "$mode_file" ] && [ -s "$mode_file" ]; then
                read -r MODE < "$mode_file"
                if [[ "$MODE" =~ ([0-9]+)x([0-9]+) ]]; then
                    WIDTH="${BASH_REMATCH[1]}"
                    HEIGHT="${BASH_REMATCH[2]}"
                fi
            fi
        done
    fi
}

get_resolution() {
    XDG_CURRENT_DESKTOP=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

    case "$XDG_CURRENT_DESKTOP" in
        "hyprland")
            read -r WIDTH HEIGHT <<< $(hyprctl monitors -j | jq -r '.[0] | "\(.width) \(.height)"')
            ;;
        "niri")
            read -r WIDTH HEIGHT <<< $(niri msg --json outputs | jq -r 'to_entries | .[0].value | .modes[.current_mode] | "\(.width) \(.height)"')
            ;;
        "mango")
            read -r WIDTH HEIGHT <<< $(mmsg get all-monitors | jq -r '.monitors[] | select(.active == true) // .[0] | "\(.width) \(.height)"')
            ;;
        *)
            fallback_resolution
            ;;
    esac
}

# Main execution
get_resolution

if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
    fallback_resolution
    if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
        echo "Could not determine monitor resolution. How it could be..."
        notify-send "Lock screen" "Could not determine monitor resolution. How it could be..."
    fi
fi

echo "Monitor resolution: ${WIDTH}x${HEIGHT}"
sleep 0.2

echo "Executing hyprlock with appropriate configuration..."
if [[ "$WIDTH" -ge 1920 && "$HEIGHT" -ge 1080 ]]; then
    exec hyprlock
else
    exec hyprlock -c ~/.config/hypr/hyprlock_tiny.conf
fi

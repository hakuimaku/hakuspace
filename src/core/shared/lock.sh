#!/usr/bin/env bash

# This script locks the screen using Hikai native session lock in Hikai mode,
# and hyprlock in Classic mode or as a fail-closed fallback.

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

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

if ! command -v hyprlock &> /dev/null; then
    echo "hyprlock is not installed. Please install it to use this script."
    notify-send "Lock screen" "hyprlock is not installed. Please install it to use this script."
    exit 1
fi

sleep 0.2
exec hyprlock

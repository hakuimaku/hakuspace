#!/usr/bin/env bash

# MangoWM Floating Window is above waybar, not a good news :(
if [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    echo "Cava Underbar is not supported on MangoWM."
    notify-send "Cava Underbar is not supported on MangoWM."
    exit 1
fi

APP_CLASS="cavaunderbar"
STATE_FILE="/tmp/cava_underbar_status" # 1 = user wants ON, 0 = user wants OFF
HIDDEN_FILE="/tmp/cava_underbar_hidden_by_fs" # 1 = daemon hid it due to fullscreen
LOCK_FILE="/tmp/cava_underbar.lock" # make sure only one daemon is running

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 is required"; exit 1; }; }

need kitty
need cava
need jq

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"
[[ ! -f "$HIDDEN_FILE" ]] && echo "0" > "$HIDDEN_FILE"

# Check 
float_sticky() {
    local cmd="niri-float-sticky"
    local binary_path=""

    # Check potential binary locations dynamically
    if command -v "$cmd" >/dev/null 2>&1; then
        binary_path="$cmd"
    elif [[ -x "$HOME/go/bin/$cmd" ]]; then
        binary_path="$HOME/go/bin/$cmd"
    else
        echo "Warning: $cmd not found. Window may not float/stick." >&2
        notify-send "Warning Cava Underbar" "$cmd not found. Window may not float/stick."
        return 1
    fi

    "$binary_path" -app-id "$APP_CLASS" &
}

run_cava() {
    pgrep -f "$APP_CLASS" >/dev/null && return 0

    kitty --class="$APP_CLASS" \
            -o background_opacity=0 \
            -o background=#000000 \
            -o font_size=5 \
            -o window_padding_width=0 \
            -o window_margin_width=0 \
            -o hide_window_decorations=yes \
            -e cava -p ~/.config/cava/config_underbar &

    if [[ "${XDG_CURRENT_DESKTOP,,}" == *"niri"* ]]; then
        float_sticky
    fi
}

stop_cava() {
    pkill -f "$APP_CLASS" 2>/dev/null
}

toggle_cava() {
    if pgrep -f "$APP_CLASS" >/dev/null; then
        stop_cava
        echo "0" > "$STATE_FILE"
        echo "0" > "$HIDDEN_FILE"
    else
        run_cava
        echo "1" > "$STATE_FILE"
        echo "0" > "$HIDDEN_FILE"
    fi
}

if [[ "$1" == "--toggle" ]]; then
    toggle_cava
    exit 0
fi


# Check fullscreen, work around for Hyprland's fullscreen behavior
# Hyprland use pin cava_underbar window -> fullscreen window still shows it up
echo "Cava Underbar daemon started, check fullscreen every second"

if [[ "${XDG_CURRENT_DESKTOP,,}" != *"hyprland"* ]]; then
    echo "Error: Cava Underbar daemon is designed to run exclusively on Hyprland."
    exit 1
fi

get_fs() {
    hyprctl activewindow -j 2>/dev/null | jq -r '.fullscreen // 0' 2>/dev/null
}

daemon_tick() {
    local want_on fs hidden
    want_on="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    hidden="$(cat "$HIDDEN_FILE" 2>/dev/null || echo 0)"
    fs="$(get_fs)"
    [[ -z "$fs" ]] && fs=0

    # user wants OFF -> daemon never starts cava
    [[ "$want_on" != "1" ]] && return 0

    # fullscreen (mode 1 or 2) => hide if running
    if [[ "$fs" != "0" ]]; then
        if pgrep -f "$APP_CLASS" >/dev/null; then
        stop_cava
        echo "1" > "$HIDDEN_FILE"
        fi
        return 0
    fi

    # not fullscreen => only restore if daemon had hidden it
    if [[ "$hidden" == "1" ]]; then
        run_cava
        echo "0" > "$HIDDEN_FILE"
    fi
}

# no --toggle => daemon only
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

while true; do
    daemon_tick
    sleep 1
done
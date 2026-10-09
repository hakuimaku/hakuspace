#!/bin/bash

# MangoWM Floating Window is above waybar, sucks
if [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    echo "Cava Underbar is not supported on MangoWM."
    notify-send "Cava Underbar is not supported on MangoWM."
    exit 1
fi

# Check dependencies
if ! command -v kitty >/dev/null 2>&1; then
    echo "kitty terminal is required to run Cava Underbar." >&2
    notify-send "kitty terminal is required to run Cava Underbar."
    exit 1
fi

if ! command -v cava >/dev/null 2>&1; then
    echo "cava is required to run Cava Underbar." >&2
    notify-send "cava is required to run Cava Underbar."
    exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
    echo "socat is required to run Cava Underbar." >&2
    notify-send "socat is required to run Cava Underbar."
    exit 1
fi

# Main
APP_CLASS="cavaunderbar"
STATE_FILE="/tmp/cava_underbar_status"
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"

run_cava() {
    kitty --class="$APP_CLASS" \
          --config NONE \
          -o background_opacity=0 \
          -o background=#000000 \
          -o font_size=5 \
          -o window_padding_width=0 \
          -o hide_window_decorations=yes \
          -e cava -p ~/.config/cava/config_underbar &

    if pgrep -x "niri" > /dev/null; then
        niri-float-sticky -ipc set_sticky -app-id "cavaunderbar"
    fi
}

toggle_cava() {
    if pgrep -f "$APP_CLASS" > /dev/null; then
        pkill -f "$APP_CLASS" 
        echo "0" > "$STATE_FILE"
    else
        echo "1" > "$STATE_FILE"
        run_cava
    fi
}

if [[ "$1" == "--toggle" ]]; then
    toggle_cava
    exit 0
fi

# Check fullscreen, work around for Hyprland's fullscreen behavior
# Hyprland use pin cava_underbar window -> fullscreen window still shows it up
check_fullscreen() {
    local active_win=$(hyprctl activewindow -j)
    local fs_mode=$(echo "$active_win" | jq -r '.fullscreen')
    local is_manual_on=$(cat "$STATE_FILE")
    
    if [[ "$is_manual_on" == "1" ]]; then
        if [[ "$fs_mode" == "2" ]]; then
            if pgrep -f "$APP_CLASS" > /dev/null; then
                pkill -f "$APP_CLASS"
            fi
        else
            if ! pgrep -f "$APP_CLASS" > /dev/null; then
                run_cava
            fi
        fi
    fi
}

check_fullscreen

socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
    if [[ "$line" == "fullscreen>>"* ]] || [[ "$line" == "activewindow>>"* ]]; then
        sleep 0.5
        check_fullscreen 
    fi
done
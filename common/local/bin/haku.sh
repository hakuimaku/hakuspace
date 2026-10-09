#!/usr/bin/env bash

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 is required"; exit 1; }; }

# Check dependencies
need kitty
need cava
need tty-clock
need lavat
need jq

# Main
FONT_CLOCK=10
FONT_GENERAL=11
FONT_TERMINAL=16

spawn() { ( setsid "$@" & ) >/dev/null 2>&1; }

clear() {
    PIDS=$(pgrep -f "seycava|seylavat|seyclock|seycmd")

    for pid in $PIDS; do
        echo "Killing window with PID: $pid"
        kill -9 "$pid"
    done
}

cava() {
    spawn kitty --title "hakucava" --class "seycava" -o font_size=$FONT_GENERAL sh -c "cava"
    sleep 0.2
}

lavat() {
    spawn kitty --title "hakulavat" --class "seylavat" -o font_size=$FONT_GENERAL sh -c "lavat -c blue -k blue -r1"
    sleep 0.2
}

clock() {
    spawn kitty --title "hakuclock" --class "seyclock" -o font_size=$FONT_CLOCK sh -c "tty-clock -c -C 4 -r -b"
    sleep 0.2
}

cmd() {
    spawn kitty --title "hakucmd" --class "seycmd" -o font_size=$FONT_TERMINAL --hold fastfetch
    sleep 0.2
}


if [[ $1 == "--clear" ]]; then
    clear
    exit 0
fi

# Main
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    MY_INFO=$(hyprctl activewindow -j)
    MY_ADDR=$(echo "$MY_INFO" | jq -r '.pid')

    LAYOUT=$(hyprctl activeworkspace -j | jq -r '.tiledLayout')
    
    clear
    sleep 0.1

        
    hyprctl eval "hl.dispatch(hl.dsp.window.float({ window = 'pid:${MY_ADDR}' }))"
    hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = 600, y = 300, window = 'pid:${MY_ADDR}' }))"

    if [[ $LAYOUT == "scrolling" ]]; then
        cmd
        clock
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seyclock" }))'
        lavat
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seyclock" }))'
        hyprctl eval 'hl.dispatch(hl.dsp.layout("consume"))'
        cava
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seyclock" }))'
        hyprctl eval 'hl.dispatch(hl.dsp.layout("consume"))'
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seycmd" }))'
    elif [[ $LAYOUT == "dwindle" ]]; then
        clock
        cmd
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seyclock" }))'
        lavat
        hyprctl eval 'hl.dispatch(hl.dsp.window.move({ direction = "right", window = "class:seylavat" }))'
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seylavat" }))'
        cava
        hyprctl eval 'hl.dispatch(hl.dsp.window.move({ direction = "right", window = "class:seycava" }))'
        hyprctl eval 'hl.dispatch(hl.dsp.window.move({ direction = "up", window = "class:seylavat" }))'
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seycmd" }))'
    elif [[ $LAYOUT == "master" ]]; then
        cava
        lavat
        clock
        cmd
        hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:seycmd" }))'
    fi

    hyprctl eval "hl.dsp.exec_cmd('hyprctl keyword input:follow_mouse 1')"
    kill -9 "$MY_ADDR"
fi

if [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    MY_INFO=$(niri msg focused-window)
    MY_ADDR=$(echo "$MY_INFO" | grep "PID:" | awk '{print $2}')

    clear
    sleep 0.1

    cmd

    clock

    lavat
    niri msg action focus-column-left
    niri msg action consume-window-into-column
    
    cava
    niri msg action focus-column-left
    niri msg action consume-window-into-column

    niri msg action focus-column-left

    kill -9 "$MY_ADDR"
fi

if [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    MY_INFO=$(mmsg get focusing-client)
    MY_ADDR=$(echo "$MY_INFO" | jq -r '.pid // empty')

    clear
    sleep 0.05

    get_client_id_by_appid() {
        local appid="$1"
        mmsg get all-clients | jq -r --arg a "$appid" '
          (.clients // []) | map(select(.appid == $a)) | last | (.id // empty)
        '
    }

    wait_client_id_by_appid() {
        local appid="$1"
        local i id
        for ((i=0; i<50; i++)); do
            id="$(get_client_id_by_appid "$appid")"
            [[ -n "$id" && "$id" != "null" ]] && { echo "$id"; return 0; }
            sleep 0.02
        done
        return 1
    }

    stack_id() {
        local id="$1"
        local dir="${2:-right}"
        [[ -n "$id" ]] && mmsg dispatch scroller_stack,"$dir" client,"$id" >/dev/null 2>&1
    }

    cmd
    cmd_id="$(wait_client_id_by_appid "seycmd")"

    clock
    clock_id="$(wait_client_id_by_appid "seyclock")"

    lavat
    lavat_id="$(wait_client_id_by_appid "seylavat")"
    stack_id "$lavat_id" "left"
    sleep 0.2

    cava
    cava_id="$(wait_client_id_by_appid "seycava")"
    stack_id "$cava_id" "left"
    sleep 0.2

    kill -9 "$MY_ADDR"
fi
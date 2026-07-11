#!/bin/bash

# Check dependencies
if ! command -v kitty &> /dev/null; then
    echo "kitty is not installed. Please install it to run this script."
    exit 1
fi

if ! command -v cava &> /dev/null; then
    echo "cava is not installed. Please install it to run this script."
    exit 1
fi

if ! command -v tty-clock &> /dev/null; then
    echo "tty-clock is not installed. Please install it to run this script."
    exit 1
fi

if ! command -v lavat &> /dev/null; then
    echo "lavat is not installed. Please install it to run this script."
    exit 1
fi

# Main
FONT_CLOCK=10
FONT_GENERAL=12
FONT_TERMINAL=15

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
    
    clear
    sleep 0.1

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
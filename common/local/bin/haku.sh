#!/bin/bash

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

#!/bin/bash

FONT_CLOCK=10
FONT_GENERAL=12
FONT_TERMINAL=15

spawn() { ( setsid "$@" & ) >/dev/null 2>&1; }


if [[ $1 == "--clear" ]]; then
    PIDS=$(pgrep -f "seycava|seylavat|seyclock|seycmd")

    for pid in $PIDS; do
        echo "Killing window with PID: $pid"
        kill -9 "$pid"
    done
    exit 0
fi

if pgrep -x "Hyprland" > /dev/null; then
    hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "1" }))'

    MY_INFO=$(hyprctl activewindow -j)
    MY_ADDR=$(echo "$MY_INFO" | jq -r '.pid')
    TARGETS=$(hyprctl clients -j | jq -r --arg addr "$MY_ADDR" '.[] | select(.workspace.id == 1) | .pid')

    TARGETS=$(echo "$TARGETS" | grep -v "$MY_ADDR")
    for win in $TARGETS; do
        echo "Killing window with address: $win"
        kill -9 "$win"
    done
    sleep 0.1

    spawn kitty --title "hakucava" --class "seycava" -o font_size=$FONT_GENERAL sh -c "cava"
    sleep 0.1
    spawn kitty --title "hakulavat" --class "seylavat" -o font_size=$FONT_GENERAL sh -c "lavat -c blue -k blue -r1"
    sleep 0.1
    spawn kitty --title "hakuclock" --class "seyclock" -o font_size=$FONT_CLOCK sh -c "tty-clock -c -C 4 -r -b"
    sleep 0.1
    spawn kitty --title "hakucmd" --class "seycmd" -o font_size=$FONT_TERMINAL --hold fastfetch

    sleep 0.5
    kill -9 "$MY_ADDR"
fi

if pgrep -x "niri" > /dev/null; then
    MY_INFO=$(niri msg focused-window)
    MY_ADDR=$(echo "$MY_INFO" | grep "PID:" | awk '{print $2}')

    niri msg action focus-workspace 1

    spawn kitty --title "hakucmd" --class "seycmd" -o font_size=$FONT_TERMINAL --hold fastfetch
    sleep 0.2

    spawn kitty --title "hakuclock" --class "seyclock" -o font_size=$FONT_CLOCK sh -c "tty-clock -c -C 4 -r -b"

    sleep 0.2

    spawn kitty --title "hakulavat" --class "seylavat" -o font_size=$FONT_GENERAL sh -c "lavat -c blue -k blue -r1"
    sleep 0.2
    niri msg action focus-column-left
    niri msg action consume-window-into-column
    
    spawn kitty --title "hakucava" --class "seycava" -o font_size=$FONT_GENERAL sh -c "cava"
    sleep 0.2
    niri msg action focus-column-left
    niri msg action consume-window-into-column

    niri msg action focus-column-left

    kill -9 "$MY_ADDR"
fi

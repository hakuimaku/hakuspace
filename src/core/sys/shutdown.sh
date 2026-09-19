#!/usr/bin/env bash

# List options
options="󰒲

󰤆
󰤁
󱅞
󰩈"

# Design rofi
chosen=$(echo -e "$options" | rofi -dmenu -p "Shutdown" -i -theme "shutdown.rasi")

# List action
case $chosen in 
    *"󰒲"*) systemctl suspend ;;
    *""*) systemctl reboot ;;
    *"󰤆"*) systemctl poweroff ;;
    *"󰤁"*) systemctl hibernate ;;
    *"󱅞"*) ~/.local/bin/lock.sh ;;
    *"󰩈"*) ~/.local/bin/exit.sh ;;
esac
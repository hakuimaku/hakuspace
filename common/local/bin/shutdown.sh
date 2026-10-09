#!/bin/bash

exit() {
    if pgrep -x "Hyprland" > /dev/null; then
        hyprctl eval 'hl.dispatch(hl.dsp.exit())'
    elif pgrep -x "niri" > /dev/null; then
        pkill niri
    fi
}

# List options
options="󱠩 Hibernate
 Reboot
 Power Off
󰒲 Sleep
󱅞 Lock
󰩈 Exit"

# Design rofi
chosen=$(echo -e "$options" | rofi -dmenu -p "Shutdown" -i -theme-str 'window
{
    width: 30%;
    height: 50%;
}')

# List action
case $chosen in 
    *"Hibernate"*) systemctl hibernate ;;
    *"Reboot"*) systemctl reboot ;;
    *"Power Off"*) systemctl poweroff ;;
    *"Sleep"*) systemctl suspend ;;
    *"Lock"*) hyprlock ;;
    *"Exit"*) exit ;;
esac
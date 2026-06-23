#!/bin/bash

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
# Note: You should config hibernate manually
case $chosen in 
    *"Hibernate"*) systemctl hibernate ;;
    *"Reboot"*) systemctl reboot ;;
    *"Power Off"*) systemctl poweroff ;;
    *"Sleep"*) systemctl suspend ;;
    *"Lock"*) swaylock ;;
    *"Exit"*) pkill niri ;;
esac
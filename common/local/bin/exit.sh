#!/usr/bin/env bash

# This script handles exiting the current window manager

if ! rofi -dmenu -p "Are you sure you want to exit?" -theme-str 'window { width: 30%; height: 30%; } entry { placeholder: ""; }' <<< "Yes
No" | grep -q "Yes"; then
    exit 0
fi

# STOP SYSTEMD GRAPHICAL TARGETS FIRST
systemctl --user stop graphical-session.target 2>/dev/null
systemctl --user stop graphical-session-pre.target 2>/dev/null
systemctl --user stop xdg-desktop-portal.service 2>/dev/null

# APP LIST TO KILL
APP_LIST=(
    "code" "code-url-handler" "zen" "zen-bin" "firefox" "chromium" "kitty" "slurp"
    "waybar" "dockbar" "hypridle" "swaync" "sway-audio-idle-inhibit"
    "awww-daemon" "gammastep" "polkit-mate" "hyprsunset"
)
APP_PATTERN=$(IFS="|" ; echo "${APP_LIST[*]}")

pkill -SIGTERM -u "$USER" -f "$APP_PATTERN" 2>/dev/null
killall -q xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-gnome 2>/dev/null

# WAIT FOR DATA SAVING
sleep 1.5

# FORCE KILL STUBBORN PROCESSES
pkill -9 -u "$USER" -f "$APP_PATTERN" 2>/dev/null

# Note: Avoid manually killing Xwayland. The active compositor should manage and kill its own Xwayland instance.
# pkill -SIGTERM -u "$USER" -x "Xwayland" 2>/dev/null

# CLEANUP LOCKS AND SPECIFIC SOCKETS
rm -f /tmp/.X11-unix/X* 2>/dev/null
rm -f /tmp/.X*-lock 2>/dev/null
rm -rf /tmp/hypr /tmp/niri* /tmp/sway* /tmp/waybar* /tmp/steam* 2>/dev/null

# UNSET ENVIRONMENT VARIABLES
systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP 2>/dev/null

# EXIT CURRENT WINDOW MANAGER
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
elif [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action quit --skip-confirmation
elif [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    mmsg dispatch quit
elif [[ $XDG_CURRENT_DESKTOP == "labwc"  ]]; then
    labwc --exit
fi
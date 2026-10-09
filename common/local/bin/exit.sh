#!/usr/bin/env bash

# This script handles exiting the current window manager

# Confirm exit
if ! rofi -dmenu -p "Are you sure you want to exit?" -theme-str 'window { width: 30%; height: 30%; } entry { placeholder: ""; }' <<< "Yes
No" | grep -q "Yes"; then
    exit 0
fi

# 1. Clean up running applications
APP_LIST=(
    "code" "code-url-handler" "zen" "zen-bin" "firefox" "chromium" "kitty" "slurp"
    "waybar" "dockbar" "hypridle" "swaync" "sway-audio-idle-inhibit"
    "awww-daemon" "gammastep" "polkit-mate" "hyprsunset"
)
APP_PATTERN=$(IFS="|" ; echo "${APP_LIST[*]}")

pkill -SIGTERM -u "$USER" -f "$APP_PATTERN" 2>/dev/null
killall -q xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-gnome 2>/dev/null

sleep 0.3
pkill -9 -u "$USER" -f "$APP_PATTERN" 2>/dev/null

pkill -SIGTERM -u "$USER" -x "Xwayland" 2>/dev/null
rm -f /tmp/.X11-unix/X* 2>/dev/null

# Exit current window manager
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
elif [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action quit --skip-confirmation
elif [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    mmsg dispatch quit
elif [[ $XDG_CURRENT_DESKTOP == "labwc"  ]]; then
    labwc --exit
fi

# Stop the graphical session
systemctl --user stop graphical-session.target 2>/dev/null
systemctl --user stop graphical-session-pre.target 2>/dev/null

# Unset environment variables
systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP 2>/dev/null

# Clean /tmp directory
rm -rf /tmp/.X11-unix /tmp/.X*-lock 2>/dev/null
rm -rf /tmp/hypr /tmp/niri* /tmp/sway* /tmp/waybar* /tmp/steam* 2>/dev/null
find /tmp -maxdepth 1 -user "$USER" ! -name "." -exec rm -rf {} + 2>/dev/null
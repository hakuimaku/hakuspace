#!/usr/bin/env bash

# This script is designed to safely exit the current window manager
# If you see some apps still running after the exit (These will take a lot of RAM when login again)
# You can add them to the APP_LIST array below for graceful and force kill sequence

# Targeted apps for graceful and force kill sequence
APP_LIST=(
    "code" "code-url-handler" "zen" "zen-bin" "firefox" "chromium" "kitty" "slurp"
    "waybar" "dockbar" "hypridle" "swaync" "sway-audio-idle-inhibit"
    "awww-daemon" "gammastep" "polkit-mate" "hyprsunset"
)
APP_PATTERN=$(IFS="|" ; echo "${APP_LIST[*]}")

# Threshold for RAM warning (in Megabytes)
RAM_THRESHOLD_MB=300

get_process_list() {
    ps -u "$USER" -o rss,comm | awk -v limit="$RAM_THRESHOLD_MB" '
    {
        if ($1 == "RSS") next;
        rss = $1; comm = $2;
        
        # Aggregate RSS memory and process count per application command
        ram_sum[comm] += rss;
        count[comm]++;
    }
    END {
        for (app in ram_sum) {
            ram_mb = ram_sum[app] / 1024;
            status = (ram_mb >= limit) ? "[HIGH RAM]" : "[Active]";
            # Print formatted output: RAM_MB | Format_String
            printf "%010.2f |    • %-22s | %-3s pids | %-8.1f MB %s\n", ram_mb, app, count[app], ram_mb, status;
        }
    }' | sort -rn -k1,1 | cut -d'|' -f2-
}

# Rofi menu for user confirmation before proceeding with the exit sequence
MENU_OPTIONS=$(cat <<EOF
[!] EXIT ANYWAY (Force Close All)
[X] CANCEL (Press ESC)
--- ALL PROCESSES (SORTED BY RAM USAGE) ---
$(get_process_list)
EOF
)

SELECTION=$(echo "$MENU_OPTIONS" | rofi -dmenu \
    -p "System Monitor" \
    -theme-str 'window { width: 55%; height: 60%; } entry { placeholder: "Select option or press ESC to cancel..."; }' \
    -selected-row 0)

# If user cancels or hits ESC
if [[ ! "$SELECTION" =~ ^\[!\] ]]; then
    echo "Exit sequence cancelled by user."
    exit 0
fi

# Main Exit Sequence
# Graceful kill
pkill -SIGTERM -u "$USER" -f "$APP_PATTERN" 2>/dev/null
killall -q xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-gnome 2>/dev/null

sleep 1.5

# Force kill stubborn background processes
pkill -9 -u "$USER" -f "$APP_PATTERN" 2>/dev/null

# Clean sockets and lock files
rm -f /tmp/.X11-unix/X* 2>/dev/null
rm -f /tmp/.X*-lock 2>/dev/null
rm -rf /tmp/hypr /tmp/niri* /tmp/sway* /tmp/waybar* 2>/dev/null

# Unset environment variables
systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP 2>/dev/null

systemctl --user stop graphical-session.target 2>/dev/null
systemctl --user stop graphical-session-pre.target 2>/dev/null
systemctl --user stop xdg-desktop-portal.service 2>/dev/null

# Exit WM
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl eval 'hl.dispatch(hl.dsp.exit())'
elif [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action quit --skip-confirmation
elif [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    mmsg dispatch quit
elif [[ $XDG_CURRENT_DESKTOP == "labwc" ]]; then
    labwc --exit
fi
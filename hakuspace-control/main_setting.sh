#!/usr/bin/env bash

# This script is used to set up the main settings for all hakuspace's scripts.
# DO NOT EDIT THIS LINE :v, used for check main_setting.sh up-to-date when run update.sh
SETTING_VERSION="2.2.2"
echo "Hakuspace Control Settings Version: $SETTING_VERSION"

# General Settings
NIGHT_LIGHT_TEMPERATURE=4000
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Niri use screenshot built-in, so SCREENSHOT_DIR is not used in Niri, you can customize it in ~/hakuspace-control/niri-custom.kdl
# But if you want to use my screenshot script, just add keybind for that

# Wallpaper Settings
WALL_DIR="$HOME/Pictures/Wallpapers"
WALL_MPV_DIR="$HOME/Videos/Wallpapers" # For lively wallpaper videos
PREVIEW_DIR="$WALL_MPV_DIR/Preview" # For lively wallpaper thumbnail previews
BACKDROP_DIR="$HOME/.cache" # For Niri only
WALL_INTERVAL=300 # Interval in seconds for random wallpaper changes
ACCENT_COLOR_BASED_ON_WALLPAPER=true
AWWW_OPTS="--transition-type random --transition-step 90 --transition-fps 60" # Options for awww transition

# Screen Recording Settings
SCREENREC_SAVE_DIR="$HOME/Videos"
#REC_COMMAND="$HOME/.cargo/bin/wl-screenrec" # If you install wl-screenrec by cargo, uncomment the following line and comment the next one
REC_COMMAND="wl-screenrec" # Default command for wl-screenrec, ensure it's in your PATH
REC_OPTS="--max-fps 60 --codec avc --encode-pixfmt nv12" # wl-screenrec options, you can customize them as needed

# Waybar Theme Settings
# Add your custom Waybar modes here, e.g., ("custom1" "custom2")
# You just add your waybar config to ~/hakuspace-control/waybar with `config` and `style.css` files.
# If name between WAYBAR_MODES_DEAULT and WAYBAR_MODE_USER is the same, WAYBAR_MODE_DEAULT (my theme) will be used.
# Example: WAYBAR_MODE_USER=("custom1"), have ~/hakuspace-control/waybar/custom1/config and ~/hakuspace-control/waybar/custom1/style.css
WAYBAR_MODE_USER=()

# Rofi Theme Settings
# You just add your theme "name.rasi" to the ~/hakuspace-control/rofi folder, and switch to it in Haku Menu (Theme tab)

# Haku Idle Space Settings (haku.sh)
HAKU_CLOCK_FONT_SIZE=10
HAKU_GENERAL_FONT_SIZE=11
HAKU_TERMINAL_FONT_SIZE=14

# Exit Settings (exit.sh)
# Threshold for RAM warning (in Megabytes)
RAM_THRESHOLD_MB=300
# Targeted apps for graceful and force kill sequence when exiting WM
# Example: EXIT_APP_LIST_USER=("discord" "firefox" "code")
EXIT_APP_LIST_USER=()

#!/usr/bin/env bash

# This script is used to set up the main settings for all hakuspace's scripts.
# DO NOT EDIT THIS LINE :v, used for checking setting.sh is up-to-date when run update.sh
SETTING_VERSION="26.12-1"

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "$SETTING_VERSION"
    exit 0
fi

# ====== General Settings ======
# Show welcome message on startup :)
WELCOME_MSG=true

NIGHT_LIGHT_TEMPERATURE=4000
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Niri use screenshot built-in, so SCREENSHOT_DIR is not used in Niri, you can customize it in ~/hakucfg/wm/niri-custom.kdl
# But if you want to use my screenshot script, just add keybind for that



# ====== Wallpaper Settings ======
WALL_DIR="$HOME/Pictures/Wallpapers"
WALL_MPV_DIR="$HOME/Videos/Wallpapers" # For lively wallpaper videos
WALL_INTERVAL=300 # Interval in seconds for random wallpaper changes
ACCENT_COLOR_BASED_ON_WALLPAPER=true
AWWW_OPTS="--transition-type random --transition-step 90 --transition-fps 60" # Options for awww transition

# Accent extraction: vivid, dominant, brightest, or saturated.
# - vivid: Most vivid color
# - dominant: Dominant color
# - brightest: Brightest color
# - saturated: Most saturated color
ACCENT_COLOR_MODE="vivid"



# ====== Screen Recording Settings ======
SCREENREC_SAVE_DIR="$HOME/Videos"

# Default command for gpu-screen-recorder, ensure it's in your PATH
REC_COMMAND="gpu-screen-recorder"

REC_OPTS="-f 60" # gpu-screen-recorder options, you can customize them as needed



# ====== Wallpaper Preview Cache Settings ======
# If you have issues with rofi wallpaper preview images (too lowres, dupe images,...), you can try to change them.
# What do they do? These are ImageMagick options used to generate cached wallpaper previews.
# Works best with wallpapers that have the subject in the center.
# Change the options below to your liking, or leave them as default.
# Previews live in ${XDG_CACHE_HOME:-$HOME/.cache}/hakuspace/wallpaper/; change wallpaper to regenerate them.

# GEN_WIDE_OPTS=${GEN_WIDE_OPTS:-"-resize 800x250^ -gravity Center -crop 800x250+0+0 +repage"}
# GEN_BOX_OPTS=${GEN_BOX_OPTS:-"-resize 1653x852^ -gravity Center -extent 1653x852 -gravity NorthWest -crop 1212x852+400+0 +repage"}



# ====== Haku Idle Space Settings (haku.sh) ======
HAKU_CLOCK_FONT_SIZE=10
HAKU_GENERAL_FONT_SIZE=11
HAKU_TERMINAL_FONT_SIZE=14



# ====== Exit Settings (exit.sh) ======
# Threshold for RAM warning (in Megabytes)
RAM_THRESHOLD_MB=300
# Targeted apps for graceful and force kill sequence when exiting WM
# Example: EXIT_APP_LIST_USER=("discord" "firefox" "code")
EXIT_APP_LIST_USER=()


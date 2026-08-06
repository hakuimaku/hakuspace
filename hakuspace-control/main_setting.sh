#!/usr/bin/env bash

# This script is used to set up the main settings for all hakuspace's scripts.
# DO NOT MOVE THIS FILE OR FOLDER, ~/hakuspace-control
# Global variables

# General Settings
NIGHT_LIGHT_TEMPERATURE=4000
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Waybar Settings
# Add your custom Waybar modes here, e.g., ("custom1" "custom2")
# These modes should correspond to directories in ~/.config/waybar/
# MUST have corresponding ~/.config/waybar/custom1/config and ~/.config/waybar/custom1/style.css files
# Well, after run update dotfiles, your config & style.css will be missing, restore them from the backup folder in $HOME
WAYBAR_MODE_USER=()

# Wallpaper Settings
WALL_DIR="$HOME/Pictures/Wallpapers"
WALL_MPV_DIR="$HOME/Videos/Wallpapers" # For lively wallpaper videos
PREVIEW_DIR="$WALL_MPV_DIR/Preview" # For lively wallpaper thumbnail previews
BACKDROP_DIR="/tmp" # For Niri only
WALL_INTERVAL=300 # Interval in seconds for random wallpaper changes

# Screen Recording Settings
SCREENREC_SAVE_DIR="$HOME/Videos"
#REC_COMMAND="$HOME/.cargo/bin/wl-screenrec" # If you install wl-screenrec by cargo, uncomment the following line and comment the next one
REC_COMMAND="wl-screenrec" # Default command for wl-screenrec, ensure it's in your PATH
REC_OPTS="--max-fps 60 --codec avc --encode-pixfmt nv12" # wl-screenrec options, you can customize them as needed

# Gen Style script (gen_style.sh)
# Defaults variables
DEFAULT_ACCENT="#ffffff"
DEFAULT_FONT="monospace"
DEFAULT_SIZE="14"

# Haku Idle Space Settings (haku.sh)
HAKU_CLOCK_FONT_SIZE=10
HAKU_GENERAL_FONT_SIZE=11
HAKU_TERMINAL_FONT_SIZE=14

# Exit Settings (exit.sh)
# Threshold for RAM warning (in Megabytes)
RAM_THRESHOLD_MB=300
# Targeted apps for graceful and force kill sequence
# Example: EXIT_APP_LIST_USER=("discord" "firefox" "code")
EXIT_APP_LIST_USER=()
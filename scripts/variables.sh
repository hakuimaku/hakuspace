#!/usr/bin/env bash

# Directories
SOURCE_DIR="$HAKU_DIR/src"
HOME_SRC_DIR="$SOURCE_DIR/home"
ASSETS_DIR="$HAKU_DIR/assets"
NIX_DIR="$HAKU_DIR/nix"

# Backup directory with timestamp
BACKUP_TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$HOME/.backup/Backup_$BACKUP_TS"

# Arrays to handle multiple WMs
SELECTED_WMS=()
SELECTED_WM_DIRS=()
SELECTED_PKG_WMS=()

# Package lists
PKG_SERVICE="$SOURCE_DIR/packages/pkg-service.txt"
PKG_CORE="$SOURCE_DIR/packages/pkg-core.txt"
PKG_OPTIONAL="$SOURCE_DIR/packages/pkg-optional.txt"
PKG_HYPRLAND="$SOURCE_DIR/packages/pkg-hyprland.txt"
PKG_NIRI="$SOURCE_DIR/packages/pkg-niri.txt"
PKG_MANGO="$SOURCE_DIR/packages/pkg-mango.txt"
PKG_LABWC="$SOURCE_DIR/packages/pkg-labwc.txt"

# hakuspace-archive repo URL and directory
ARCHIVE_REPO_URL="https://github.com/hakuimaku/hakuspace-archive.git"
ARCHIVE_DIR="$HOME/hakuspace-archive"

# hakuspace-control directory
HAKUSPACE_CONTROL_DIR="$HOME_SRC_DIR/hakuspace-control"
DEST_CONTROL_DIR="$HOME/hakuspace-control"

# Config Directories
SOURCE_CONFIG="$HOME_SRC_DIR/.config"
DEST_CONFIG="$HOME/.config"

# Once configs (to be deployed only once)
# update.sh will skip these configs, for not overwriting user changes
ONCE_CONFIGS=(
    "$SOURCE_CONFIG/Thunar"
    "$SOURCE_CONFIG/xfce4"
    "$SOURCE_CONFIG/mpv"
    "$SOURCE_CONFIG/btop"
)

# Skip configs (to be skipped during install.sh and update.sh)
# Not deloyed together with the rest of the configs in $SOURCE_CONFIG
SKIP_CONFIGS=(
    "$SOURCE_CONFIG/hypr"
    "$SOURCE_CONFIG/niri"
    "$SOURCE_CONFIG/mango"
    "$SOURCE_CONFIG/labwc"
    "$SOURCE_CONFIG/gtk-3.0"
)
    
# Bin Directories
SOURCE_BIN="$HOME_SRC_DIR/.local/bin"
DEST_BIN="$HOME/.local/bin"
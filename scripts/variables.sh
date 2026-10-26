#!/usr/bin/env bash

# Resolve HAKU_DIR if not set
if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

# Static Directories
SOURCE_DIR="$HAKU_DIR/src"
HOME_SRC_DIR="$SOURCE_DIR/home"
ASSETS_DIR="$HAKU_DIR/assets"
NIX_DIR="$HAKU_DIR/nix"

# Package lists
PKG_SERVICE="$SOURCE_DIR/packages/pkg-service.txt"
PKG_CORE="$SOURCE_DIR/packages/pkg-core.txt"
PKG_OPTIONAL="$SOURCE_DIR/packages/pkg-optional.txt"
PKG_HYPRLAND="$SOURCE_DIR/packages/pkg-hyprland.txt"
PKG_NIRI="$SOURCE_DIR/packages/pkg-niri.txt"
PKG_MANGO="$SOURCE_DIR/packages/pkg-mango.txt"
PKG_LABWC="$SOURCE_DIR/packages/pkg-labwc.txt"

# Visual downloads are temporary; configured development sources may live anywhere.
HAKU_CURSOR_REPO_URL="https://github.com/hakuimaku/haku-cursor.git"
HAKU_GTK_REPO_URL="https://github.com/hakuimaku/hikade-gtk-theme.git"
HAKU_SYMBOLS_REPO_URL="https://github.com/hakuimaku/hikaide-symbols.git"

# Wallpaper archive only; visual software is managed by setup.sh.
ARCHIVE_REPO_URL="https://github.com/hakuimaku/hakuspace-archive.git"
ARCHIVE_DIR="${HAKUSPACE_ARCHIVE_SOURCE:-$HOME/hakuspace-archive}"

# User custom configuration directory
HAKUSPACE_CUSTOM_DIR="$HOME_SRC_DIR/hakucfg"
DEST_CUSTOM_DIR="$HOME/hakucfg"

# Config Directories
SOURCE_CONFIG="$HOME_SRC_DIR/.config"
DEST_CONFIG="$HOME/.config"

# HakuSpace script directories
SOURCE_CORE="$SOURCE_DIR/core"
DEST_BIN="$HOME/.local/bin"

# Arrays to handle multiple WMs (default empty for set -u safety)
SELECTED_WMS=("${SELECTED_WMS[@]:-}")
SELECTED_WM_DIRS=("${SELECTED_WM_DIRS[@]:-}")
SELECTED_PKG_WMS=("${SELECTED_PKG_WMS[@]:-}")

# Source runtime context (shared run ID and backup directory)
source "$HAKU_DIR/scripts/runtime.sh"

# Source registry (single source of truth for managed targets and ONCE_CONFIGS)
source "$HAKU_DIR/scripts/registry.sh"

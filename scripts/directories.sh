#!/usr/bin/env bash
# HakuSpace Necessary Directories Creation Module
# Ensures base directories exist (~/.config, ~/.icons, ~/.themes, ~/Pictures/Wallpapers, ~/Pictures/Screenshots)

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"

create_directories() {
    log_info "Creating necessary directories..."

    local folders=(
        "$HOME/.config"
        "$HOME/.icons"
        "$HOME/.themes"
        "$HOME/Pictures/Wallpapers"
        "$HOME/Pictures/Screenshots"
    )

    for folder in "${folders[@]}"; do
        ensure_dir "$folder"
    done

    log_ok "All necessary directories created."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    create_directories
fi

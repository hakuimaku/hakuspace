#!/usr/bin/env bash
# HakuSpace Legacy Copy Deployment Module
# Preserves existing file-copy deployment semantics without alteration.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"
source "$HAKU_DIR/scripts/runtime.sh"
source "$HAKU_DIR/scripts/registry.sh"

copy_item() {
    local src="$1"
    local dst="$2"
    local skip_backup="${3:-0}"

    if [[ -d "$src" ]]; then
        copy_dir_content "$src" "$dst" "$skip_backup"
    else
        copy_file "$src" "$dst" "$skip_backup"
    fi
}

copy_wm_configs() {
    local wm="$1"
    case "$wm" in
        hyprland)
            log_info "Deploying Hyprland configs (copy)..."
            copy_item "$SOURCE_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config"
            copy_item "$SOURCE_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
            ;;
        niri)
            log_info "Deploying Niri configs (copy)..."
            copy_item "$SOURCE_CONFIG/niri" "$DEST_CONFIG/niri"
            ;;
        mango)
            log_info "Deploying Mango configs (copy)..."
            copy_item "$SOURCE_CONFIG/mango" "$DEST_CONFIG/mango"
            ;;
        labwc)
            log_info "Deploying Labwc configs (copy)..."
            copy_item "$SOURCE_CONFIG/labwc" "$DEST_CONFIG/labwc"
            if [[ ! -d "$HOME/.themes/hakulab" && -d "$HOME_SRC_DIR/.themes/hakulab" ]]; then
                log_info "Deploying Hakulab theme for Labwc..."
                copy_dir_content "$HOME_SRC_DIR/.themes/hakulab" "$HOME/.themes/hakulab"
            fi
            ;;
        *)
            log_warn "Unknown WM: $wm. Skipping copy."
            ;;
    esac
}

deploy_copy_all() {
    local wms=("$@")

    log_info "Deploying base configs via copy..."
    while IFS='|' read -r src dst; do
        [[ -z "$src" ]] && continue
        copy_item "$src" "$dst"
    done < <(registry_get_common_configs)

    for wm in "${wms[@]}"; do
        copy_wm_configs "$wm"
    done

    # Deploy core scripts in copy mode
    "$HAKU_DIR/scripts/core.sh" --mode copy

    log_ok "Legacy copy deployment completed."
}

# CLI Entrypoint
ACTION="${1:-install}"
shift || true

case "$ACTION" in
    install|update)
        deploy_copy_all "$@"
        ;;
    config)
        copy_item "$1" "$2"
        ;;
    --help|-h)
        echo "Usage: $0 [install|update <wm1> <wm2>...] | [config <src> <dst>]"
        exit 0
        ;;
    *)
        deploy_copy_all "$ACTION" "$@"
        ;;
esac

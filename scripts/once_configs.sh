#!/usr/bin/env bash
# HakuSpace Once-Configs Deployment Module
# Deploys user configs that should only ever be copied once during initial installation.
# Never symlinks; never executed by update.sh.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"
source "$HAKU_DIR/scripts/runtime.sh"
source "$HAKU_DIR/scripts/registry.sh"

deploy_once_configs() {
    local skip_backup="${1:-0}"

    log_info "Deploying ONCE configs (Thunar, xfce4, mpv, btop, cava, mimeapps.list)..."

    while IFS='|' read -r src dst; do
        [[ -e "$src" ]] || continue
        if [[ -d "$src" ]]; then
            copy_dir_content "$src" "$dst" "$skip_backup"
        else
            copy_file "$src" "$dst" "$skip_backup"
        fi
    done < <(registry_get_once_configs)

    log_ok "ONCE configs deployed successfully."
}

# CLI Entrypoint
SKIP_BACKUP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-backup)
            SKIP_BACKUP=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--skip-backup]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_once_configs "$SKIP_BACKUP"
fi

#!/usr/bin/env bash
# Copy missing wallpapers from a fresh shallow clone of the static archive.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

cleanup_archive_checkout() {
    if [[ -z "${HAKUSPACE_ARCHIVE_SOURCE:-}" && -n "${ARCHIVE_DIR:-}" && "$ARCHIVE_DIR" != "/" && "$ARCHIVE_DIR" != "$HOME" ]]; then
        rm -rf -- "$ARCHIVE_DIR"
    fi
}

deploy_assets() {
    local dry_run="${1:-0}"

    if [[ "$dry_run" -eq 1 ]]; then
        log_info "DRY RUN: replace $ARCHIVE_DIR from $ARCHIVE_REPO_URL and copy missing wallpapers to $HOME/Pictures/Wallpapers"
        return 0
    fi

    if [[ -n "${HAKUSPACE_ARCHIVE_SOURCE:-}" ]]; then
        [[ -d "$ARCHIVE_DIR" ]] || { log_error "Archive override not found: $ARCHIVE_DIR"; return 1; }
    else
        if ! command -v git >/dev/null 2>&1; then
            log_error "git is required to clone $ARCHIVE_REPO_URL"
            return 1
        fi
        [[ -n "$ARCHIVE_DIR" && "$ARCHIVE_DIR" != "/" && "$ARCHIVE_DIR" != "$HOME" ]] || {
            log_error "Refusing unsafe archive directory: $ARCHIVE_DIR"
            return 1
        }
        trap cleanup_archive_checkout EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        rm -rf -- "$ARCHIVE_DIR" || return 1
        log_info "Cloning archive repo..."
        git clone --depth 1 "$ARCHIVE_REPO_URL" "$ARCHIVE_DIR" || return 1
    fi

    if [[ ! -d "$ARCHIVE_DIR/Wallpapers" ]]; then
        log_error "Wallpapers directory not found in $ARCHIVE_DIR"
        return 1
    fi
    mkdir -p "$HOME/Pictures/Wallpapers" || return 1
    cp -an -- "$ARCHIVE_DIR/Wallpapers/." "$HOME/Pictures/Wallpapers/" || return 1
    cleanup_archive_checkout
}

# CLI Entrypoint
DRY_RUN=0

case "${1:-}" in
    --dry-run)
        deploy_assets 1
        ;;
    --help|-h)
        echo "Usage: $0 [--dry-run]"
        exit 0
        ;;
    *)
        deploy_assets 0
        ;;
esac

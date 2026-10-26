#!/usr/bin/env bash
# HakuSpace Assets Deployment Module
# Clones or updates hakuspace-archive repository (wallpapers, icons, themes) and runs setup.sh.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

deploy_assets() {
    local dry_run="${1:-0}"

    if [[ "$dry_run" -eq 1 ]]; then
        log_info "DRY RUN: would deploy assets from $ARCHIVE_REPO_URL to $ARCHIVE_DIR"
        log_info "DRY RUN: install Haku Cursor, Hikaide, Hikaide-Light, Hikaide-Symbols, Hikaide-Symbols-Light and wallpapers"
        log_info "DRY RUN: verify/activate appearance, apply canonical theme and reconcile icon accent"
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required to clone $ARCHIVE_REPO_URL"
        return 1
    fi

    if [[ -n "${HAKUSPACE_ARCHIVE_SOURCE:-}" ]]; then
        [[ -d "$ARCHIVE_DIR" ]] || { log_error "Archive override not found: $ARCHIVE_DIR"; return 1; }
    elif [[ -d "$ARCHIVE_DIR/.git" && ! -L "$ARCHIVE_DIR" ]]; then
        if [[ -n "$(git -C "$ARCHIVE_DIR" status --porcelain)" ]]; then
            log_error "Dirty archive checkout; leaving untouched: $ARCHIVE_DIR"
            return 1
        fi
        log_info "Updating archive checkout..."
        git -C "$ARCHIVE_DIR" pull --ff-only || return 1
    elif [[ -e "$ARCHIVE_DIR" || -L "$ARCHIVE_DIR" ]]; then
        log_error "Refusing to replace non-checkout: $ARCHIVE_DIR"
        return 1
    else
        log_info "Cloning archive repo..."
        git clone --depth 1 "$ARCHIVE_REPO_URL" "$ARCHIVE_DIR" || return 1
    fi

    if [[ ! -f "$ARCHIVE_DIR/setup.sh" ]]; then
        log_error "setup.sh not found in $ARCHIVE_DIR"
        return 1
    fi

    log_info "Running archive setup script..."
    export PATH="$HOME/.local/bin:$PATH"
    bash "$ARCHIVE_DIR/setup.sh" || return 1
    "$SOURCE_CORE/backend/theme/appearance_ctl.sh" verify || return 1
    "$SOURCE_CORE/backend/theme/appearance_ctl.sh" apply || return 1
    "$SOURCE_CORE/backend/theme/theme_ctl.sh" apply
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

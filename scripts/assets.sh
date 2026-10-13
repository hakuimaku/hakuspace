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
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required to clone $ARCHIVE_REPO_URL"
        return 1
    fi

    if [[ -d "$ARCHIVE_DIR/.git" ]]; then
        log_info "Archive repo already exists. Pulling latest changes..."
        if ! git -C "$ARCHIVE_DIR" pull --ff-only; then
            log_error "Failed to update $ARCHIVE_DIR"
            return 1
        fi
    else
        if [[ -d "$ARCHIVE_DIR" ]]; then
            log_warn "$ARCHIVE_DIR exists but is not a git repo."
            if ask_yes_no "===> Remove and re-clone hakuspace-archive?"; then
                rm -rf "$ARCHIVE_DIR"
            else
                log_warn "Cannot continue archive deployment without a valid repo."
                return 1
            fi
        fi

        log_info "Cloning archive repo..."
        if ! git clone "$ARCHIVE_REPO_URL" "$ARCHIVE_DIR"; then
            log_error "Failed to clone $ARCHIVE_REPO_URL"
            return 1
        fi
    fi

    if [[ ! -f "$ARCHIVE_DIR/setup.sh" ]]; then
        log_error "setup.sh not found in $ARCHIVE_DIR"
        return 1
    fi

    chmod +x "$ARCHIVE_DIR/setup.sh"
    log_info "Running archive setup script..."
    (cd "$ARCHIVE_DIR" && ./setup.sh)
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

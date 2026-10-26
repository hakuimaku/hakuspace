#!/usr/bin/env bash
# Copy missing wallpapers from the independent static archive checkout.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

deploy_assets() {
    local dry_run="${1:-0}"

    if [[ "$dry_run" -eq 1 ]]; then
        log_info "DRY RUN: update wallpaper archive from $ARCHIVE_REPO_URL at $ARCHIVE_DIR"
        log_info "DRY RUN: copy missing wallpapers to $HOME/Pictures/Wallpapers"
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required to clone $ARCHIVE_REPO_URL"
        return 1
    fi

    if [[ -n "${HAKUSPACE_ARCHIVE_SOURCE:-}" ]]; then
        [[ -d "$ARCHIVE_DIR" ]] || { log_error "Archive override not found: $ARCHIVE_DIR"; return 1; }
    elif [[ -d "$ARCHIVE_DIR/.git" && ! -L "$ARCHIVE_DIR" && ! -L "$ARCHIVE_DIR/.git" ]]; then
        local origin top changes
        top="$(git -C "$ARCHIVE_DIR" rev-parse --show-toplevel)" || return 1
        [[ "$top" == "$(cd "$ARCHIVE_DIR" && pwd -P)" ]] || { log_error "Not an independent archive checkout"; return 1; }
        origin="$(git -C "$ARCHIVE_DIR" config --get remote.origin.url)" || return 1
        [[ "$origin" == "$ARCHIVE_REPO_URL" ]] || { log_error "Wrong archive origin: $origin"; return 1; }
        changes="$(git -C "$ARCHIVE_DIR" status --porcelain)" || return 1
        if [[ -n "$changes" ]]; then
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

    if [[ ! -d "$ARCHIVE_DIR/Wallpapers" ]]; then
        log_error "Wallpapers directory not found in $ARCHIVE_DIR"
        return 1
    fi
    mkdir -p "$HOME/Pictures/Wallpapers" || return 1
    cp -an -- "$ARCHIVE_DIR/Wallpapers/." "$HOME/Pictures/Wallpapers/"
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

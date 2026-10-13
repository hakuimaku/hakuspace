#!/usr/bin/env bash
# HakuSpace Desktop Defaults Module
# Applies default desktop preferences (GNOME dark theme, default file manager).

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

apply_desktop_defaults() {
    local dry_run="${1:-0}"

    if [[ "$dry_run" -eq 1 ]]; then
        log_info "DRY RUN: would configure GNOME color-scheme and Thunar xdg-mime"
        return 0
    fi

    # Set GNOME dark color scheme
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        log_ok "Set GNOME color scheme to prefer-dark."
    else
        log_warn "gsettings not available. Skipping GNOME color scheme setup."
    fi

    # Set Thunar as default file manager
    if command -v thunar >/dev/null 2>&1 && command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default thunar.desktop inode/directory 2>/dev/null || true
        log_ok "Set Thunar as default file manager."
    else
        log_warn "Thunar or xdg-mime not available. Skipping default file manager setup."
    fi
}

case "${1:-}" in
    --dry-run)
        apply_desktop_defaults 1
        ;;
    --help|-h)
        echo "Usage: $0 [--dry-run]"
        exit 0
        ;;
    *)
        apply_desktop_defaults 0
        ;;
esac

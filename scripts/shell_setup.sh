#!/usr/bin/env bash
# HakuSpace Fish Shell Setup Module
# Ensures Fish is registered in /etc/shells and set as default login shell.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

shell_check() {
    if ! command -v fish >/dev/null 2>&1; then
        log_warn "Fish shell is not installed."
        return 1
    fi

    local fish_path
    fish_path="$(command -v fish)"
    if [[ "${SHELL:-}" == "$fish_path" ]]; then
        log_ok "Fish is default shell ($fish_path)."
        return 0
    else
        log_info "Fish is installed ($fish_path), but not default (current: ${SHELL:-none})."
        return 1
    fi
}

setup_fish() {
    local dry_run="${1:-0}"

    if ! command -v fish >/dev/null 2>&1; then
        log_warn "Fish shell is not installed. Skipping shell change."
        return 0
    fi

    local fish_path
    fish_path="$(command -v fish)"

    if [[ "$dry_run" -eq 1 ]]; then
        log_info "DRY RUN: would register $fish_path and run chsh"
        return 0
    fi

    if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
        log_info "Adding $fish_path to /etc/shells..."
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi

    if [[ "${SHELL:-}" != "$fish_path" ]]; then
        log_info "Changing default shell for $USER to $fish_path..."
        chsh -s "$fish_path" "$USER"
        log_ok "Changed default shell to fish ($fish_path)."
    else
        log_skip "Fish is already your default shell."
    fi
}

# CLI Entrypoint
case "${1:-}" in
    --check)
        shell_check
        ;;
    --dry-run)
        setup_fish 1
        ;;
    --help|-h)
        echo "Usage: $0 [--check | --dry-run]"
        exit 0
        ;;
    *)
        setup_fish 0
        ;;
esac

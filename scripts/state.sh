#!/usr/bin/env bash
# HakuSpace State Management Module
# Manages ~/.local/state/hakuspace runtime state files.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"
source "$HAKU_DIR/scripts/registry.sh"

source "$SOURCE_CORE/lib/haku_state.sh"
HAKU_RUNTIME_STATE_DIR="$HAKU_STATE_DIR"
HAKU_THEME_RENDER_DIR="$HAKU_STATE_ROOT/theme"
SRC_STATE_ROOT="$HOME_SRC_DIR/.local/state/hakuspace"

state_check() {
    local missing=0
    if [[ ! -d "$HAKU_STATE_ROOT" ]]; then
        log_warn "State directory does not exist: $(shorten_path "$HAKU_STATE_ROOT")"
        return 1
    fi

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ ! -f "$HAKU_STATE_ROOT/$file" ]]; then
            log_warn "Missing state file: $(shorten_path "$HAKU_STATE_ROOT/$file")"
            missing=$((missing + 1))
        fi
    done < <(registry_get_state_files)

    if [[ $missing -eq 0 ]]; then
        log_ok "State directory and files are healthy."
        return 0
    else
        return 1
    fi
}

state_init() {
    log_info "Initializing HakuSpace state directory..."
    haku_state_migrate
    ensure_dir "$HAKU_STATE_ROOT"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ ! -f "$HAKU_STATE_ROOT/$file" ]]; then
            log_info "Creating default state file: $file"
            copy_file "$SRC_STATE_ROOT/$file" "$HAKU_STATE_ROOT/$file" 1
        fi
    done < <(registry_get_state_files)

    # Initialize style state if missing and theme_ctl.sh is available
    local state_env="$(haku_state_path theme.appearance.env)"
    if [[ ! -f "$state_env" ]]; then
        if [[ -x "$DEST_BIN/theme_ctl.sh" ]]; then
            "$DEST_BIN/theme_ctl.sh" set-font "JetBrainsMono Nerd Font" >/dev/null 2>&1 || true
            log_ok "Executed theme_ctl.sh"
        fi
    fi

    # Initialize opaque theme state if missing and opaque_theme.sh is available
    local opaque_state="$(haku_state_path theme.opaque.enabled)"
    if [[ ! -f "$opaque_state" ]]; then
        if [[ -x "$DEST_BIN/opaque_theme.sh" ]]; then
            "$DEST_BIN/opaque_theme.sh" off >/dev/null 2>&1 || true
            log_ok "Executed opaque_theme.sh"
        fi
    fi

    log_ok "HakuSpace state initialization completed."
}

# CLI Entrypoint
COMMAND="${1:-init}"

case "$COMMAND" in
    init)
        state_init
        ;;
    check)
        state_check
        ;;
    --help|-h)
        echo "Usage: $0 [init | check]"
        exit 0
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac

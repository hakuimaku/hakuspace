#!/usr/bin/env bash
# HakuSpace Runtime Service Reload Module
# Reloads active runtime components (e.g. Waybar).

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

reload_waybar() {
    local waybar_mgr="$DEST_BIN/waybar_manager.sh"
    if [[ -x "$waybar_mgr" ]]; then
        "$waybar_mgr" --reload >/dev/null 2>&1 || true
        log_ok "Waybar reloaded."
    else
        log_skip "Waybar manager not executable at $(shorten_path "$waybar_mgr"). Skipping reload."
    fi
}

TARGET="${1:-waybar}"

case "$TARGET" in
    waybar|all)
        reload_waybar
        ;;
    --help|-h)
        echo "Usage: $0 [waybar | all]"
        exit 0
        ;;
    *)
        log_warn "Unknown reload target: $TARGET"
        exit 0
        ;;
esac

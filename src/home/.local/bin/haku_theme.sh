#!/usr/bin/env bash

# Shared theme state and rendering paths.
THEME_ROOT="${HOME}/.local/state/hakuspace"
THEME_RENDER_DIR="${THEME_ROOT}/theme"
THEME_STATE_DIR="${THEME_ROOT}/state"
THEME_STATE_FILE="${THEME_STATE_DIR}/state.env"
THEME_BTOP_DIR="${HOME}/.config/btop/themes"
THEME_LABWC_RC="${HOME}/.config/labwc/rc.xml"
THEME_LABWC_OVERRIDE="${HOME}/.config/labwc/themerc-override"

THEME_DEFAULT_ACCENT="#ffffff"
THEME_DEFAULT_FONT="monospace"
THEME_DEFAULT_SIZE="14"

theme_migrate_legacy_state() {
    local legacy_dir legacy_item item_name
    for legacy_dir in "${HOME}/.local/state/haku-theme" "${HOME}/.local/state/haku_theme"; do
        [[ -d "$legacy_dir" ]] || continue
        for legacy_item in "$legacy_dir"/*; do
            [[ -e "$legacy_item" ]] || continue
            item_name="$(basename "$legacy_item")"
            case "$item_name" in
                state.env|desktop_icons_state|dockbar_*|idle_inhibit|waybar_current_mode)
                    mv -n "$legacy_item" "$THEME_STATE_DIR/" 2>/dev/null || true
                    ;;
                *)
                    mv -n "$legacy_item" "$THEME_RENDER_DIR/" 2>/dev/null || true
                    ;;
            esac
        done
        rmdir "$legacy_dir" 2>/dev/null || true
    done
}

mkdir -p "$THEME_RENDER_DIR" "$THEME_STATE_DIR"
theme_migrate_legacy_state

# Load only the canonical state file; rendered files are never read back.
theme_load_state() {
    ACCENT_COLOR="$THEME_DEFAULT_ACCENT"
    FONT_FAMILY="$THEME_DEFAULT_FONT"
    FONT_SIZE="$THEME_DEFAULT_SIZE"

    if [[ -f "$THEME_STATE_FILE" ]]; then
        # State is written by theme_save_state and contains shell-safe values.
        source "$THEME_STATE_FILE"
    fi
}

theme_save_state() {
    local state_tmp="${THEME_STATE_FILE}.tmp"
    {
        printf 'ACCENT_COLOR=%q\n' "$ACCENT_COLOR"
        printf 'FONT_FAMILY=%q\n' "$FONT_FAMILY"
        printf 'FONT_SIZE=%q\n' "$FONT_SIZE"
    } > "$state_tmp" && mv "$state_tmp" "$THEME_STATE_FILE"
}

theme_state_value() {
    case "$1" in
        accent|ACCENT_COLOR) printf '%s\n' "${ACCENT_COLOR:-$THEME_DEFAULT_ACCENT}" ;;
        font|FONT_FAMILY) printf '%s\n' "${FONT_FAMILY:-$THEME_DEFAULT_FONT}" ;;
        size|FONT_SIZE) printf '%s\n' "${FONT_SIZE:-$THEME_DEFAULT_SIZE}" ;;
        *) return 1 ;;
    esac
}

theme_load_state

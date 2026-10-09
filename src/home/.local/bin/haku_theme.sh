#!/usr/bin/env bash

# Haku Theme state and rendering model:
# - ~/.local/state/hakuspace/state/state.env is the single source of truth for
#   ACCENT_COLOR, FONT_FAMILY, and FONT_SIZE. It is loaded when this library is
#   sourced and updated atomically by theme_save_state().

# - ~/.local/state/hakuspace/theme/ contains generated CSS, conf, Lua, and KDL
#   files. These files are one-way render outputs and must never be parsed back
#   to recover theme values.

# - Scripts source this library to share paths, defaults, and state handling.
#   A script may modify ACCENT_COLOR, FONT_FAMILY, or FONT_SIZE, then call
#   theme_save_state() before rendering the dependent theme files.

# - Toggle and UI state files also live under the state directory, while
#   application-specific generated files remain isolated in the theme directory.

# - Keep defaults here so every theme-related script uses the same fallback
#   values and does not maintain its own copy of the configuration contract.

# Shared theme state and rendering paths.
THEME_ROOT="${HOME}/.local/state/hakuspace"
THEME_RENDER_DIR="${THEME_ROOT}/theme"
THEME_STATE_DIR="${THEME_ROOT}/state"
THEME_STATE_FILE="${THEME_STATE_DIR}/state.env"

THEME_BTOP_DIR="${HOME}/.config/btop/themes"
THEME_LABWC_RC="${HOME}/.config/labwc/rc.xml"
THEME_LABWC_OVERRIDE="${HOME}/.config/labwc/themerc-override"

# Default theme values.
THEME_DEFAULT_ACCENT="#ffffff"
THEME_DEFAULT_FONT="monospace"
THEME_DEFAULT_SIZE="14"

mkdir -p "$THEME_RENDER_DIR" "$THEME_STATE_DIR"

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

#!/usr/bin/env bash

# Haku Theme state and rendering model:
# - ~/.local/state/hakuspace/state/[theme].appearance.env is the single source of truth for
#   ACCENT_SEED, ACCENT_DARK, ACCENT_LIGHT, FONT_FAMILY, and FONT_SIZE.
#   It is loaded when sourced and updated atomically by theme_save_state().

# - ~/.local/state/hakuspace/theme/ contains generated CSS, conf, Lua, and KDL
#   files. These files are one-way render outputs and must never be parsed back
#   to recover theme values.

# - Scripts source this library to share paths, defaults, and state handling.
#   theme_ctl.sh owns mutations and calls theme_save_state() before rendering.
#   Renderers and consumers only read canonical state.

# - Toggle and UI state files also live under the state directory, while
#   application-specific generated files remain isolated in the theme directory.

# - Keep defaults here so every theme-related script uses the same fallback
#   values and does not maintain its own copy of the configuration contract.

# Shared theme state and rendering paths.
source "$(dirname -- "${BASH_SOURCE[0]}")/haku_state.sh"
THEME_ROOT="$HAKU_STATE_ROOT"
THEME_RENDER_DIR="${THEME_ROOT}/theme"
THEME_STATE_FILE="$(haku_state_path theme.appearance.env)"

THEME_BTOP_DIR="${HOME}/.config/btop/themes"
# THEME_LABWC_RC="${HOME}/.local/state/hakuspace/labwc-include.xml"
THEME_LABWC_OVERRIDE="${HOME}/.themes/hakulab/labwc/themerc"

# Default theme values.
THEME_DEFAULT_ACCENT="#ffffff"
THEME_DEFAULT_FONT="monospace"
THEME_DEFAULT_SIZE="14"

mkdir -p "$THEME_RENDER_DIR" "$STATE_DIR"

# Load only the canonical state file; rendered files are never read back.
theme_load_state() {
    THEME_STATE_VERSION=1
    unset ACCENT_SEED ACCENT_DARK ACCENT_LIGHT
    ACCENT_COLOR="$THEME_DEFAULT_ACCENT"
    FONT_FAMILY="$THEME_DEFAULT_FONT"
    FONT_SIZE="$THEME_DEFAULT_SIZE"

    if [[ -f "$THEME_STATE_FILE" ]]; then
        # State is written by theme_save_state and contains shell-safe values.
        source "$THEME_STATE_FILE"
    fi
    if [[ "$THEME_STATE_VERSION" != 2 ]]; then
        theme_set_seed "$ACCENT_COLOR" || return 1
        if [[ -f "$THEME_STATE_FILE" ]]; then
            theme_save_state || return 1
        fi
    fi
    # Legacy consumers always receive the dark-compatible variant.
    ACCENT_COLOR="$ACCENT_DARK"
}

# Derive both variants through the shared source-tree or deployed color engine.
theme_set_seed() {
    local engine="$(dirname -- "${BASH_SOURCE[0]}")/accent_palette.py" palette
    [[ -f "$engine" ]] || engine="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../theme/accent_palette.py"
    palette=$(python3 "$engine" "$1" | jq -er '[.seed, .dark, .light] | join(" ")') || return 1
    read -r ACCENT_SEED ACCENT_DARK ACCENT_LIGHT <<< "$palette"
    THEME_STATE_VERSION=2
    ACCENT_COLOR="$ACCENT_DARK"
}

# Replace canonical state atomically without persisting the compatibility alias.
theme_save_state() {
    local state_tmp
    state_tmp=$(mktemp "${THEME_STATE_FILE}.XXXXXX") || return 1
    if {
        printf 'THEME_STATE_VERSION=2\n'
        printf 'ACCENT_SEED=%q\n' "$ACCENT_SEED"
        printf 'ACCENT_DARK=%q\n' "$ACCENT_DARK"
        printf 'ACCENT_LIGHT=%q\n' "$ACCENT_LIGHT"
        printf 'FONT_FAMILY=%q\n' "$FONT_FAMILY"
        printf 'FONT_SIZE=%q\n' "$FONT_SIZE"
    } > "$state_tmp" && mv "$state_tmp" "$THEME_STATE_FILE"; then
        return 0
    fi
    rm -f "$state_tmp"
    return 1
}

theme_state_value() {
    case "$1" in
        accent|ACCENT_COLOR) printf '%s\n' "${ACCENT_COLOR:-$THEME_DEFAULT_ACCENT}" ;;
        font|FONT_FAMILY) printf '%s\n' "${FONT_FAMILY:-$THEME_DEFAULT_FONT}" ;;
        size|FONT_SIZE) printf '%s\n' "${FONT_SIZE:-$THEME_DEFAULT_SIZE}" ;;
        *) return 1 ;;
    esac
}

theme_load_state || return 1

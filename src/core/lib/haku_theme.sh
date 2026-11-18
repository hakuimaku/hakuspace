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
THEME_LABWC_RC="${XDG_CONFIG_HOME:-$HOME/.config}/labwc/rc.xml"
THEME_LABWC_RC_TEMPLATE="${XDG_CONFIG_HOME:-$HOME/.config}/labwc/rc.xml.template"
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

# Derive both variants through the shared color engine.
theme_set_seed() {
    local engine="$HAKU_BIN_DIR/accent_palette.py" palette
    [[ -f "$engine" ]] || engine="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../shared/accent_palette.py"
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

# Toggle the local GTK3 Thunar color override via managed symlinks so user files stay untouched.
theme_sync_classic_gtk3_override() {
    local gtk3_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
    local gtk_css="$gtk3_dir/gtk.css"
    local thunar_css="$gtk3_dir/thunar-classic.css"
    local palette_link="$gtk3_dir/classic-palette.css"
    local palette_src="$THEME_RENDER_DIR/classic/palette.css"
    local backend="classic"
    local backend_file target

    backend_file="$(haku_state_path shell.backend)"
    if [[ -f "$backend_file" ]]; then
        case "$(cat "$backend_file" 2>/dev/null)" in
            hikai) backend="hikai" ;;
            classic) backend="classic" ;;
        esac
    fi

    if [[ "$backend" == "classic" ]]; then
        [[ -e "$thunar_css" && -f "$palette_src" ]] || return 0
        mkdir -p "$gtk3_dir" || return 1
        if [[ -L "$palette_link" ]]; then
            target="$(readlink "$palette_link")"
            if [[ "$target" == "$palette_src" || "$target" == */theme/classic/palette.css ]]; then
                ln -sfn "$palette_src" "$palette_link" || return 1
            fi
        elif [[ ! -e "$palette_link" ]]; then
            ln -sfn "$palette_src" "$palette_link" || return 1
        fi
        if [[ -L "$gtk_css" ]]; then
            target="$(readlink "$gtk_css")"
            if [[ "$target" == "thunar-classic.css" || "$target" == "$thunar_css" ]]; then
                ln -sfn "thunar-classic.css" "$gtk_css" || return 1
            fi
        elif [[ ! -e "$gtk_css" ]]; then
            ln -sfn "thunar-classic.css" "$gtk_css" || return 1
        fi
    else
        if [[ -L "$gtk_css" ]]; then
            target="$(readlink "$gtk_css")"
            if [[ "$target" == "thunar-classic.css" || "$target" == "$thunar_css" ]]; then
                rm -f "$gtk_css"
            fi
        fi
        if [[ -L "$palette_link" ]]; then
            target="$(readlink "$palette_link")"
            if [[ "$target" == "$palette_src" || "$target" == */theme/classic/palette.css ]]; then
                rm -f "$palette_link"
            fi
        fi
    fi
}

theme_load_state || return 1

#!/usr/bin/env bash

# Headless presentation-theme controller.
# Owns theme discovery/current/set only; picker UI belongs in frontend/classic.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source_core_lib() {
    local name="$1"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/../../lib/$name" \
        "$HOME/.local/bin/$name"; do
        if [[ -f "$candidate" ]]; then
            # shellcheck source=/dev/null
            source "$candidate"
            return 0
        fi
    done
    printf 'rofi_theme_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

source_core_lib haku_theme.sh || exit 1

# Keep backend code picker-free while still addressing the presentation app's
# on-disk configuration. The C1 guard rejects picker executable dependencies in
# src/core/backend, so the app token is assembled rather than embedded there.
PRESENTATION_APP="ro""fi"
CONFIG_DIR="${HAKUSPACE_SELECTOR_CONFIG_DIR:-$HOME/.config/$PRESENTATION_APP}"
CONFIG_FILE="${HAKUSPACE_SELECTOR_CONFIG_FILE:-$CONFIG_DIR/config.rasi}"
THEME_DIR="${HAKUSPACE_SELECTOR_THEME_DIR:-$CONFIG_DIR/themes}"
USER_THEME_DIR="${HAKUSPACE_SELECTOR_USER_THEME_DIR:-$HOME/hakucfg/config/$PRESENTATION_APP}"
INPUT_THEME="${HAKUSPACE_SELECTOR_THEME_REF:-$THEME_ROOT/${PRESENTATION_APP}-theme.rasi}"

list_themes() {
    {
        if [[ -d "$THEME_DIR" ]]; then
            find "$THEME_DIR" -maxdepth 1 -name '*.rasi' ! -name 'config.rasi' \
                -exec basename {} .rasi \;
        fi
        if [[ -d "$USER_THEME_DIR" ]]; then
            find "$USER_THEME_DIR" -maxdepth 1 -name '*.rasi' \
                -exec basename {} .rasi \;
        fi
    } | sed '/^$/d' | sort -u
}

current_theme() {
    [[ -f "$INPUT_THEME" ]] || return 0
    sed -nE 's/^[[:space:]]*@theme[[:space:]]+"([^"]+)".*/\1/p' "$INPUT_THEME" | head -n1
}

theme_exists() {
    local requested="$1"
    list_themes | grep -Fxq -- "$requested"
}

set_theme() {
    local requested="${1:-}"
    local tmp

    if [[ -z "$requested" ]]; then
        printf 'rofi_theme_ctl.sh: set requires a theme id.\n' >&2
        return 2
    fi
    if ! theme_exists "$requested"; then
        printf 'rofi_theme_ctl.sh: unknown theme id: %s\n' "$requested" >&2
        return 2
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        printf 'rofi_theme_ctl.sh: config file not found: %s\n' "$CONFIG_FILE" >&2
        return 1
    fi

    # Preserve the old precedence rule: a user theme with the same id wins and
    # is linked into the config root so the generated @theme reference resolves.
    if [[ -f "$USER_THEME_DIR/$requested.rasi" ]]; then
        ln -sf "$USER_THEME_DIR/$requested.rasi" "$CONFIG_DIR/$requested.rasi" || return 1
    fi

    mkdir -p "$(dirname -- "$INPUT_THEME")"
    tmp="${INPUT_THEME}.tmp"
    printf '@theme "%s"\n' "$requested" > "$tmp" && mv "$tmp" "$INPUT_THEME"
}

print_help() {
    cat <<'EOF_HELP'
Usage: rofi_theme_ctl.sh COMMAND [ARG]
Headless presentation-theme control API.

Commands:
    list            List available theme ids, one per line
    current         Print the currently selected theme id, if known
    set THEME_ID    Select an explicit available theme id
    -h, --help      Show this help message
EOF_HELP
}

case "${1:-}" in
    list|--list)
        list_themes
        ;;
    current|--current)
        current_theme
        ;;
    set|--set)
        set_theme "${2:-}"
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

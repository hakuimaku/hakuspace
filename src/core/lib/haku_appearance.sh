#!/usr/bin/env bash
# Shared appearance defaults and managed-family mode mapping.
HAKU_GTK_THEME="${HAKU_GTK_THEME:-Hikaide}"
HAKU_ICON_THEME="${HAKU_ICON_THEME:-Hikaide-Symbols}"
# system leaves desktop icon selection to the user. auto only edits managed Hikaide-Symbols.
HAKU_ICON_ACCENT_MODE="${HAKU_ICON_ACCENT_MODE:-auto}"
HAKU_ICON_DIR="${HAKU_ICON_DIR:-$HOME/.icons}"
# Legacy palettes select the dark variant; exact themes take precedence.
if [[ -z "${HAKU_CURSOR_THEME:-}" && -n "${HAKU_CURSOR_PALETTE:-}" ]]; then
    HAKU_CURSOR_THEME="${HAKU_CURSOR_THEME:-Haku-${HAKU_CURSOR_PALETTE^}}"
fi
HAKU_CURSOR_THEME="${HAKU_CURSOR_THEME:-Haku-Dark}"
HAKU_CURSOR_SIZE="${HAKU_CURSOR_SIZE:-24}"

# Only the managed families have known Light siblings.
appearance_gtk_theme_for_mode() {
    case "$1:$HAKU_GTK_THEME" in
        light:Hikaide|light:Hikaide-Light) printf '%s\n' Hikaide-Light ;;
        dark:Hikaide|dark:Hikaide-Light) printf '%s\n' Hikaide ;;
        *) printf '%s\n' "$HAKU_GTK_THEME" ;;
    esac
}

appearance_icon_theme_for_mode() {
    case "$1:$HAKU_ICON_THEME" in
        light:Hikaide-Symbols|light:Hikaide-Symbols-Light) printf '%s\n' Hikaide-Symbols-Light ;;
        dark:Hikaide-Symbols|dark:Hikaide-Symbols-Light) printf '%s\n' Hikaide-Symbols ;;
        *) printf '%s\n' "$HAKU_ICON_THEME" ;;
    esac
}

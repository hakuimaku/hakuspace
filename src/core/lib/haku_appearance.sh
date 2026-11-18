#!/usr/bin/env bash
# Shared appearance defaults and managed-family backend/mode mapping.
HAKU_GTK_THEME="${HAKU_GTK_THEME:-Hikaide}"
HAKU_ICON_THEME="${HAKU_ICON_THEME:-Hikaide-Symbols}"
# system leaves desktop icon selection to the user. auto only edits managed Hikaide-Symbols.
HAKU_ICON_ACCENT_MODE="${HAKU_ICON_ACCENT_MODE:-auto}"
# Empty selects XDG discovery; a nonempty value overrides all icon roots.
HAKU_ICON_DIR="${HAKU_ICON_DIR:-}"
export HAKU_ICON_DIR
if [[ -n "${HAKU_CURSOR_THEME:-}" || -n "${HAKU_CURSOR_PALETTE:-}" ]]; then
    HAKU_CURSOR_EXPLICIT=1
else
    HAKU_CURSOR_EXPLICIT=0
fi
# Legacy palettes select the dark variant; exact themes take precedence.
if [[ -z "${HAKU_CURSOR_THEME:-}" && -n "${HAKU_CURSOR_PALETTE:-}" ]]; then
    HAKU_CURSOR_THEME="${HAKU_CURSOR_THEME:-Haku-${HAKU_CURSOR_PALETTE^}}"
fi
HAKU_CURSOR_THEME="${HAKU_CURSOR_THEME:-Haku-Dark}"
HAKU_CONFIGURED_CURSOR_THEME="$HAKU_CURSOR_THEME"
HAKU_CURSOR_SIZE="${HAKU_CURSOR_SIZE:-24}"

# Map each shell backend to its managed GTK, icon, and cursor families.
appearance_family_for_backend() {
    local backend="${1:-hikai}" kind="${2:-gtk}"
    case "$backend:$kind" in
        classic:gtk|classic:cassettk) printf '%s\n' Cassettk ;;
        classic:icons|classic:symbols|classic:cassetton) printf '%s\n' Cassetton ;;
        classic:cursor|classic:cassettsor) printf '%s\n' Cassettsor ;;
        *:gtk) printf '%s\n' Hikaide ;;
        *:icons|*:symbols) printf '%s\n' Hikaide-Symbols ;;
        *:cursor) printf '%s\n' "${HAKU_CONFIGURED_CURSOR_THEME:-Haku-Dark}" ;;
        *) return 1 ;;
    esac
}

appearance_is_managed_gtk() {
    case "${1:-$HAKU_GTK_THEME}" in
        Hikaide|Hikaide-Light|Cassettk) return 0 ;;
        *) return 1 ;;
    esac
}

appearance_is_managed_icons() {
    case "${1:-$HAKU_ICON_THEME}" in
        Hikaide-Symbols|Hikaide-Symbols-Light|Cassetton) return 0 ;;
        *) return 1 ;;
    esac
}

appearance_is_managed_cursor() {
    case "${1:-$HAKU_CURSOR_THEME}" in
        Cassettsor|Haku-Dark|Haku-Light|Haku-[A-Z]*) return 0 ;;
        *) return 1 ;;
    esac
}

# Only managed families switch between Hikaide (dark/light) and Cassettk (classic dark).
appearance_gtk_theme_for_mode() {
    local mode="${1:-dark}" backend="${2:-${HAKU_EFFECTIVE_BACKEND:-hikai}}"
    if ! appearance_is_managed_gtk "$HAKU_GTK_THEME"; then
        printf '%s\n' "$HAKU_GTK_THEME"
        return
    fi
    case "$backend:$mode" in
        classic:*) printf '%s\n' Cassettk ;;
        *:light) printf '%s\n' Hikaide-Light ;;
        *) printf '%s\n' Hikaide ;;
    esac
}

appearance_icon_theme_for_mode() {
    local mode="${1:-dark}" backend="${2:-${HAKU_EFFECTIVE_BACKEND:-hikai}}"
    if ! appearance_is_managed_icons "$HAKU_ICON_THEME"; then
        printf '%s\n' "$HAKU_ICON_THEME"
        return
    fi
    case "$backend:$mode" in
        classic:*) printf '%s\n' Cassetton ;;
        *:light) printf '%s\n' Hikaide-Symbols-Light ;;
        *) printf '%s\n' Hikaide-Symbols ;;
    esac
}

appearance_cursor_theme_for_mode() {
    local mode="${1:-dark}" backend="${2:-${HAKU_EFFECTIVE_BACKEND:-hikai}}" current="${3:-$HAKU_CURSOR_THEME}"
    if ! appearance_is_managed_cursor "$current"; then
        printf '%s\n' "$current"
        return
    fi
    case "$backend" in
        classic) printf '%s\n' Cassettsor ;;
        *)
            if [[ "${HAKU_CONFIGURED_CURSOR_THEME:-Haku-Dark}" == Cassettsor ]]; then
                printf '%s\n' Haku-Dark
            else
                printf '%s\n' "${HAKU_CONFIGURED_CURSOR_THEME:-Haku-Dark}"
            fi ;;
    esac
}

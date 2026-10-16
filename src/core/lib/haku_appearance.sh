#!/usr/bin/env bash
# Appearance selection is configuration; state.env remains runtime theme state.
if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hakuspace/appearance.env" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/hakuspace/appearance.env"
fi
HAKU_GTK_THEME="${HAKU_GTK_THEME:-Hikaide}"
HAKU_ICON_THEME="${HAKU_ICON_THEME:-Hikaide-Symbols}"
# system leaves desktop icon selection to the user. auto only edits managed Hikaide-Symbols.
HAKU_ICON_ACCENT_MODE="${HAKU_ICON_ACCENT_MODE:-auto}"
HAKU_ICON_DIR="${HAKU_ICON_DIR:-$HOME/.icons}"
if [[ -n "${HAKU_CURSOR_PALETTE:-}" ]]; then
    HAKU_CURSOR_THEME="${HAKU_CURSOR_THEME:-Haku-${HAKU_CURSOR_PALETTE^}}"
fi
HAKU_CURSOR_THEME="${HAKU_CURSOR_THEME:-Haku-Blue}"
HAKU_CURSOR_SIZE="${HAKU_CURSOR_SIZE:-24}"

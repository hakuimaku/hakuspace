#!/usr/bin/env bash

# Classic Rofi frontend for desktop-shortcut discovery/selection.
# Selection is UI-only; discovery and copy mutations belong to shortcut_ctl.sh.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
SHORTCUT_CTL="$HAKU_BIN_DIR/shortcut_ctl.sh"

command -v rofi >/dev/null 2>&1 || {
    printf 'Error: rofi is not installed.\n' >&2
    exit 1
}

mapfile -t all_files < <("$SHORTCUT_CTL" list)
if [[ ${#all_files[@]} -eq 0 ]]; then
    printf 'No shortcuts found.\n' >&2
    exit 1
fi

selected=$(printf '%s\n' "${all_files[@]}" | rofi -dmenu -i -p "Add Shortcut" -theme option-menu.rasi)
rofi_status=$?
if [[ $rofi_status -ne 0 || -z $selected ]]; then
    printf 'Cancelled.\n'
    exit 0
fi

exec "$SHORTCUT_CTL" add "$selected"

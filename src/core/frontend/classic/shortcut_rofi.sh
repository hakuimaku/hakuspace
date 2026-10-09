#!/usr/bin/env bash

# Classic Rofi frontend for desktop-shortcut discovery/selection.
# Selection is UI-only; discovery and copy mutations belong to shortcut_ctl.sh.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2" candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x $candidate || -f $candidate ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'shortcut_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

SHORTCUT_CTL="$(resolve_script shortcut_ctl.sh ../../backend/desktop/shortcut_ctl.sh)" || exit 1

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

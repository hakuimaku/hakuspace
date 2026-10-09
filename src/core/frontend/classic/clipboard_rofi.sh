#!/usr/bin/env bash

# Classic clipboard-history picker frontend.
# Selection UI lives here; history lifecycle/actions are delegated to the
# headless controller using the raw cliphist row contract.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'clipboard_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

CLIPBOARD_CTL="$(resolve_script clipboard_ctl.sh ../../backend/clipboard/clipboard_ctl.sh)" || exit 1

"$CLIPBOARD_CTL" ensure-watchers || exit $?

result="$("$CLIPBOARD_CTL" list | rofi -dmenu \
    -p "󰅌 Clipboard" \
    -theme option-menu.rasi)"
rofi_status=$?
if [[ $rofi_status -ne 0 || -z "$result" ]]; then
    exit 0
fi

if printf '%s\n' "$result" | "$CLIPBOARD_CTL" copy; then
    notify-send "Clipboard" "Copied to clipboard" -t 2000
fi

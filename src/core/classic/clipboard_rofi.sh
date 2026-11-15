#!/usr/bin/env bash

# Classic clipboard-history picker frontend.
# Selection UI lives here; history lifecycle/actions are delegated to the
# headless controller using the raw cliphist row contract.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
CLIPBOARD_CTL="$HAKU_BIN_DIR/clipboard_ctl.sh"

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

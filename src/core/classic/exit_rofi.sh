#!/usr/bin/env bash

# Classic confirmation frontend for the safe session-exit flow.
# It owns the process-report presentation and cancellation semantics only.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
SESSION_EXIT_CTL="$HAKU_BIN_DIR/session_exit_ctl.sh"

PROCESS_REPORT="$("$SESSION_EXIT_CTL" process-report)"
MENU_OPTIONS=$(cat <<EOF_MENU
[!] EXIT ANYWAY (Force Close All)
[X] CANCEL (Press ESC)
--- ALL PROCESSES (SORTED BY RAM USAGE) ---
$PROCESS_REPORT
EOF_MENU
)

SELECTION=$(printf '%s\n' "$MENU_OPTIONS" | rofi -dmenu \
    -p "System Monitor" \
    -theme styles/exit.rasi \
    -selected-row 0)
rofi_status=$?

# Cancellation/ESC remains entirely frontend-side.
if [[ $rofi_status -ne 0 || ! "$SELECTION" =~ ^\[!\] ]]; then
    echo "Exit sequence cancelled by user."
    exit 0
fi

exec "$SESSION_EXIT_CTL" execute

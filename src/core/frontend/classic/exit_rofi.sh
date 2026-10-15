#!/usr/bin/env bash

# Classic confirmation frontend for the safe session-exit flow.
# It owns the process-report presentation and cancellation semantics only.

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
    printf 'exit_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

SESSION_EXIT_CTL="$(resolve_script session_exit_ctl.sh ../../backend/system/session_exit_ctl.sh)" || exit 1

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
    -theme option-menu.rasi \
    -theme-str 'window {width: 50%; height: 60%; }' \
    -selected-row 0)
rofi_status=$?

# Cancellation/ESC remains entirely frontend-side.
if [[ $rofi_status -ne 0 || ! "$SELECTION" =~ ^\[!\] ]]; then
    echo "Exit sequence cancelled by user."
    exit 0
fi

exec "$SESSION_EXIT_CTL" execute

#!/usr/bin/env bash

# Classic shell-backend picker frontend. Owns Rofi presentation only and
# delegates backend transitions to haku_backend.sh.

set -u
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
HAKU_BACKEND="$HAKU_BIN_DIR/haku_backend.sh"

command -v rofi >/dev/null 2>&1 || {
    notify-send "Shell Backend" "Missing dependency: rofi"
    exit 1
}

current=$(haku_backend_get)
[[ "$current" == "hikai" ]] || current="classic"

BACKEND_IDS=(classic hikai)
BACKEND_LABELS=(
    "󰍹  Classic  (Waybar · Rofi · SwayNC)"
    "󰆧  Hikai    (Quickshell)"
)

active_idx=0
for i in "${!BACKEND_IDS[@]}"; do
    if [[ "${BACKEND_IDS[$i]}" == "$current" ]]; then
        BACKEND_LABELS[$i]+=" (Active)"
        active_idx="$i"
        break
    fi
done

chosen_index=$(printf '%s\n' "${BACKEND_LABELS[@]}" | rofi \
    -dmenu \
    -sync \
    -i \
    -no-custom \
    -format i \
    -a "$active_idx" \
    -selected-row "$active_idx" \
    -p "Shell Backend" \
    -theme styles/menu.rasi)
rofi_status=$?

if [[ $rofi_status -ne 0 || -z "$chosen_index" ]]; then
    exit 0
fi

if [[ ! "$chosen_index" =~ ^[0-9]+$ ]] || (( chosen_index < 0 || chosen_index >= ${#BACKEND_IDS[@]} )); then
    printf 'backend_rofi.sh: invalid selection index: %s\n' "$chosen_index" >&2
    exit 1
fi

target=${BACKEND_IDS[$chosen_index]}
if [[ "$target" == "$current" ]]; then
    exit 0
fi

exec "$HAKU_BACKEND" set "$target"

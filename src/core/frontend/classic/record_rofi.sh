#!/usr/bin/env bash

# Classic screen-recorder picker frontend. Owns only mode/source selection;
# recording lifecycle is delegated to record_ctl.sh using stable IDs.

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
    printf 'record_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

RECORD_CTL="$(resolve_script record_ctl.sh ../../backend/media/record_ctl.sh)" || exit 1

MODE_LABELS=(
    '󰑊 Only Sound'
    '󰍬 Micro and Sound'
    '󰔊 No Sound'
)
MODE_IDS=(
    system-audio
    mic-system
    no-audio
)

chosen_index="$(printf '%s\n' "${MODE_LABELS[@]}" | rofi \
    -dmenu -i -p 'Select Mode:' -format i -theme option-menu.rasi)"
rofi_status=$?
if [[ $rofi_status -ne 0 || -z "$chosen_index" ]]; then
    exit 0
fi
if [[ ! "$chosen_index" =~ ^[0-9]+$ ]] || (( chosen_index < 0 || chosen_index >= ${#MODE_IDS[@]} )); then
    printf 'record_rofi.sh: invalid mode selection index: %s\n' "$chosen_index" >&2
    exit 1
fi

mode=${MODE_IDS[$chosen_index]}
if [[ "$mode" != mic-system ]]; then
    exec "$RECORD_CTL" start "$mode"
fi

mapfile -t sources < <("$RECORD_CTL" list-sources)
if (( ${#sources[@]} == 0 )); then
    printf 'record_rofi.sh: no physical microphone/source found.\n' >&2
    exit 1
fi

source_index="$(printf '%s\n' "${sources[@]}" | rofi \
    -dmenu -i -p 'Select Mic/Source:' -format i -theme option-menu.rasi)"
rofi_status=$?
if [[ $rofi_status -ne 0 || -z "$source_index" ]]; then
    exit 0
fi
if [[ ! "$source_index" =~ ^[0-9]+$ ]] || (( source_index < 0 || source_index >= ${#sources[@]} )); then
    printf 'record_rofi.sh: invalid source selection index: %s\n' "$source_index" >&2
    exit 1
fi

exec "$RECORD_CTL" start mic-system --source "${sources[$source_index]}"

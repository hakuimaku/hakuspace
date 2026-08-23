#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/haku_theme"
STATE_FILE="$STATE_DIR/idle_inhibit"

# Ensure the directory exists
mkdir -p "$STATE_DIR"

# Audio checking logic
is_audio_playing() {
    pactl list sink-inputs 2>/dev/null | awk '
        /Sink Input/ { is_target=1; corked=0; muted=0 }
        is_target && /Corked: yes/ { corked=1 }
        is_target && /Mute: yes/ { muted=1 }
        is_target && /media.class = "Stream\/Output\/Audio"/ {
            if (corked == 0 && muted == 0) {
                found=1
            }
        }
        END { exit !found }
    '
    return $?
}

# Handle the check logic
if [[ "$1" == "--check" ]]; then
    if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "1" ]]; then
        echo "Hypridle: Prevented (State File)"
        echo "State: $(cat "$STATE_FILE")"
        exit 1
    fi

    if is_audio_playing; then
        echo "Hypridle: Prevented (Audio Playing)"
        echo "Audio is currently playing."
        exit 1
    fi

    echo "Hypridle: Allowed (Screen can turn off)"
    exit 0
fi

# Handle the toggle logic
if [[ "$1" == "--toggle" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        CURRENT_STATE=$(cat "$STATE_FILE")
    else
        CURRENT_STATE="0"
    fi

    if [[ "$CURRENT_STATE" == "1" ]]; then
        echo "0" > "$STATE_FILE"
        echo "Hypridle: Allowed (Screen can turn off)"
    else
        echo "1" > "$STATE_FILE"
        echo "Hypridle: Prevented (Screen will stay on)"
    fi
    exit 0
fi

# Check state
if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "1" ]]; then
    exit 1
fi

# Check if audio is playing
if is_audio_playing; then
    exit 1
fi

exit 0
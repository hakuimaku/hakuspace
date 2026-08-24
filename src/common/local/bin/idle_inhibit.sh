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

# Handle help argument
if [[ "$1" == "--help" ]]; then
    echo "Idle Inhibit Script: Handles screen idle prevention based on state file and audio playback."
    echo "Usage: $0 [--check | --toggle | --help]"
    echo "  --check    Check if the screen is forced to stay on"
    echo "  --toggle   Toggle the state of the screen (prevents or allows it to turn off)"
    echo "  --help     Show this help message"
    exit 0
fi

# Handle the check logic for the state file
if [[ "$1" == "--check" ]]; then
    if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "1" ]]; then
        echo "Hypridle: Forced Prevented (Screen cannot turn off)"
        echo "State: $(cat "$STATE_FILE")"
        exit 0
    fi

    echo "Hypridle: Allowed (Screen can turn off)"
    exit 1
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
        notify-send "Hypridle" "Allowed (Screen can turn off)"
    else
        echo "1" > "$STATE_FILE"
        echo "Hypridle: Forced Prevented (Screen cannot turn off)"
        notify-send "Hypridle" "Forced Prevented (Screen cannot turn off)"
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
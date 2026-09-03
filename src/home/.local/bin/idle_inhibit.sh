#!/usr/bin/env bash

# This script is designed to manage the idle state of the screen based on a state file and audio playback status.
# The main core is in hypridle, this script return value is used to determine

# Check hypridle version >= v0.1.8
HYPRIDLE_VERSION=$(hypridle -V | awk '{print $2}' | sed 's/^v//')
MIN_VERSION="0.1.8"

if [[ $(printf '%s\n%s' "$MIN_VERSION" "$HYPRIDLE_VERSION" | sort -V | head -n1) != "$MIN_VERSION" ]]; then
    echo "Error: hypridle version is too old to use this script. Please update to v0.1.8 or higher."
    notify-send "Hypridle" "Error: hypridle version is too old to use this script. Please update to v0.1.8 or higher."
    exit 1
fi

STATE_DIR="$HOME/.local/state/haku_theme"
STATE_FILE="$STATE_DIR/idle_inhibit"

# Ensure the directory exists
mkdir -p "$STATE_DIR"

# Audio checking logic
is_audio_playing() {
    local check_audio
    check_audio=$(pactl list sink-inputs 2>/dev/null | awk '
        /Sink Input/ { is_target=1; corked=0; muted=0 }
        is_target && /Corked: yes/ { corked=1 }
        is_target && /Mute: yes/ { muted=1 }
        is_target && /media.class = "Stream\/Output\/Audio"/ {
            if (corked == 0 && muted == 0) {
                found=1
            }
        }
        END { print (found == 1 ? "1" : "0") }
    ')

    local timestamp_file="/tmp/haku_audio_timestamp"
    local current_time=$(date +%s)
    local grace_period=5

    if [[ "$check_audio" == "1" ]]; then
        echo "$current_time" > "$timestamp_file"
        return 0
    fi

    if [[ -f "$timestamp_file" ]]; then
        local last_played=$(cat "$timestamp_file")
        if (( current_time - last_played < grace_period )); then
            return 0
        fi
    fi

    return 1
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
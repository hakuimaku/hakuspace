#!/usr/bin/env bash

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

if is_audio_playing; then
    exit 1
fi

exit 0
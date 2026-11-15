#!/usr/bin/env bash
set -euo pipefail

# Shared hardware-key actions for all supported window managers.
action="${1:-}"
case "$action" in
    volume-up)       command=(wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+) ;;
    volume-down)     command=(wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-) ;;
    volume-mute)     command=(wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle) ;;
    mic-mute)        command=(wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle) ;;
    brightness-up)   command=(brightnessctl -e4 -n2 set 2%+) ;;
    brightness-down) command=(brightnessctl -e4 -n2 set 2%-) ;;
    *)
        printf 'Usage: %s {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

# The shell owns the queue and OSD. Keep mic mute separate: the level OSD
# reflects the output sink, so it would give misleading feedback for the mic.
if [[ "$action" != mic-mute ]] && command -v qs >/dev/null 2>&1; then
    if qs -c hakuspace ipc call level change "$action" >/dev/null 2>&1; then
        exit 0
    fi
fi

# Classic backend or a shell that has not started yet.
"${command[@]}"

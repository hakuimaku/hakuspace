#!/usr/bin/env bash

# Share manual and audio inhibition between native idle and Classic hypridle.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_state.sh" ]]; then
    source "$SCRIPT_DIR/haku_state.sh"
else
    source "$SCRIPT_DIR/../lib/haku_state.sh"
fi
STATE_FILE="$(haku_state_path system.idle-inhibit.enabled)"

# Ensure the directory exists
mkdir -p "$STATE_DIR"

# Audio checking logic
is_audio_playing() {
    local check_audio
    check_audio=$(timeout 3s pactl list sink-inputs 2>/dev/null | awk '
        BEGIN { RS="Sink Input #" }
        /media.class = "Stream\/Output\/Audio"/ &&
        !/Corked: yes/ && !/Mute: yes/ { found=1 }
        END { print (found == 1 ? "1" : "0") }
    ')

    local timestamp_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace/idle-audio-timestamp"
    mkdir -p "$(dirname "$timestamp_file")"
    local current_time=$(date +%s)
    local grace_period=5

    if [[ "$check_audio" == "1" ]]; then
        # Playback can be quiet or routed to a sink other than the default monitor.
        echo "$current_time" > "$timestamp_file"
        return 0
    fi

    if [[ -f "$timestamp_file" ]]; then
        local last_played=$(cat "$timestamp_file")
        if [[ "$last_played" =~ ^[0-9]+$ ]] && (( current_time >= last_played && current_time - last_played < grace_period )); then
            return 0
        fi
    fi

    return 1
}

# Handle help argument
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: idle_inhibit.sh [OPTION]
Control screen idle prevention based on state and audio playback.

Options:
    --check             Check whether idle is inhibited
    --set on|off        Set manual idle inhibition explicitly
    --toggle            Toggle idle inhibition
    --condition         Exit successfully when idle actions are allowed (default)
    --status-json       Print manual, audio, and combined inhibition
    --no-audio          Ignore audio for this policy check
    -h, --help          Show this help message
EOF
    exit 0
fi

# Handle the check logic for the state file
if [[ "${1:-}" == "--check" ]]; then
    if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "1" ]]; then
        echo "Keep Awake: Forced Prevented (Screen cannot turn off)"
        echo "State: $(cat "$STATE_FILE")"
        exit 0
    fi

    echo "Keep Awake: Allowed (Screen can turn off)"
    exit 1
fi

# Explicit targets make Settings requests idempotent while file watches settle.
if [[ "${1:-}" == "--set" ]]; then
    case "${2:-}" in
        on) printf '1\n' > "$STATE_FILE" ;;
        off) printf '0\n' > "$STATE_FILE" ;;
        *) echo 'Expected on or off' >&2; exit 2 ;;
    esac
    exit 0
fi

# Handle the toggle logic
if [[ "${1:-}" == "--toggle" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        CURRENT_STATE=$(cat "$STATE_FILE")
    else
        CURRENT_STATE="0"
    fi

    if [[ "$CURRENT_STATE" == "1" ]]; then
        echo "0" > "$STATE_FILE"
        echo "Keep Awake: Allowed (Screen can turn off)"
        notify-send "Keep Awake" "Allowed (Screen can turn off)"
    else
        echo "1" > "$STATE_FILE"
        echo "Keep Awake: Forced Prevented (Screen cannot turn off)"
        notify-send "Keep Awake" "Forced Prevented (Screen cannot turn off)"
    fi
    exit 0
fi

# Validate the small public policy API before invoking external audio tools.
case "${1:---condition}" in
    --condition|--status-json) ;;
    *) echo "Unknown idle policy option: $1" >&2; exit 2 ;;
esac
if (( $# > 2 )) || [[ -n "${2:-}" && "$2" != --no-audio ]]; then exit 2; fi

# Keep --check manual-only for Quick Actions; conditions combine both policies.
MANUAL=false
AUDIO=false
[[ $(cat "$STATE_FILE" 2>/dev/null) == 1 ]] && MANUAL=true
if [[ "${2:-}" != --no-audio ]] && is_audio_playing; then AUDIO=true; fi
if [[ "${1:-}" == --status-json ]]; then
    INHIBITED=false
    if $MANUAL || $AUDIO; then INHIBITED=true; fi
    printf '{"manual":%s,"audio":%s,"inhibited":%s}\n' "$MANUAL" "$AUDIO" "$INHIBITED"
    exit 0
fi
! $MANUAL && ! $AUDIO

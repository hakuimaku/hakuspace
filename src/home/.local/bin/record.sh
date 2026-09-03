#!/usr/bin/env bash

# This script is used to record the screen and audio using wl-screenrec and PipeWire
# It sets up a virtual audio sink to combine microphone and system audio, and manages the recording process
# 3 modes are available: Only Sound, Micro and Sound, No Sound

# Load configurations
[ -f "$HOME/hakuspace-control/main_setting.sh" ] && source "$HOME/hakuspace-control/main_setting.sh"

# Defaults
SCREENREC_SAVE_DIR=${SCREENREC_SAVE_DIR:-"$HOME/Videos"}
REC_COMMAND=${REC_COMMAND:-"wl-screenrec"}
REC_OPTS=${REC_OPTS:-"--max-fps 60"}

PID_FILE="/tmp/recording_pid"
TIME_FILE="/tmp/recording_time"
AUDIO_MODULES_FILE="/tmp/recording_audio_modules"
KEEPALIVE_PID_FILE="/tmp/recording_keepalive_pid"
COMBINED_SINK_NAME="rec_combined_sink"
LOCKED_SAMPLE_RATE="${SCREENREC_LOCK_RATE:-48000}"
LOCKED_QUANTUM="${SCREENREC_LOCK_QUANTUM:-1024}"

# Print debug directly to terminal
debug_log() {
    if [ "${SCREENREC_DEBUG:-0}" = "1" ]; then
        echo "[$(date +%H:%M:%S) DEBUG] $*"
    fi
}

# Dependency checks
if ! command -v "$REC_COMMAND" &> /dev/null || ! command -v pactl &> /dev/null; then
    notify-send -u critical "Recording System" "Missing dependencies ($REC_COMMAND or pactl)!" -i dialog-error
    exit 1
fi

mkdir -p "$SCREENREC_SAVE_DIR"

# Setup virtual null-sink and loopbacks for mic + system audio
setup_virtual_audio() {
    local mic_device="$1"
    local real_sink="$2"
    local system_monitor="${real_sink}.monitor"
    
    debug_log "Init virtual audio: mic=$mic_device | sink=$real_sink"
    if [ -z "$real_sink" ]; then return 1; fi

    rm -f "$AUDIO_MODULES_FILE"

    # 1. Create null-sink
    local null_sink_module_id
    null_sink_module_id=$(pactl load-module module-null-sink \
        sink_name="$COMBINED_SINK_NAME" \
        sink_properties=device.description="RecordingCombinedAudio" 2>/dev/null)
    
    if [ -z "$null_sink_module_id" ]; then return 1; fi
    echo "$null_sink_module_id" >> "$AUDIO_MODULES_FILE"

    # Force default sink back to real sink to prevent feedback loops
    pactl set-default-sink "$real_sink" 2>/dev/null

    # 2. Loopback mic to null-sink
    local loopback_mic_id
    loopback_mic_id=$(pactl load-module module-loopback \
        source="$mic_device" \
        sink="$COMBINED_SINK_NAME" \
        latency_msec=1 2>/dev/null)
    
    if [ -z "$loopback_mic_id" ]; then
        teardown_virtual_audio
        return 1
    fi
    echo "$loopback_mic_id" >> "$AUDIO_MODULES_FILE"

    # Prevent recursive loopback
    if [ "$system_monitor" = "${COMBINED_SINK_NAME}.monitor" ]; then
        teardown_virtual_audio
        return 1
    fi

    # 3. Loopback system audio to null-sink
    local loopback_sys_id
    loopback_sys_id=$(pactl load-module module-loopback \
        source="$system_monitor" \
        sink="$COMBINED_SINK_NAME" \
        latency_msec=1 2>/dev/null)

    if [ -z "$loopback_sys_id" ]; then
        teardown_virtual_audio
        return 1
    fi
    echo "$loopback_sys_id" >> "$AUDIO_MODULES_FILE"

    return 0
}

# Remove virtual audio modules
teardown_virtual_audio() {
    if [ -f "$AUDIO_MODULES_FILE" ]; then
        tac "$AUDIO_MODULES_FILE" | while read -r module_id; do
            [ -n "$module_id" ] && pactl unload-module "$module_id" 2>/dev/null
        done
        rm -f "$AUDIO_MODULES_FILE"
        debug_log "Virtual audio modules unloaded"
    fi
}

# Lock PipeWire rate/quantum to prevent renegotiation crashes during stream pause
lock_pipewire_rate() {
    if ! command -v pw-metadata &> /dev/null; then return 1; fi
    pw-metadata -n settings 0 clock.force-rate "$LOCKED_SAMPLE_RATE" 2>/dev/null
    pw-metadata -n settings 0 clock.force-quantum "$LOCKED_QUANTUM" 2>/dev/null
    debug_log "Locked rate=$LOCKED_SAMPLE_RATE, quantum=$LOCKED_QUANTUM"
}

unlock_pipewire_rate() {
    if command -v pw-metadata &> /dev/null; then
        pw-metadata -n settings 0 clock.force-rate 0 2>/dev/null
        pw-metadata -n settings 0 clock.force-quantum 0 2>/dev/null
        debug_log "Unlocked PipeWire rate and quantum"
    fi
}

# Prevent default sink from auto-suspending by feeding it silent data
start_keepalive_silence() {
    local real_sink="$1"
    if [ -z "$real_sink" ] || ! command -v pacat &> /dev/null; then return 1; fi

    ( pacat --device="$real_sink" --raw --rate=48000 --channels=2 --format=s16le < /dev/zero & echo $! > "$KEEPALIVE_PID_FILE" ) 2>/dev/null
    sleep 0.05
    debug_log "Keepalive started on $real_sink"
}

stop_keepalive_silence() {
    if [ -f "$KEEPALIVE_PID_FILE" ]; then
        kill "$(cat "$KEEPALIVE_PID_FILE")" 2>/dev/null
        rm -f "$KEEPALIVE_PID_FILE"
        debug_log "Keepalive stopped"
    fi
}

# Cleanup on exit or interrupt
trap 'teardown_virtual_audio; stop_keepalive_silence; unlock_pipewire_rate' EXIT INT TERM

stop_recording() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill -SIGINT "$PID" 2>/dev/null
        while ps -p "$PID" > /dev/null 2>&1; do sleep 0.1; done
        
        rm -f "$PID_FILE" "$TIME_FILE"
        teardown_virtual_audio
        stop_keepalive_silence
        unlock_pipewire_rate
        
        notify-send -u normal "Recording System" "Saved Video" -i video-display
        debug_log "Recording stopped and saved"
    fi
}

start_recording() {
    options="󰑊 Only Sound\n󰍬 Micro and Sound\n󰔊 No Sound"
    chosen=$(echo -e "$options" | rofi -dmenu -i -p "Select Mode:" -theme-str "window { width: 35%; }")
    if [ -z "$chosen" ]; then exit 0; fi

    FILENAME="recording_$(date +%Y%m%d_%H%M%S).mp4"
    FILEPATH="$SCREENREC_SAVE_DIR/$FILENAME"
    
    # Get actual default sink BEFORE creating virtual ones
    REAL_SINK=$(pactl get-default-sink 2>/dev/null)
    if [ -z "$REAL_SINK" ]; then
        notify-send -u critical "Recording System" "Default sink not found!" -i dialog-error
        exit 1
    fi

    debug_log "Starting record mode: $chosen | Real sink: $REAL_SINK"

    case "$chosen" in
        *"Only Sound")
            lock_pipewire_rate
            start_keepalive_silence "$REAL_SINK"
            $REC_COMMAND $REC_OPTS --audio --audio-device "${REAL_SINK}.monitor" -f "$FILEPATH" &
            MSG="Recording: System Audio"
            ;;
        *"Micro and Sound")
            # Filter for physical mics only
            AUDIO_DEVICE=$(pactl list short sources | awk '{print $2}' | grep -viE '\.monitor$' | rofi -dmenu -i -p "Select Mic/Source:" -theme-str "window { width: 70%; }")
            if [ -z "$AUDIO_DEVICE" ]; then exit 0; fi

            lock_pipewire_rate
            start_keepalive_silence "$REAL_SINK"

            if ! setup_virtual_audio "$AUDIO_DEVICE" "$REAL_SINK"; then
                stop_keepalive_silence
                unlock_pipewire_rate
                exit 1
            fi

            $REC_COMMAND $REC_OPTS --audio --audio-device "${COMBINED_SINK_NAME}.monitor" -f "$FILEPATH" &
            MSG="Recording: Mic + System Audio"
            ;;
        *"No Sound")
            $REC_COMMAND $REC_OPTS -f "$FILEPATH" &
            MSG="Recording: No Sound"
            ;;
    esac

    echo $! > "$PID_FILE"
    notify-send "Recording System" "$MSG" -i video-display -t 1000

    # Timer loop
    SEC=0
    while [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; do
        MIN=$((SEC / 60))
        S=$((SEC % 60))
        printf "%02d:%02d" $MIN $S > "$TIME_FILE"
        sleep 1
        SEC=$((SEC + 1))
    done

    # Cleanup if wl-screenrec exits on its own
    rm -f "$PID_FILE" "$TIME_FILE"
    teardown_virtual_audio
    stop_keepalive_silence
    unlock_pipewire_rate
}

if [ -f "$PID_FILE" ]; then
    stop_recording
else
    start_recording
fi
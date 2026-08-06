#!/usr/bin/env bash

# Include SCREENREC_SAVE_DIR & REC_COMMAND & REC_OPTS settings
source "$HOME/hakuspace-control/main_setting.sh"

# Fallback values if not set in main_setting.sh
SCREENREC_SAVE_DIR=${SCREENREC_SAVE_DIR:-"$HOME/Videos"}
REC_COMMAND=${REC_COMMAND:-"wl-screenrec"}
REC_OPTS=${REC_OPTS:-"--max-fps 60 --codec avc --encode-pixfmt nv12"}

PID_FILE="/tmp/recording_pid"
TIME_FILE="/tmp/recording_time"

# Check dependency
if ! command -v "$REC_COMMAND" &> /dev/null; then
    notify-send -u critical "Recording System" "Error: $REC_COMMAND is not installed!" -i dialog-error
    echo "Error: $REC_COMMAND is not installed. Please install it first."
    exit 1
fi

mkdir -p "$SCREENREC_SAVE_DIR"

stop_recording() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        
        kill -SIGINT "$PID"
        
        while ps -p $PID > /dev/null; do sleep 0.1; done
        
        rm -f "$PID_FILE"
        rm -f "$TIME_FILE"
        notify-send -u normal "Recording System" "Saved Video" -i video-display
    fi
}

start_recording() {
    options="󰑊 Only Sound\n󰍬 Micro and Sound\n󰔊 No Sound"
    
    chosen=$(echo -e "$options" | rofi -dmenu -i -p "Select Mode:" \
    -theme-str "window { width: 35%; }")

    if [ -z "$chosen" ]; then
        exit 0
    fi

    FILENAME="recording_$(date +%Y%m%d_%H%M%S).mp4"
    FILEPATH="$SCREENREC_SAVE_DIR/$FILENAME"
    
    case "$chosen" in
        *"Only Sound")
            $REC_COMMAND $REC_OPTS --audio --audio-device default.monitor -f "$FILEPATH" &
            MSG="Recording: System Audio"
            ;;
        *"Micro and Sound")
            # Record audio from the default device (usually the microphone).
            # If you want to mix both game audio + mic, you need to set up loopback on Pipewire.
            $REC_COMMAND $REC_OPTS --audio -f "$FILEPATH" &
            MSG="Recording: Microphone/Default"
            ;;
        *"No Sound")
            # Only record the screen, no audio.
            $REC_COMMAND $REC_OPTS -f "$FILEPATH" &
            MSG="Recording: No Sound"
            ;;
    esac

    echo $! > "$PID_FILE"
    notify-send "Recording System" "$MSG" -i video-display -t 1000
    
    SEC=0
    while [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null; do
        MIN=$((SEC / 60))
        S=$((SEC % 60))
        printf "%02d:%02d" $MIN $S > "$TIME_FILE"
        sleep 1
        SEC=$((SEC + 1))
    done
    
    rm -f "$PID_FILE" "$TIME_FILE"
}

if [ -f "$PID_FILE" ]; then
    stop_recording
else
    start_recording
fi
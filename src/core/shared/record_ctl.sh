#!/usr/bin/env bash

# Headless screen-recording controller.
# Owns capture/audio lifecycle and explicit mode/source actions; picker UI lives
# in the Classic frontend.

set -u

[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

SCREENREC_SAVE_DIR=${SCREENREC_SAVE_DIR:-"$HOME/Videos"}
REC_COMMAND=${REC_COMMAND:-"gpu-screen-recorder"}
REC_OPTS=${REC_OPTS:-"-f 60"}

PID_FILE=${SCREENREC_PID_FILE:-"/tmp/recording_pid"}
TIME_FILE=${SCREENREC_TIME_FILE:-"/tmp/recording_time"}
MODE_FILE=${SCREENREC_MODE_FILE:-"/tmp/recording_mode"}
OUTPUT_FILE=${SCREENREC_OUTPUT_FILE:-"/tmp/recording_output"}
SOURCE_FILE=${SCREENREC_SOURCE_FILE:-"/tmp/recording_source"}

usage() {
    cat <<'EOF_HELP'
Usage: record_ctl.sh <COMMAND> [ARGS]

Commands:
    status [--json]                 Show recorder state
    list-modes [--json]             List stable recording mode IDs
    list-sources [--json]           List physical microphone/source IDs
    start <MODE> [--source <ID>] [--target <screen|portal>]    Start recording
    stop                            Stop the active recording
    -h, --help                      Show this help message

Modes:
    system-audio    Capture screen + system audio
    mic-system      Capture screen + microphone + system audio
    no-audio        Capture screen without audio

Targets:
    screen          Capture primary screen directly (default)
    portal          Prompt xdg-desktop-portal screen/window chooser
EOF_HELP
}

debug_log() {
    if [[ "${SCREENREC_DEBUG:-0}" == "1" ]]; then
        printf '[%(%H:%M:%S)T DEBUG] %s\n' -1 "$*" >&2
    fi
}

json_escape() {
    local value=${1-}
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

process_running() {
    local pid=$1 stat
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    stat=$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    [[ -n "$stat" && "$stat" != Z* ]]
}

is_recording() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null) || return 1
    process_running "$pid"
}

read_state_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        cat "$file" 2>/dev/null || true
    fi
}

status_cmd() {
    if [[ $# -gt 1 ]]; then
        printf 'record_ctl.sh: status accepts at most --json.\n' >&2
        return 2
    fi
    local format=${1:-}
    if [[ -n "$format" && "$format" != "--json" ]]; then
        printf 'record_ctl.sh: status accepts only --json.\n' >&2
        return 2
    fi

    local recording=false pid='' elapsed='' mode='' output='' source=''
    if is_recording; then
        recording=true
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
    fi
    elapsed=$(read_state_file "$TIME_FILE")
    mode=$(read_state_file "$MODE_FILE")
    output=$(read_state_file "$OUTPUT_FILE")
    source=$(read_state_file "$SOURCE_FILE")

    if [[ "$format" == "--json" ]]; then
        printf '{"recording":%s,"pid":' "$recording"
        if [[ -n "$pid" ]]; then printf '%s' "$pid"; else printf 'null'; fi
        printf ',"elapsed":"%s","mode":"%s","output":"%s","source":"%s"}\n' \
            "$(json_escape "$elapsed")" "$(json_escape "$mode")" \
            "$(json_escape "$output")" "$(json_escape "$source")"
    elif [[ "$recording" == true ]]; then
        printf 'recording\n'
    else
        printf 'idle\n'
    fi
}

list_modes() {
    if [[ $# -gt 1 ]]; then
        printf 'record_ctl.sh: list-modes accepts at most --json.\n' >&2
        return 2
    fi
    local format=${1:-}
    if [[ -n "$format" && "$format" != "--json" ]]; then
        printf 'record_ctl.sh: list-modes accepts only --json.\n' >&2
        return 2
    fi
    if [[ "$format" == "--json" ]]; then
        printf '[{"id":"system-audio"},{"id":"mic-system"},{"id":"no-audio"}]\n'
    else
        printf '%s\n' system-audio mic-system no-audio
    fi
}

require_pactl() {
    if ! command -v pactl >/dev/null 2>&1; then
        printf 'record_ctl.sh: missing dependency: pactl\n' >&2
        return 1
    fi
}

list_sources() {
    if [[ $# -gt 1 ]]; then
        printf 'record_ctl.sh: list-sources accepts at most --json.\n' >&2
        return 2
    fi
    local format=${1:-}
    if [[ -n "$format" && "$format" != "--json" ]]; then
        printf 'record_ctl.sh: list-sources accepts only --json.\n' >&2
        return 2
    fi
    require_pactl || return 1

    local sources=()
    mapfile -t sources < <(pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/ {print $2}')

    if [[ "$format" == "--json" ]]; then
        local first=1 source
        printf '['
        for source in "${sources[@]}"; do
            (( first )) || printf ','
            printf '{"id":"%s"}' "$(json_escape "$source")"
            first=0
        done
        printf ']\n'
    elif (( ${#sources[@]} > 0 )); then
        printf '%s\n' "${sources[@]}"
    fi
}

source_exists() {
    local wanted=$1 source
    while IFS= read -r source; do
        [[ "$source" == "$wanted" ]] && return 0
    done < <(list_sources)
    return 1
}

cleanup_runtime() {
    local output_file
    output_file=$(read_state_file "$OUTPUT_FILE")
    [[ -n "$output_file" ]] && rm -f "${output_file}.ts"
    rm -f "$PID_FILE" "$TIME_FILE" "$MODE_FILE" "$OUTPUT_FILE" "$SOURCE_FILE"
}

stop_recording() {
    if ! is_recording; then
        # Clean stale state without treating it as a recording.
        cleanup_runtime
        return 3
    fi

    local pid had_started=0
    pid=$(cat "$PID_FILE")
    [[ -f "$TIME_FILE" ]] && had_started=1
    kill -SIGINT "$pid" 2>/dev/null || true
    while process_running "$pid"; do
        sleep 0.1
    done
    cleanup_runtime

    if (( had_started )) && command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal "Recording System" "Saved Video" -i video-display
    fi
    debug_log "Recording stopped and saved"
}

start_recording() {
    local mode=${1:-}
    shift || true
    local source='' target=''

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                [[ $# -ge 2 ]] || { printf 'record_ctl.sh: --source requires an ID.\n' >&2; return 2; }
                source=$2
                shift 2
                ;;
            --target)
                [[ $# -ge 2 ]] || { printf 'record_ctl.sh: --target requires screen or portal.\n' >&2; return 2; }
                target=$2
                shift 2
                ;;
            *)
                printf 'record_ctl.sh: unknown start argument: %s\n' "$1" >&2
                return 2
                ;;
        esac
    done

    case "$mode" in
        system-audio|mic-system|no-audio) ;;
        '') printf 'record_ctl.sh: start requires a mode.\n' >&2; return 2 ;;
        *) printf 'record_ctl.sh: unknown mode: %s\n' "$mode" >&2; return 2 ;;
    esac

    if [[ -n "$target" && "$target" != screen && "$target" != portal ]]; then
        printf 'record_ctl.sh: unknown target: %s\n' "$target" >&2
        return 2
    fi

    if is_recording; then
        printf 'record_ctl.sh: a recording is already active.\n' >&2
        return 4
    fi
    if ! command -v "$REC_COMMAND" >/dev/null 2>&1; then
        printf 'record_ctl.sh: missing dependency: %s\n' "$REC_COMMAND" >&2
        return 1
    fi

    if [[ "$mode" == mic-system ]]; then
        if [[ -z "$source" ]]; then
            printf 'record_ctl.sh: mic-system requires --source <ID>.\n' >&2
            return 2
        fi
        if ! source_exists "$source"; then
            printf 'record_ctl.sh: unknown physical source: %s\n' "$source" >&2
            return 2
        fi
    elif [[ -n "$source" ]]; then
        printf 'record_ctl.sh: --source is only valid with mic-system.\n' >&2
        return 2
    fi

    mkdir -p "$SCREENREC_SAVE_DIR"
    local filename filepath message ts_file
    filename="recording_$(date +%Y%m%d_%H%M%S).mp4"
    filepath="$SCREENREC_SAVE_DIR/$filename"
    ts_file="${filepath}.ts"

    debug_log "Starting record mode: $mode | target: ${target:-default} | source: $source"

    # Only the start lifecycle owns cleanup-on-interrupt. Query commands must be
    # strictly side-effect free and must never tear down an active recording.
    trap 'cleanup_runtime' EXIT INT TERM

    local has_capture_target=0 has_ts_opt=0 opt
    # REC_OPTS intentionally keeps the legacy shell-word semantics.
    # shellcheck disable=SC2086
    for opt in $REC_OPTS; do
        if [[ "$opt" == "-w" || "$opt" == -w=* ]]; then
            has_capture_target=1
        elif [[ "$opt" == "-write-first-frame-ts" || "$opt" == -write-first-frame-ts=* ]]; then
            has_ts_opt=1
        fi
    done

    local -a target_args=() audio_args=() ts_args=()
    if [[ -n "$target" ]]; then
        target_args=(-w "$target")
    elif (( ! has_capture_target )); then
        target_args=(-w screen)
    fi

    if (( ! has_ts_opt )); then
        ts_args=(-write-first-frame-ts yes)
    fi

    case "$mode" in
        system-audio)
            audio_args=(-a default_output)
            message="Recording: System Audio"
            ;;
        mic-system)
            audio_args=(-a "default_output|device:${source}")
            message="Recording: Mic + System Audio"
            ;;
        no-audio)
            message="Recording: No Sound"
            ;;
    esac

    # Ensure no stale timer exists while waiting for portal confirmation.
    rm -f "$TIME_FILE" "$ts_file"

    # shellcheck disable=SC2086
    "$REC_COMMAND" $REC_OPTS "${target_args[@]}" "${ts_args[@]}" "${audio_args[@]}" -o "$filepath" &

    local recorder_pid=$!
    printf '%s\n' "$recorder_pid" > "$PID_FILE"
    printf '%s\n' "$mode" > "$MODE_FILE"
    printf '%s\n' "$filepath" > "$OUTPUT_FILE"
    if [[ -n "$source" ]]; then printf '%s\n' "$source" > "$SOURCE_FILE"; else rm -f "$SOURCE_FILE"; fi

    # Wait until the first video frame is encoded (e.g. after xdg-desktop-portal selection).
    while [[ -f "$PID_FILE" ]] && process_running "$recorder_pid" && [[ ! -f "$ts_file" ]]; do
        sleep 0.1
    done

    if [[ -f "$PID_FILE" ]] && process_running "$recorder_pid" && [[ -f "$ts_file" ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Recording System" "$message" -i video-display -t 1000
        fi

        local sec=0 min rem
        while [[ -f "$PID_FILE" ]] && process_running "$recorder_pid"; do
            min=$((sec / 60))
            rem=$((sec % 60))
            printf '%02d:%02d' "$min" "$rem" > "$TIME_FILE"
            sleep 1
            sec=$((sec + 1))
        done
    elif [[ -f "$filepath" && ! -s "$filepath" ]]; then
        rm -f "$filepath"
    fi

    cleanup_runtime
    trap - EXIT INT TERM
}

command_name=${1:-}
if [[ -n "$command_name" ]]; then shift; fi

case "$command_name" in
    status)
        status_cmd "$@"
        ;;
    list-modes)
        list_modes "$@"
        ;;
    list-sources)
        list_sources "$@"
        ;;
    start)
        start_recording "$@"
        ;;
    stop)
        if [[ $# -ne 0 ]]; then
            printf 'record_ctl.sh: stop does not accept extra arguments.\n' >&2
            exit 2
        fi
        stop_recording
        ;;
    -h|--help)
        usage
        ;;
    '')
        usage >&2
        exit 2
        ;;
    *)
        printf 'record_ctl.sh: unknown command: %s\n' "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac

#!/usr/bin/env bash

# Supervisor for Hikai backend

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: qs_supervisor.sh
Supervisor for the Hikai backend. Keeps hikai running and falls back on crash loop.

Options:
    -h, --help          Show this help message
EOF
    exit 0
fi

RUNTIME_DIR="$(haku_runtime_dir)"
LOG_FILE="$RUNTIME_DIR/qs.log"

MAX_CRASHES=3
CRASH_WINDOW=60
CRASH_TIMESTAMPS=()

while true; do
    # Only run if backend is hikai
    if ! haku_backend_is "hikai"; then
        exit 0
    fi

    # Run hikai
    export QML_XHR_ALLOW_FILE_READ=1
    echo "[$(date -Iseconds)] Starting hikai..." >> "$LOG_FILE"
    qs -c hakuspace >> "$LOG_FILE" 2>&1
    
    EXIT_CODE=$?
    echo "[$(date -Iseconds)] Hikai exited with code $EXIT_CODE" >> "$LOG_FILE"

    # If backend was changed during execution, exit normally
    if ! haku_backend_is "hikai"; then
        exit 0
    fi

    # Check for crash loop
    NOW=$(date +%s)
    
    # Remove timestamps older than window
    NEW_TIMESTAMPS=()
    for ts in "${CRASH_TIMESTAMPS[@]}"; do
        if (( NOW - ts <= CRASH_WINDOW )); then
            NEW_TIMESTAMPS+=("$ts")
        fi
    done
    CRASH_TIMESTAMPS=("${NEW_TIMESTAMPS[@]}")
    CRASH_TIMESTAMPS+=("$NOW")
    
    if (( ${#CRASH_TIMESTAMPS[@]} >= MAX_CRASHES )); then
        echo "[$(date -Iseconds)] Crash loop detected (${#CRASH_TIMESTAMPS[@]} crashes in $CRASH_WINDOW s). Falling back to classic." >> "$LOG_FILE"
        ~/.local/bin/haku_backend.sh set classic
        exit 1
    fi
    
    sleep 1
done

#!/usr/bin/env bash

# Supervisor for Quickshell backend

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Complete filename migration before any state consumer starts.
if [[ -f "$SCRIPT_DIR/haku_state.sh" ]]; then
    source "$SCRIPT_DIR/haku_state.sh"
else
    source "$SCRIPT_DIR/../lib/haku_state.sh"
fi
haku_state_migrate || exit 1
source "$SCRIPT_DIR/haku_backend_lib.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: qs_supervisor.sh
Supervisor for the Quickshell backend. Keeps quickshell running and falls back on crash loop.

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
    # Only run if backend is quickshell
    if ! haku_backend_is $QS_BACKEND_NAME; then
        exit 0
    fi

    # Run quickshell
    if haku_qs_alive; then
        echo "[$(date -Iseconds)] Quickshell already running, waiting..." >> "$LOG_FILE"
        while haku_qs_alive; do sleep 1; done
    fi
    # Both login and backend switching pass here before AppState starts watching.
    "$SCRIPT_DIR/hikai_chrome_state_ctl.py" migrate >> "$LOG_FILE" 2>&1 || exit 1
    echo "[$(date -Iseconds)] Starting quickshell..." >> "$LOG_FILE"
    QT_QPA_PLATFORM=wayland python3 "$SCRIPT_DIR/wallpaper_ctl.py" launch -c hakuspace >> "$LOG_FILE" 2>&1
    
    EXIT_CODE=$?
    echo "[$(date -Iseconds)] Quickshell exited with code $EXIT_CODE" >> "$LOG_FILE"

    # If backend was changed during execution, exit normally
    if ! haku_backend_is $QS_BACKEND_NAME; then
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
        # Detach recovery so stopping this supervisor cannot kill the rollback owner.
        setsid -f "$HOME/.local/bin/haku_backend.sh" --recover </dev/null >> "$LOG_FILE" 2>&1
        exit 1
    fi
    
    sleep 1
done

#!/usr/bin/env bash

# Serialize idle ownership across login, shell switches, and recovery.
IDLE_CTL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$IDLE_CTL_DIR/haku_backend_lib.sh" ]]; then
    source "$IDLE_CTL_DIR/haku_backend_lib.sh"
else
    source "$IDLE_CTL_DIR/../lib/haku_backend_lib.sh"
fi
exec 8>"$(haku_runtime_dir)/idle-backend.lock" || exit 1
flock -w 10 8 || exit 1

# Wait for daemon exit before native idle can acquire ownership.
stop_classic() {
    local deadline=$((SECONDS + 5))
    pkill -u "$(id -u)" -x hypridle 2>/dev/null || true
    while pgrep -u "$(id -u)" -x hypridle >/dev/null; do
        (( SECONDS < deadline )) || { echo "hypridle did not stop" >&2; return 1; }
        sleep 0.05
    done
}

# Preserve a healthy daemon and repair duplicate Classic owners.
start_classic() {
    local count deadline=$((SECONDS + 5))
    count=$(pgrep -u "$(id -u)" -x hypridle | wc -l)
    [[ "$count" == 1 ]] && return 0
    command -v hypridle >/dev/null || { echo "Classic idle requires hypridle" >&2; return 1; }
    (( count == 0 )) || stop_classic || return 1
    hypridle </dev/null >>"$(haku_runtime_dir)/hypridle.log" 2>&1 8>&- 9>&- &
    while [[ $(pgrep -u "$(id -u)" -x hypridle | wc -l) != 1 ]]; do
        (( SECONDS < deadline )) || { echo "hypridle failed to start" >&2; return 1; }
        sleep 0.05
    done
}

# Report observable ownership without starting or stopping a daemon.
idle_status() {
    local count
    count=$(pgrep -u "$(id -u)" -x hypridle | wc -l)
    printf '{"backend":"%s","hypridleCount":%s}\n' "$(haku_backend_get)" "$count"
}

case "${1:-reconcile}" in
    reconcile) if haku_backend_is classic; then start_classic; else stop_classic; fi ;;
    start-classic) haku_backend_is classic && start_classic ;;
    stop-classic) stop_classic ;;
    status) idle_status ;;
    *) echo "Usage: $0 {reconcile|start-classic|stop-classic|status}" >&2; exit 2 ;;
esac

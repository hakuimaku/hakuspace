#!/usr/bin/env bash

# Facade for notification center

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: notif.sh [ACTION]
Manage the notification center facade.

Actions:
    toggle              Toggle the notification center
    dnd                 Toggle Do-Not-Disturb mode
    clear               Clear all notifications
    count               Get the number of notifications
    -h, --help          Show this help message
EOF
    exit 0
fi

ACTION="${1:-toggle}"

if haku_backend_is "classic"; then
    case "$ACTION" in
        toggle)
            swaync-client -t -sw
            ;;
        dnd)
            swaync-client -d
            ;;
        clear)
            swaync-client -C
            ;;
        count)
            swaync-client -c
            ;;
        *)
            echo "Usage: $0 {toggle|dnd|clear|count}"
            exit 1
            ;;
    esac
else
    case "$ACTION" in
        toggle)
            haku_qs_ipc notif toggleCenter
            ;;
        dnd)
            haku_qs_ipc notif toggleDnd
            ;;
        clear)
            haku_qs_ipc notif clearAll
            ;;
        count)
            # Quickshell doesn't easily return output to CLI without a return fifo for IPC in current spec, 
            # but IPC contract says it returns int. `qs ipc call` might print to stdout.
            haku_qs_ipc notif count
            ;;
        *)
            echo "Usage: $0 {toggle|dnd|clear|count}"
            exit 1
            ;;
    esac
fi

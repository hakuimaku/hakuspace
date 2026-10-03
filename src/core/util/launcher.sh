#!/usr/bin/env bash

# Facade for application launcher and emoji picker

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: launcher.sh [MODE]
Manage the application launcher facade.

Modes:
    drun                Open the application launcher (default)
    emoji               Open the emoji picker
    -h, --help          Show this help message
EOF
    exit 0
fi

MODE="${1:-drun}"

if haku_backend_is "classic"; then
    if [[ "$MODE" == "emoji" ]]; then
        exec rofi -modi emoji -show emoji
    else
        exec rofi -show drun
    fi
else
    if [[ "$MODE" == "emoji" ]]; then
        haku_qs_ipc launcher open emoji
    else
        haku_qs_ipc launcher open drun
    fi
fi

#!/usr/bin/env bash

# Early session startup for backends

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

if [[ "${1:-}" == "--early" ]]; then
    if [[ ! -f "$STATE_DIR/haku_space_state" ]] && [[ -f "$STATE_DIR/haku_shell_state" ]]; then

        cp "$STATE_DIR/haku_shell_state" "$STATE_DIR/haku_space_state"

        rm -f "$STATE_DIR/haku_shell_state"

    fi
    if haku_backend_is "classic"; then
        swaync &
    else
        # Quickshell early start
        # Reset runtime states
        rm -f /tmp/cava-layer.pid
        
        setsid -f ~/.local/bin/qs_supervisor.sh >/dev/null 2>&1
        
        # Wait up to 3s for health check, but never block
        for ((i=0; i<3; i++)); do
            sleep 1
            if qs -c hakuspace ipc call shell ping 2>/dev/null | grep -q "pong"; then
                break
            fi
        done
    fi
fi

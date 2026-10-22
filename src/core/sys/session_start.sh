#!/usr/bin/env bash

# Early session startup for backends

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Complete filename migration before any state consumer starts.
if [[ -f "$SCRIPT_DIR/haku_state.sh" ]]; then
    source "$SCRIPT_DIR/haku_state.sh"
else
    source "$SCRIPT_DIR/../lib/haku_state.sh"
fi
haku_state_migrate || exit 1
source "$SCRIPT_DIR/haku_backend_lib.sh"

if [[ "${1:-}" == "--early" ]]; then
    # Reconcile installed assets after updates or restores without failing login.
    if [[ -x "$HOME/.local/bin/appearance_ctl.sh" ]]; then
        "$HOME/.local/bin/appearance_ctl.sh" apply || true
    fi
    if [[ -x "$HOME/.local/bin/theme_ctl.sh" ]]; then
        "$HOME/.local/bin/theme_ctl.sh" apply || true
    fi
    if haku_backend_is "classic"; then
        pgrep -x swaync >/dev/null || swaync &
    else
        pkill -x swaync
        # Quickshell early start
        # Reset runtime states
        rm -f /tmp/cava-layer.pid
        
        if ! pgrep -f qs_supervisor.sh >/dev/null 2>&1; then
            setsid -f ~/.local/bin/qs_supervisor.sh >/dev/null 2>&1
        fi
        
        # Wait up to 3s for health check, but never block
        for ((i=0; i<3; i++)); do
            sleep 1
            if qs -c hakuspace ipc call shell ping 2>/dev/null | grep -q "pong"; then
                break
            fi
        done
    fi
fi

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
    # Select the idle owner before starting either shell.
    "$HOME/.local/bin/idle_backend_ctl.sh" reconcile || exit 1
    # Restore effective opaque overrides before rendering or starting either shell.
    "$HOME/.local/bin/opaque_theme.sh" sync "$(haku_backend_get)" || true
    # Reconcile installed assets after updates or restores without failing login.
    if [[ -x "$HOME/.local/bin/appearance_ctl.sh" ]]; then
        "$HOME/.local/bin/appearance_ctl.sh" apply || true
    fi
    if [[ -x "$HOME/.local/bin/theme_ctl.sh" ]]; then
        "$HOME/.local/bin/theme_ctl.sh" apply || true
    fi
    if haku_backend_is "classic"; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
        python3 "$HOME/.local/bin/kitty_theme_ctl.py" dark || true
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

#!/usr/bin/env bash

# Early session startup for backends

# Complete filename migration before any state consumer starts.
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
haku_state_migrate || exit 1

if [[ "${1:-}" == "--early" ]]; then
    # Select the idle owner before starting either shell.
    "$HAKU_BIN_DIR/idle_backend_ctl.sh" reconcile || exit 1
    # Reconcile installed assets after updates or restores without failing login.
    if [[ -x "$HAKU_BIN_DIR/appearance_ctl.sh" ]]; then
        "$HAKU_BIN_DIR/appearance_ctl.sh" apply || true
    fi
    if [[ -x "$HAKU_BIN_DIR/theme_ctl.sh" ]]; then
        "$HAKU_BIN_DIR/theme_ctl.sh" apply || true
    fi
    if haku_backend_is "classic"; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
        python3 "$HAKU_BIN_DIR/kitty_theme_ctl.py" dark || true
        pgrep -x swaync >/dev/null || swaync &
    else
        pkill -x swaync
        # Quickshell early start
        # Reset runtime states
        rm -f /tmp/cava-layer.pid
        
        if ! pgrep -f qs_supervisor.sh >/dev/null 2>&1; then
            setsid -f "$HAKU_BIN_DIR/qs_supervisor.sh" >/dev/null 2>&1
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

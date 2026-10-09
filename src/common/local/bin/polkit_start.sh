#!/usr/bin/env bash

if POLKIT_BIN=$(ls -d /nix/store/*-mate-polkit-*/libexec/polkit-mate-authentication-agent-1 2>/dev/null | head -n 1) && [ -n "$POLKIT_BIN" ]; then
    exec "$POLKIT_BIN"
elif [ -f /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 ]; then
    exec /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
else
    echo "Error: mate-polkit binary not found!" >&2
    notify-send "Error: mate-polkit binary not found!"
    exit 1
fi
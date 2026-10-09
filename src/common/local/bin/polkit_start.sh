#!/usr/bin/env bash

killall -q polkit-mate-authentication-agent-1
while pgrep -u $UID -x polkit-mate-authentication-agent-1 >/dev/null; do sleep 0.1; done

if POLKIT_BIN=$(ls -d /nix/store/*-mate-polkit-*/libexec/polkit-mate-authentication-agent-1 2>/dev/null | head -n 1) && [ -n "$POLKIT_BIN" ]; then
    exec "$POLKIT_BIN"
elif [ -f /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 ]; then
    exec /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
else
    echo "Error: mate-polkit binary not found!" >&2
    notify-send "Error: mate-polkit binary not found!"
    exit 1
fi
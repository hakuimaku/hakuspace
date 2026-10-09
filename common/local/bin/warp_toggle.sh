#!/bin/bash

# This script toggles the Cloudflare WARP connection on or off.

# Check dependency
if ! command -v warp-cli &> /dev/null; then
    echo "warp-cli could not be found. Please install cloudflare-warp-bin."
    notify-send "Cloudflare WARP" "warp-cli not found. Please install cloudflare-warp-bin."
    exit 1
fi

STATUS=$(warp-cli status | grep -q 'Connected' && echo true || echo false)

if [[ $STATUS == true ]]; then
    notify-send "Cloudflare WARP" "Disconnected"
    echo "Disconnected"
    warp-cli disconnect
else
    notify-send "Cloudflare WARP" "Connected"
    echo "Connected"
    warp-cli connect
fi
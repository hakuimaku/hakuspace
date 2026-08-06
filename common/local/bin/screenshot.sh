#!/usr/bin/env bash

# Include SCREENSHOT_DIR
source "$HOME/hakuspace-control/main_setting.sh"
SCREENSHOT_DIR=${SCREENSHOT_DIR:-"$HOME/Pictures/Screenshots"}
mkdir -p "$SCREENSHOT_DIR"

timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
file="${SCREENSHOT_DIR}/screenshot_${timestamp}.png"

usage() {
    cat <<'EOF'
Usage:
    screenshot.sh              # Select region
    screenshot.sh --fullscreen # Fullscreen
EOF
}

mode="region"
if [[ "${1:-}" == "--fullscreen" ]]; then
    mode="fullscreen"
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
elif [[ $# -gt 0 ]]; then
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 1
fi

for cmd in grim wl-copy; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing dependency: $cmd" >&2
        exit 1
    }
done

if [[ "$mode" == "region" ]]; then
    command -v slurp >/dev/null 2>&1 || {
        echo "Missing dependency: slurp (required for region mode)" >&2
        exit 1
    }
    geometry="$(slurp)" || exit 0
    grim -g "$geometry" "$file"
else
    grim "$file"
fi

wl-copy < "$file"
echo "Saved & copied: $file"
notify-send "Screenshot saved & copied" "$file"
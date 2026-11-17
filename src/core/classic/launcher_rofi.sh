#!/usr/bin/env bash
set -euo pipefail

# Classic launcher frontend. Presentation only; backend routing stays in
# launcher.sh so Hikai can use the Quickshell launcher IPC instead of Rofi.

MODE="${1:-drun}"

case "$MODE" in
    drun)
        exec rofi -show drun -theme styles/launcher.rasi
        ;;
    emoji)
        exec rofi -modi emoji -show emoji -theme styles/launcher.rasi
        ;;
    -h|--help)
        cat <<'HELP'
Usage: launcher_rofi.sh [drun|emoji]
Open the Classic Rofi launcher frontend.
HELP
        ;;
    *)
        printf 'launcher_rofi.sh: unknown mode: %s\n' "$MODE" >&2
        exit 2
        ;;
esac

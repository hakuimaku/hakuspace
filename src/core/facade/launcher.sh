#!/usr/bin/env bash
set -euo pipefail

# Public launcher facade. Keep this basename stable for existing keybinds.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'HELP'
Usage: launcher.sh [MODE]
Manage the application launcher facade.

Modes:
    drun                Open the application launcher (default)
    emoji               Open the emoji picker
    -h, --help          Show this help message
HELP
    exit 0
fi

MODE="${1:-drun}"
case "$MODE" in
    drun|emoji) ;;
    *)
        printf 'launcher.sh: unknown mode: %s\n' "$MODE" >&2
        exit 2
        ;;
esac

if haku_backend_is "classic"; then
    exec "$HAKU_BIN_DIR/launcher_rofi.sh" "$MODE"
fi

haku_qs_ipc launcher open "$MODE"

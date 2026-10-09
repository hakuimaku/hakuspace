#!/usr/bin/env bash
set -euo pipefail

# Public launcher facade. Keep this basename stable for existing keybinds.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/../lib/$name" \
        "$SCRIPT_DIR/../frontend/classic/$name" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'launcher.sh: unable to resolve %s\n' "$name" >&2
    return 1
}

# shellcheck source=/dev/null
source "$(resolve_script haku_backend_lib.sh)"

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
    exec "$(resolve_script launcher_rofi.sh)" "$MODE"
fi

haku_qs_ipc launcher open "$MODE"

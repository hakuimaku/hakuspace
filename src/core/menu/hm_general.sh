#!/usr/bin/env bash
set -euo pipefail

# Preserve the public basename for Classic and source-tree callers.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for adapter in "$SCRIPT_DIR/hm_general_rofi.py" "$SCRIPT_DIR/../frontend/classic/hm_general_rofi.py" "$HOME/.local/bin/hm_general_rofi.py"; do
    if [[ -f "$adapter" ]]; then
        exec python3 "$adapter" "$@"
    fi
done
printf 'hm_general.sh: General menu adapter not found\n' >&2
exit 1

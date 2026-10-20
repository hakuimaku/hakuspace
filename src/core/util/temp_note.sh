#!/usr/bin/env bash
set -euo pipefail

# Resolve the shared backend library in source and flat deployments.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_backend_lib.sh" ]]; then
    HAKU_BACKEND_LIB="$SCRIPT_DIR/haku_backend_lib.sh"
else
    HAKU_BACKEND_LIB="$SCRIPT_DIR/../lib/haku_backend_lib.sh"
fi
# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

# Classic has no floating Temp Note editor.
if haku_backend_is classic; then
    exec notify-send "Temp Note" "Temp Note is not supported in Classic mode."
fi

haku_qs_ipc tempNote toggle

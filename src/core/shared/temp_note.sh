#!/usr/bin/env bash
set -euo pipefail

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

# Classic has no floating Temp Note editor.
if haku_backend_is classic; then
    exec notify-send "Temp Note" "Temp Note is not supported in Classic mode."
fi

haku_qs_ipc tempNote toggle

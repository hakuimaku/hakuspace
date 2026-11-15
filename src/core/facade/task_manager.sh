#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

# Classic has no native floating Task Manager.
if haku_backend_is classic; then
    exec notify-send "Task Manager" "Task Manager is not supported in Classic mode."
fi

haku_qs_ipc taskManager toggle

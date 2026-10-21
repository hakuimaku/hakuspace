#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/haku_backend_lib.sh" ]]; then
    HAKU_BACKEND_LIB="$SCRIPT_DIR/haku_backend_lib.sh"
else
    HAKU_BACKEND_LIB="$SCRIPT_DIR/../lib/haku_backend_lib.sh"
fi
# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

case "${1:-toggle}" in
    toggle) operation=toggleDefault ;;
    open) operation=openDefault ;;
    close) operation=close ;;
    *) printf 'Usage: settings_manager.sh [toggle|open|close]\n' >&2; exit 2 ;;
esac

if haku_backend_is classic; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Settings" "Settings panel is not supported in Classic mode."
    fi
    exit 0
fi

haku_qs_ipc settings "$operation"


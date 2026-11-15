#!/usr/bin/env bash

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

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


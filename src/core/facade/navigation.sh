#!/usr/bin/env bash

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

case "${1:-toggle}" in
    toggle) operation=toggleDefault ;;
    open) operation=openDefault ;;
    close) operation=close ;;
    *) printf 'Usage: navigation.sh [toggle|open|close]\n' >&2; exit 2 ;;
esac

if haku_backend_is classic; then exit 0; fi
haku_qs_ipc navigation "$operation"

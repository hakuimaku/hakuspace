#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

# Keep the public command vocabulary independent of the shell implementation.
case "${1:-overview-toggle}" in
    next) operation=next ;;
    previous) operation=previous ;;
    commit) operation=commit ;;
    cancel) operation=cancel ;;
    overview-toggle) operation=overviewToggle ;;
    *) printf 'Usage: window_navigator.sh [next|previous|commit|cancel|overview-toggle]\n' >&2; exit 2 ;;
esac

if haku_qs_mode; then
    haku_qs_ipc windowNavigator "$operation"
else
    # Classic retains native cycling and the existing scrolloverview plugin.
    case "$operation" in
        next|previous)
            forward=true
            [[ $operation != previous ]] || forward=false
            hyprctl eval "hl.dispatch(hl.dsp.window.cycle_next({next = $forward})); hl.dispatch(hl.dsp.window.bring_to_top())"
            ;;
        overviewToggle) hyprctl eval 'hl.plugin.scrolloverview.overview("toggle all")' ;;
        commit|cancel) : ;;
    esac
fi

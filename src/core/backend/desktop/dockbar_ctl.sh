#!/usr/bin/env bash

# Control the native compact Dockbar request without starting legacy processes.
state_dir="$HOME/.local/state/hakuspace/state"
state_file="$state_dir/dockbar_manual_state"
current=0
[[ "$(cat "$state_file" 2>/dev/null)" == 1 ]] && current=1
case "${1:-}" in
    --status)
        if [[ "$current" == 1 ]]; then printf 'enabled\n'; else printf 'disabled\n'; fi
        exit 0 ;;
    --toggle) next=$((1 - current)) ;;
    --enable) next=1 ;;
    --disable) next=0 ;;
    -h|--help) printf 'Usage: dockbar_ctl.sh --status|--toggle|--enable|--disable\n'; exit 0 ;;
    *) printf 'dockbar_ctl.sh: unknown command\n' >&2; exit 2 ;;
esac
mkdir -p "$state_dir" || exit 1
printf '%s\n' "$next" > "$state_file"

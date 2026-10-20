#!/usr/bin/env bash

# Expose compact Dockbar control through the installed public facade.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for controller in "$SCRIPT_DIR/dockbar_ctl.sh" "$SCRIPT_DIR/../backend/desktop/dockbar_ctl.sh" "$HOME/.local/bin/dockbar_ctl.sh"; do
    if [[ -f "$controller" ]]; then exec bash "$controller" "$@"; fi
done
printf 'dockbar_manager.sh: controller not found\n' >&2
exit 1

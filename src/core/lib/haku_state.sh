#!/usr/bin/env bash

# Shared persistent root and runtime state directory; sourcing is read-only.
HAKU_STATE_ROOT="$HOME/.local/state/hakuspace"
HAKU_STATE_DIR="$HAKU_STATE_ROOT/state"
STATE_DIR="$HAKU_STATE_DIR"
HAKU_STATE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Resolve only registered state keys to quoted, owner-prefixed paths.
haku_state_path() {
    local name
    case "${1:-}" in
        shell.backend) name='[shell].backend' ;;
        shell.haku-space.enabled) name='[shell].haku-space.enabled' ;;
        desktop.waybar.requested) name='[desktop].waybar.requested' ;;
        desktop.waybar.mode) name='[desktop].waybar.mode' ;;
        desktop.taskbar.requested) name='[desktop].taskbar.requested' ;;
        desktop.dockbar.requested) name='[desktop].dockbar.requested' ;;
        desktop.icons.enabled) name='[desktop].icons.enabled' ;;
        desktop.edge-trigger.enabled) name='[desktop].edge-trigger.enabled' ;;
        screen.rounded.enabled) name='[screen].rounded.enabled' ;;
        screen.rounded.dynamic) name='[screen].rounded.dynamic' ;;
        theme.opaque.enabled) name='[theme].opaque.enabled' ;;
        theme.appearance.env) name='[theme].appearance.env' ;;
        system.idle-inhibit.enabled) name='[system].idle-inhibit.enabled' ;;
        cava.enabled) name='[cava].enabled' ;;
        cava.position) name='[cava].position' ;;
        cava.dynamic-position) name='[cava].dynamic-position' ;;
        cava.color-mode) name='[cava].color-mode' ;;
        cava.height) name='[cava].height' ;;
        migration.hikai-chrome-v6.json) name='[migration].hikai-chrome-v6.json' ;;
        *) printf 'Unknown HakuSpace state key: %s\n' "${1:-}" >&2; return 1 ;;
    esac
    printf '%s/%s\n' "$HAKU_STATE_DIR" "$name"
}

# Upgrade legacy files before session consumers or default initialization run.
haku_state_migrate() {
    local migrator="$HAKU_STATE_LIB_DIR/haku_state_migrate.py"
    [[ -f "$migrator" ]] || migrator="$HAKU_STATE_LIB_DIR/../state/haku_state_migrate.py"
    python3 "$migrator"
}

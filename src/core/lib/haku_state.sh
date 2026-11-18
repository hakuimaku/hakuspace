#!/usr/bin/env bash

# Shared persistent root and runtime state directory; sourcing is read-only.
HAKU_BIN_DIR="${HAKU_BIN_DIR:-$HOME/.local/bin}"
HAKU_STATE_ROOT="$HOME/.local/state/hakuspace"
HAKU_STATE_DIR="$HAKU_STATE_ROOT/state"
STATE_DIR="$HAKU_STATE_DIR"

# Resolve only registered state keys to quoted, owner-prefixed paths.
haku_state_path() {
    local name
    case "${1:-}" in
        shell.backend) name='[shell].backend' ;;
        shell.memory-maintenance.json) name='[shell].memory-maintenance.json' ;;
        shell.haku-space.enabled) name='[shell].haku-space.enabled' ;;
        desktop.waybar.requested) name='[desktop].waybar.requested' ;;
        desktop.taskbar.requested) name='[desktop].taskbar.requested' ;;
        desktop.dockbar.requested) name='[desktop].dockbar.requested' ;;
        desktop.icons.enabled) name='[desktop].icons.enabled' ;;
        desktop.icons.positions.json) name='[desktop].icons.positions.json' ;;
        desktop.wallpaper.current.json) name='[desktop].wallpaper.current.json' ;;
        desktop.wallpaper.runtime.json) name='[desktop].wallpaper.runtime.json' ;;
        theme.appearance.env) name='[theme].appearance.env' ;;
        theme.classic.palette) name='[theme].classic.palette' ;;
        theme.classic.palette.effective) name='[theme].classic.palette.effective' ;;
        system.visual-sources.json) name='[system].visual-sources.json' ;;
        system.visual-reconcile.pending) name='[system].visual-reconcile.pending' ;;
        system.idle-inhibit.enabled) name='[system].idle-inhibit.enabled' ;;
        cava.enabled) name='[cava].enabled' ;;
        cava.position) name='[cava].position' ;;
        cava.dynamic-position) name='[cava].dynamic-position' ;;
        cava.color-mode) name='[cava].color-mode' ;;
        cava.height) name='[cava].height' ;;
        migration.hikai-layout-v11.json) name='[migration].hikai-layout-v11.json' ;;
        migration.hikai-chrome-v6.json) name='[migration].hikai-chrome-v6.json' ;;
        *) printf 'Unknown HakuSpace state key: %s\n' "${1:-}" >&2; return 1 ;;
    esac
    printf '%s/%s\n' "$HAKU_STATE_DIR" "$name"
}

# Upgrade legacy files before session consumers or default initialization run.
haku_state_migrate() {
    python3 "$(dirname -- "${BASH_SOURCE[0]}")/haku_state_migrate.py"
}

"""Canonical runtime state paths; resolving a path never creates files."""
from pathlib import Path

# Registered state keys and their owner-prefixed basenames.
STATE_FILES = {
    'shell.backend': '[shell].backend',
    'shell.haku-space.enabled': '[shell].haku-space.enabled',
    'desktop.waybar.requested': '[desktop].waybar.requested',
    'desktop.waybar.mode': '[desktop].waybar.mode',
    'desktop.taskbar.requested': '[desktop].taskbar.requested',
    'desktop.dockbar.requested': '[desktop].dockbar.requested',
    'desktop.icons.enabled': '[desktop].icons.enabled',
    'desktop.wallpaper.current.json': '[desktop].wallpaper.current.json',
    'desktop.wallpaper.runtime.json': '[desktop].wallpaper.runtime.json',
    'desktop.edge-trigger.enabled': '[desktop].edge-trigger.enabled',
    'screen.rounded.enabled': '[screen].rounded.enabled',
    'screen.rounded.dynamic': '[screen].rounded.dynamic',
    'theme.opaque.enabled': '[theme].opaque.enabled',
    'theme.appearance.env': '[theme].appearance.env',
    'system.visual-sources.json': '[system].visual-sources.json',
    'system.visual-reconcile.pending': '[system].visual-reconcile.pending',
    'system.idle-inhibit.enabled': '[system].idle-inhibit.enabled',
    'cava.enabled': '[cava].enabled',
    'cava.position': '[cava].position',
    'cava.dynamic-position': '[cava].dynamic-position',
    'cava.color-mode': '[cava].color-mode',
    'cava.height': '[cava].height',
    'migration.hikai-chrome-v6.json': '[migration].hikai-chrome-v6.json',
}


def state_root():
    """Return the persistent HakuSpace root for the current home."""
    return Path.home() / ".local/state/hakuspace"


def state_path(key):
    """Resolve a registered key without initializing or normalizing its value."""
    return state_root() / "state" / STATE_FILES[key]

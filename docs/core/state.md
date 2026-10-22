# Runtime state

Persistent feature state lives in `~/.local/state/hakuspace/state/`. Each filename begins with its owner's `[domain]` prefix. Renaming changes neither stored values nor feature defaults.

| Key | Filename |
| --- | --- |
| `shell.backend` | `[shell].backend` |
| `shell.haku-space.enabled` | `[shell].haku-space.enabled` |
| `desktop.waybar.requested` | `[desktop].waybar.requested` |
| `desktop.waybar.mode` | `[desktop].waybar.mode` |
| `desktop.taskbar.requested` | `[desktop].taskbar.requested` |
| `desktop.dockbar.requested` | `[desktop].dockbar.requested` |
| `desktop.icons.enabled` | `[desktop].icons.enabled` |
| `desktop.edge-trigger.enabled` | `[desktop].edge-trigger.enabled` |
| `screen.rounded.enabled` | `[screen].rounded.enabled` |
| `screen.rounded.dynamic` | `[screen].rounded.dynamic` |
| `theme.opaque.enabled` | `[theme].opaque.enabled` |
| `theme.appearance.env` | `[theme].appearance.env` |
| `system.idle-inhibit.enabled` | `[system].idle-inhibit.enabled` |
| `cava.enabled` | `[cava].enabled` |
| `cava.position` | `[cava].position` |
| `cava.dynamic-position` | `[cava].dynamic-position` |
| `cava.color-mode` | `[cava].color-mode` |
| `cava.height` | `[cava].height` |
| `migration.hikai-chrome-v6.json` | `[migration].hikai-chrome-v6.json` |

Bash consumers source `haku_state.sh` and call `haku_state_path KEY`. Always quote the returned path: brackets are shell glob characters. Python consumers import `state_path(KEY)` from `haku_state.py`; it returns a `pathlib.Path`. QML watchers and menu indicators use the readonly state properties in `Env.qml`. Resolving a path does not create state or validate/change its value.

Installation/update, early session startup, the Quickshell supervisor, and the backend CLI invoke `haku_state_migrate.py` before reading state or initializing defaults. Migration serializes against other state migrations with a directory lock and opens directories and entries without following symlinks. It preserves existing bytes and permissions, publishes canonical files without replacing an existing entry, and removes identical legacy duplicates. A canonical file always wins a conflict; the different legacy value is retained under `~/.local/state/hakuspace/migration-backup/state-naming-v1/` with a warning. Existing backups are never overwritten. Unsafe entries stop migration with a visible error, so startup does not replace missing canonical state with defaults after a failed upgrade.

The current Haku Space preference takes priority over its two older aliases. The obsolete Taskbar autohide file has no active writer; migration archives it and the desktop context menu no longer reads it. No canonical autohide preference is created.

Generated `taskbar-theme`, `rofi-theme.rasi`, `niri-animation.kdl`, and `theme/` outputs stay outside the runtime `state/` namespace. `/tmp/random_wallpaper_status` also keeps its existing path.

Run `python3 scripts/check_state_schema.py` to verify production path naming and Bash/Python registry parity. `python3 scripts/test_state_naming.py` checks safe upgrades with temporary homes. Both checks are included in the precommit script.

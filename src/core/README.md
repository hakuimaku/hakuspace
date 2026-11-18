# HakuSpace core scripts

`src/core/` is the canonical source tree for HakuSpace shell and Python runtime scripts. The source tree uses a flat one-level taxonomy organized by **shell scope and role**, while deployment intentionally remains flat into `$HAKU_BIN_DIR` (defaulting to `~/.local/bin`).

## Directory taxonomy

```text
src/core/
├── classic/   # Classic-only (Waybar, Rofi, SwayNC, Classic AppBar, Cava layer, Classic adapters)
├── hikai/     # Hikai-only (Quickshell controllers and services)
├── shared/    # Cross-shell backends, engines, theme, WM helpers, utilities
├── facade/    # Public entrypoints used by keybinds, startup, and user CLI
└── lib/       # Shared sourced libraries and schemas (haku_*.sh, haku_*.py)
```

### `classic/`

Classic-only interactive presentation adapters (`*_rofi.sh`, `hm_*_rofi.py`), Waybar/SwayNC/AppBar controllers (`waybar_ctl.sh`, `notif_ctl.sh`, `appbar_ctl.sh`), standalone Classic widgets (`appbar_layer.py`, `wlr_toplevel.py`, `cava_layer.py`), and Classic-specific helpers (`classic_palette.py`).

### `hikai/`

Hikai-only headless controllers and settings stores used by the Quickshell shell (`hikai_settings_ctl.py`, `dockbar_ctl.sh`, `hakucfg_editor_ctl.py`, `avatar_ctl.sh`, `temp_note_ctl.sh`, etc.).

### `shared/`

Cross-shell domain controllers, theming/rendering engines (`gen_style.sh`, `apply_style.sh`, `theme_ctl.sh`, `appearance_ctl.sh`, `wallpaper_ctl.sh`, `haku_icon_accent.py`), standalone desktop widgets (`desktop_icons.py`), and shared utilities (`pinned_apps_ctl.py`, `taskbar_ctl.sh`, `record_ctl.sh`, `clipboard_ctl.sh`, `power_ctl.sh`, etc.).

### `facade/`

Stable public compatibility commands used by WM keybinds, startup files, and HakuMenu actions, for example:

```text
statusbar_manager.sh
taskbar_manager.sh
dockbar_manager.sh
change_theme.sh
niri_animation_switcher.sh
wallpaper_select.sh
shutdown.sh
exit.sh
record.sh
clipboard_menu.sh
emoji_menu.sh
shell_switcher.sh
gen_shortcut.sh
hakumenu.sh
launcher.sh
```

A facade may route Classic interactive flows to `classic/` while exposing explicit headless subcommands through `shared/` or `hikai/`.

### `lib/`

Shared sourced helpers and schema libraries such as `haku_state.sh`, `haku_cache.sh`, `haku_state.py`, `haku_theme.sh`, `haku_backend_lib.sh`, `haku_appearance.sh`, and `haku_pick.sh`.

## Flattened deployment & `HAKU_BIN_DIR`

`deploy_hakuspace_scripts` walks `src/core/` and deploys every script except `README.md` directly into `$HAKU_BIN_DIR` (default: `$HOME/.local/bin`):

```text
src/core/facade/wallpaper_select.sh   -> $HAKU_BIN_DIR/wallpaper_select.sh
src/core/shared/wallpaper_ctl.sh      -> $HAKU_BIN_DIR/wallpaper_ctl.sh
src/core/classic/wallpaper_rofi.sh    -> $HAKU_BIN_DIR/wallpaper_rofi.sh
```

Therefore source paths are **not** part of the runtime public API, and every file under `src/core/` must have a globally unique basename. A basename collision is a deployment error.

Runtime scripts and Quickshell (`Env.binDir`) resolve internal commands directly via `HAKU_BIN_DIR` (defaulting to `$HOME/.local/bin`) without multi-path fallback loops.

## Change rules

When adding or refactoring a command family:

1. keep an existing public basename stable unless an explicit compatibility facade remains;
2. place Classic-only UI/controllers in `classic/`, Hikai-only controllers in `hikai/`, and cross-shell logic in `shared/`;
3. keep public routing in `facade/` when a compatibility command already exists;
4. do not duplicate backend mutations in the frontend;
5. resolve sibling scripts via `HAKU_BIN_DIR` (`$HOME/.local/bin`);
6. verify no basename collision and run deployment/validation checks after moving or renaming files.

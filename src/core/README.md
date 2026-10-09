# HakuSpace core scripts

`src/core/` is the canonical source tree for HakuSpace shell and Python runtime scripts. The source tree is organized by **runtime responsibility**, while deployment intentionally remains flat.

## Runtime responsibility model

The main architectural boundary is:

```text
backend/           headless domain/control commands
frontend/classic/  Classic presentation and interactive UI
facade/            stable public command names
lib/               shared sourced helpers
```

A typical migrated command family looks like:

```text
facade/wallpaper_select.sh
        -> frontend/classic/wallpaper_rofi.sh   # interactive Classic picker
        -> backend/theme/wallpaper_ctl.sh       # explicit headless operations
```

The facade keeps the long-standing public basename used by keybinds, startup files, user configuration and other HakuSpace components. Frontends collect human input and translate it into explicit backend calls. Backends own state queries and mutations and must remain UI-free.

## Directory taxonomy

### `backend/`

Headless, machine-callable domain logic. These scripts must not open Rofi, call `haku_pick.sh`, launch a Quickshell picker, or interpret human-facing menu labels as commands.

Current domains include:

```text
backend/clipboard/   clipboard history operations
backend/desktop/     taskbar, Waybar and desktop shortcut operations
backend/media/       recording lifecycle
backend/system/      power, session-exit and login-shell operations
backend/theme/       theme, Rofi-theme and wallpaper operations
backend/wm/          compositor-specific control logic
```

Use explicit commands and stable IDs. Prefer machine-readable output for structured data.

### `frontend/classic/`

Classic interactive presentation adapters. These scripts may build labels/icons, invoke Rofi, ask for a selection or password, and then call one explicit backend operation. Mutation logic should not be duplicated here.

`accent_color_picker.sh` also lives here because it is an interactive presentation helper even though it uses `hyprpicker` rather than Rofi.

### `facade/`

Stable public compatibility commands. These preserve the basenames and externally visible CLI used before the frontend/backend split, for example:

```text
taskbar_manager.sh
waybar_manager.sh
change_theme.sh
rofi_theme_switcher.sh
niri_animation_switcher.sh
wallpaper_select.sh
shutdown.sh
exit.sh
record.sh
clipboard_menu.sh
shell_switcher.sh
gen_shortcut.sh
```

A facade may route no-argument Classic behavior to `frontend/classic/` while exposing explicit headless subcommands through `backend/`.

Two older public routing entrypoints, `util/launcher.sh` and `menu/hakumenu.sh`, remain at their historical source paths for this refactor, but they are facade-equivalent and UI-free. Their Classic Rofi presentation now lives in `frontend/classic/launcher_rofi.sh` and `frontend/classic/hakumenu_rofi.sh`. Their deployed public basenames remain unchanged.

### Existing functional directories

Not every existing script needs to be forced into the three-layer pattern. Families that are already cohesive remain in their established locations:

- `lib/` — shared sourced helpers such as `haku_theme.sh`, `haku_backend_lib.sh` and `haku_pick.sh`.
- `app/` — standalone application/runtime components such as desktop icons, edge trigger, rounded screen and Cava layer.
- `menu/` — HakuMenu providers and routing scripts.
- `sys/` — cohesive system/runtime helpers that are not migrated compatibility facades.
- `theme/` — cohesive render/apply helpers such as style generation and wallpaper resume/set support.
- `util/` — cohesive general utilities that do not need a frontend/backend split.

`haku_pick.sh` remains a frontend service in `lib/`: it routes selection to Classic Rofi or Hikai picker IPC. It must not be called from `backend/`.

## Flattened deployment

`deploy_hakuspace_scripts` recursively walks `src/core/` and deploys every file except `README.md` directly into:

```text
~/.local/bin/
```

Therefore source paths are **not** part of the runtime public API. For example:

```text
src/core/facade/wallpaper_select.sh
src/core/backend/theme/wallpaper_ctl.sh
src/core/frontend/classic/wallpaper_rofi.sh
```

become:

```text
~/.local/bin/wallpaper_select.sh
~/.local/bin/wallpaper_ctl.sh
~/.local/bin/wallpaper_rofi.sh
```

The same public commands and keybinds continue to work after source-tree reorganization.

## Global basename rule

Because deployment is flat, every deployed filename under `src/core/` must have a globally unique basename. Two source files in different directories may **not** share the same filename.

`scripts/precommit_check.sh` enforces this. A basename collision is a deployment error, not just a source-tree style issue.

## Source-tree and deployed execution

Internal scripts must work in both forms:

1. directly from the repository source tree; and
2. after flat deployment into `~/.local/bin`.

When resolving another HakuSpace script, use the established fallback pattern:

```text
same directory / source-tree relative path
-> ~/.local/bin/<basename>
```

Do not assume that a source-tree sibling relationship will still exist after deployment.

## Change rules

When adding or refactoring a command family:

1. keep an existing public basename stable unless an explicit compatibility facade remains;
2. put state/query/mutation logic in `backend/`;
3. put Classic picker/password/presentation logic in `frontend/classic/`;
4. keep public routing in `facade/` when a compatibility command already exists;
5. do not duplicate backend mutations in the frontend;
6. do not introduce UI dependencies into `backend/`;
7. verify no basename collision;
8. test both source-tree resolution and flattened `~/.local/bin` resolution.

If symlinks are missing or stale after a source move, run the normal HakuSpace update/deployment flow so `~/.local/bin` is regenerated from the new canonical source paths.

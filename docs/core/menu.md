# The Haku Menu (src/core/menu)

Haku Menu provides a public entry point for desktop actions. The scripts in `src/core/menu/` handle routing and shared action providers.

This document covers those scripts and the Classic Rofi adapter. See [Hikai](../hikai.md) for shell architecture.

The providers supply choices and dispatch actions through the relevant public commands.

## The Main Hub

### `hakumenu.sh`
This is the stable public entry point used by keybinds and other callers. It routes requests to the active shell frontend. The Classic adapter lives in `frontend/classic/hakumenu_rofi.sh`.

### `hakumenu_rofi.sh`
This is the Classic presentation adapter. It launches Rofi and binds the three custom bash scripts to their respective tabs.
- **What it does:** Runs the HakuMenu Rofi mode and defines the custom modes:
  - `General` -> `hm_general.sh`
  - `Theme` -> `hm_theme.sh`
  - `Setting` -> `hm_setting.sh`

## Action Providers

### `hm_general.sh`
This is a thin compatibility entrypoint for `frontend/classic/hm_general_rofi.py`.
The adapter renders the backend snapshot with Rofi row metadata (`info`) and runs
only the stable ID returned through `ROFI_INFO`. Labels and icons are presentation;
duplicate labels are supported. Custom Rofi input cannot launch an action.

### Shared General menu backend

`backend/user/general_menu_ctl.py` manages custom actions shared by Classic and Hikai.
User rows live in `~/hakucfg/config/hakumenu-general.json`:

```json
{
  "schemaVersion": 1,
  "items": [
    {"id": "browser", "icon": "", "label": "Browser", "argv": ["open_browser.sh"]}
  ]
}
```

Seeded rows are ordinary user data: they can be edited, removed, disabled with
`"enabled": false`, or reordered. The backend returns custom items only, each with
`origin: "user"`, `mutable: true`, `enabled`, `argv` and a displayable `commandText`.
The default snapshot has seven rows from `app-menu` through `quit`.

Hikai owns seven static shell controls in `UiCatalog.hakuMenuGeneralItems`: Wifi,
Bluetooth, Disk Manager, Storage Manager, Audio Control, Task Manager and Settings.
They use `static-*` IDs. External tools launch directly through Quickshell;
Task Manager and Settings use Hikai panel actions on the menu's output. These
controls never enter the custom JSON, backend snapshots or Classic General menu. The backend rejects both `static-*`
and the former `builtin-*` namespace for custom IDs; get/run of absent static or
former built-in IDs returns `unknown item id`.

Classic renders all seven default custom rows. Hikai hides only `id: "app-menu"`
even if its label changes, because Hikai has a separate Drun tab. Its normal view
contains six custom actions followed by the seven static controls.

The CLI returns one JSON object. Successful list/check/mutation responses contain
`ok`, `schemaVersion`, `revision` and `items`; get/run return `item` instead of
`items`. Failures return `{"ok": false, "error": "..."}` and exit nonzero.

```bash
general_menu_ctl.py list
general_menu_ctl.py check
general_menu_ctl.py get browser
general_menu_ctl.py run browser
general_menu_ctl.py add '{"label":"Terminal","icon":"","argv":["kitty"],"afterId":"browser"}'
general_menu_ctl.py update browser '{"label":"Web Browser"}'
general_menu_ctl.py move browser 0
general_menu_ctl.py remove browser
```

`add` generates an ID when omitted. `update` preserves the ID and accepts partial
fields. `afterId` applies only to `add` and must reference a user row; omission
appends after the last user row. Move indices are zero-based within the user rows.
The backend never edits static shell controls.

All mutations accept `--expected-revision sha256:...`; add/update can alternatively
include `expectedRevision` in the payload. A stale revision returns
`{"ok": false, "error": "conflict"}` without overwriting data. CLI mutations may
omit the revision; Hikai always supplies its loaded revision. Writes lock the
parent directory, validate the existing document, flush a temporary file, check
for an intervening external edit, atomically replace the file and flush the parent.
An arbitrary external writer does not participate in the lock, so it must also use
the controller to guarantee serialized writes.

Use `argv` for commands. Add/update also accept `commandText` instead of `argv`;
the backend parses words with `shlex.split()` and stores only `argv`. No shell is
invoked: pipes, redirections, substitutions and operators are literal arguments.
Put complex logic in a separate executable script. Tilde prefixes in arguments
expand at launch, and `~/.local/bin` is prepended to the launch PATH.

Validation rejects unknown fields, duplicate IDs/JSON keys, unsupported schema
versions, empty labels/commands, control characters in presentation text, NUL in
arguments, symlinks in the config path and non-regular or foreign-owned files.
Limits are 128 user rows, 96 label characters, 16 icon characters, 128 arguments
per command, 4096 characters per argument and 256 KiB per document/payload.
`HAKUSPACE_GENERAL_MENU_FILE` overrides the config path for isolated clients/tests.
Missing or malformed files produce an error; the controller never silently seeds
or replaces them.

### Migration and Hikai binding

`scripts/hakucfg.sh sync --yes` seeds the JSON template only when missing. It no
longer deploys or requires `~/hakucfg/general-menu.sh`. Existing legacy scripts
retain their contents and permissions, and sync warns once that they are inactive.
Copy custom actions manually into the JSON; arbitrary Bash cannot be converted
safely. The warning receipt is `~/hakucfg/config/.general-menu-legacy-warned`.
Sync preserves existing JSON, including malformed content for manual recovery.

Hikai's `GeneralMenuService.qml` exposes `items`, `revision`, `busy`, `error`,
`refresh()`, `run(id)`, `add(payload, afterId)`, `update(id, payload)`, `remove(id)`
and `move(id, index)`. Mutations return whether the request was accepted and emit
`mutationFinished(operation, success)` on completion. Busy mutations are rejected;
refreshes are coalesced. Revision conflicts trigger a refresh. The last valid model
survives invalid external edits, and the next menu opening refreshes the snapshot.
`GeneralList.qml` retains separate custom/static models until search filtering and
presentation. Only the first visible static row gets a divider when both blocks
have matches. The divider's Add button appears when no search terms are active;
`>` alone is the General prefix, not a search term. An empty custom block keeps an
Add button above static controls without drawing a separator.

Right-click a custom row to toggle its inline Edit/Delete controls. Right-clicking
static controls closes any open rail. Right clicks and action buttons never launch
the row; left clicks launch custom IDs through the service or static commands
directly. Query, tab and menu-close changes clear the transient controls.

`GeneralItemEditor.qml` is the shared internal Add/Edit surface with Icon, Name
and Command fields. Add appends to the custom block; Edit preserves the ID. The
editor validates presentation limits, leaves command parsing to the backend, and
closes only after successful persistence. Backend errors and revision conflicts
retain the draft and a local error after refresh. The editor loads on demand and
releases after its visual close and pending save finish.

Delete first reveals inline `Delete?` and Cancel controls. Confirmation removes
exactly that custom ID and selects the nearest surviving row; errors retain the
rail/confirmation. Add and action controls are outside the keyboard row model.
Static rows have no CRUD controls.

Targeted regression checks:

```bash
python3 -B tests/menu/general/test_ctl.py
python3 -B tests/config/hakucfg/test_sync.py GeneralConfigTests
node tests/hikai/hakumenu/test_general_list.js
python3 -B tests/hikai/hakumenu/test_general_qml.py
```

The QML integration probe uses an isolated HOME and offscreen software renderer;
it exercises real mouse clicks, the service/editor/backend and Classic output after
Add/Edit/Delete. It does not measure hardware rendering performance.

Manual session checks after deployment (use a disposable configuration and harmless
launch commands):

- Classic General shows seven seeded custom rows, including App Menu, with no
  Wifi/Bluetooth controls. Selecting duplicate labels runs the intended ID.
- Hikai General shows six custom rows, divider/Add and seven static controls. Verify
  glyphs, selected-row contrast, editor Tab/Shift-Tab, narrow layouts and scrolling.
- Right-click custom rows, edit, cancel/confirm deletion and switch tabs or close
  the menu. Controls must not trigger row launches or retain stale context.
- Add/Edit/Delete in Hikai must appear on the next Classic opening. Change the JSON
  externally during editing and verify the draft/error remains available on conflict.

### `hm_theme.sh`
This provider exposes theme and desktop controls and dispatches selections through their public commands. State belongs to the relevant controller; menu presentation does not own it. Read the provider source for the available actions and their labels.

### `hm_setting.sh`
This provider connects system tools and HakuSpace configuration commands.
- **What it does:** It gives you quick access to essential GUI tools like `nm-connection-editor` (Wifi), `blueman-manager` (Bluetooth), `gparted` (Disk Manager), `ncdu` (Storage Manager), and `pavucontrol` (Audio Control).
- **HakuSpace Configs:** It also provides toggles specifically for the Taskbar (App Name, Icon Size), Cava Modes (Color Switch, Dynamic Mode), Rounded Screen Dynamic Mode, and the Opaque Theme Mode. It offers direct shortcuts to open your `~/hakucfg` folder or edit `~/hakucfg/config/hakumenu-general.json` in VS Code. Like the Theme tab, it reads local configuration variables to dynamically display the current states of these settings.


---
**Previous:** [Utilities](util.md) | **Next:** [Mini-Apps](app.md)

# HakuSpace P3 — `src/core` Frontend / Backend Separation Plan

> Scope: refactor script architecture only. Do **not** add new Hikai UI in this batch.
>
> Baseline reviewed: `10621064`.
>
> P3 ordering intent: HakuMenu shell / General / Drun are already usable; Theme remains deferred. Run this script split **before** implementing real Theme-tab actions and before Wallpaper carousel action wiring.

---

# 1. Why this refactor exists

`src/core` currently mixes three different responsibilities in several single scripts:

1. **backend/domain logic** — query state, mutate state, start/stop processes, apply settings;
2. **frontend interaction** — show Rofi, collect a choice/password, format human-facing labels;
3. **public compatibility entrypoint** — stable commands referenced by keybinds, Waybar, HakuMenu and user config under `~/.local/bin`.

That coupling is harmless for Classic-only scripts, but it becomes a blocker for Hikai because QML should call a headless contract instead of spawning/parsing a Rofi UI script.

The target is not “remove Rofi”. The target is:

```text
backend = headless + explicit arguments + stable output
classic frontend = Rofi / haku_pick presentation only
facade = stable public command name and backend routing
```

Classic must keep working throughout the migration.

---

# 2. Current-tree findings

Direct Rofi invocation is currently present in these families:

```text
src/core/app/taskbar/taskbar_manager.sh
src/core/menu/hakumenu.sh
src/core/sys/exit.sh
src/core/sys/shutdown.sh
src/core/theme/change_theme.sh
src/core/theme/niri_animation_switcher.sh
src/core/theme/rofi_theme_switcher.sh
src/core/theme/wallpaper_select.sh
src/core/util/clipboard_menu.sh
src/core/util/gen_shortcut.sh
src/core/util/launcher.sh
src/core/util/record.sh
src/core/util/shell_switcher.sh
src/core/util/waybar_manager.sh
src/core/lib/haku_pick.sh
```

Not every `rofi` text match is a frontend/backend violation:

```text
src/core/theme/gen_style.sh
    renders Rofi theme files; it is not a picker UI.

src/core/theme/opaque_theme.sh
    renders Rofi style overrides; it is not a picker UI.

src/core/sys/haku_backend.sh
    kills/verifies the classic `rofi` process; it does not present a picker.

src/core/app/edge-trigger/edge_trigger.py
    contains Classic Rofi command/liveness integration; treat it as Classic
    integration code, not as a domain backend to split in this batch.

src/core/util/open_config.sh
    references the Rofi config directory as data; it does not invoke Rofi.
```

Existing useful boundary:

```text
src/core/lib/haku_pick.sh
```

`haku_pick.sh` already acts as a selector facade: Classic -> Rofi, Hikai -> Quickshell picker IPC. It is a **frontend service**, not a domain backend. Keep it out of backend/domain scripts.

Existing menu providers:

```text
hm_general.sh
hm_theme.sh
hm_setting.sh
```

already run without invoking Rofi themselves. Preserve their current public contracts during this refactor. Do not use their human-readable labels as the new backend API for future Hikai Theme/Wallpaper work.

---

# 3. Target source layout

Use responsibility-based source directories while preserving flattened deployment to `~/.local/bin`:

```text
src/core/
├── backend/
│   ├── theme/
│   ├── wallpaper/
│   ├── desktop/
│   ├── system/
│   ├── recorder/
│   ├── clipboard/
│   └── session/
├── frontend/
│   └── classic/
├── facade/
├── lib/
├── app/
├── menu/
├── sys/
├── theme/
└── util/
```

This is an end-state taxonomy, not a request for one giant move commit. Migrate one caller family at a time.

Because deployment is flat, **all script basenames must remain globally unique** under `src/core`.

Suggested naming convention for new internal scripts:

```text
<domain>_ctl.sh       headless backend/domain command
<domain>_rofi.sh      Classic frontend adapter
<existing-name>.sh    stable public facade when one already exists
```

Examples:

```text
wallpaper_ctl.sh
wallpaper_rofi.sh
wallpaper_select.sh       # compatibility facade

record_ctl.sh
record_rofi.sh
record.sh                 # compatibility facade
```

Do not rename externally referenced commands unless a compatibility wrapper with the old basename remains.

---

# 4. Hard architecture contracts

## 4.1 Backend/domain script contract

Anything under `src/core/backend/` must be headless.

Forbidden:

```text
rofi
haku_pick.sh
Quickshell picker IPC / UI opening
theme geometry such as `-theme-str`, `-location`, row count, window size
interactive selection from stdin
parsing display labels to decide an action
```

Backend scripts may:

```text
read/write HakuSpace state
query system state
invoke system/domain tools
start/stop domain processes
print machine-consumable data
perform an explicit action requested by an argument
```

Prefer returning errors on stderr + non-zero status rather than opening a UI message. User-facing notification belongs in the facade/frontend unless an existing runtime side effect must temporarily be preserved for compatibility.

## 4.2 Frontend contract

Classic frontend scripts may:

```text
build labels/icons
invoke Rofi or haku_pick
ask for a password/selection
translate the selected stable ID into one explicit backend call
show user-facing cancellation/error feedback
```

They must **not** duplicate backend mutation logic.

## 4.3 Facade contract

Public commands already used by keybinds/configs keep their basename and current externally visible behavior.

Examples:

```text
wallpaper_select.sh
record.sh
shutdown.sh
clipboard_menu.sh
shell_switcher.sh
waybar_manager.sh
taskbar_manager.sh
```

During the split, a facade may continue to launch the Classic frontend even when no Hikai replacement exists. This refactor must not invent unfinished QML UIs.

Where Hikai routing already exists (`launcher.sh`, `notif.sh`), preserve it.

## 4.4 Data contract

Backend selection must use **stable IDs**, not presentation strings.

Bad:

```text
case "$chosen" in *"Change Wallpaper"*) ...
```

Good:

```text
wallpaper_ctl.sh list --json
wallpaper_ctl.sh apply --id '<stable-id>'
```

Simple lists may be one item per line. Structured rows with icon/path/status should use JSON or another explicitly documented format. Avoid output that is only understandable by Rofi script mode.

Recommended exit status contract:

```text
0   success
1   runtime/domain failure
2   invalid usage/input
```

“User cancelled picker” is a frontend concern and must not be represented as a backend mutation failure.

---

# 5. Deployment / source-tree safety

HakuSpace currently deploys every `src/core` file flat into `~/.local/bin` and rejects basename collisions.

Therefore every migration must verify:

```text
1. no duplicate basename anywhere under src/core;
2. existing public basename still deploys;
3. symlink mode points to the intended new source path;
4. copy mode still receives the same public commands;
5. scripts that source `lib/` work both:
   - from the repository source tree;
   - after flat deployment into ~/.local/bin.
```

Do not assume `SCRIPT_DIR/haku_theme.sh` works from a newly nested source directory. Use the repository/deployed fallback pattern already demonstrated by `haku_backend_lib.sh`.

---

# 6. Atomic execution plan

One accepted task = one commit. Do not combine families.

## C0 — Inventory + contract freeze

No product behavior change.

Deliver:

- this plan;
- direct-Rofi inventory;
- public command inventory;
- classification into backend/frontend/facade/false-positive.

Commit:

```text
p3(core): plan frontend backend script separation
```

Gate:

- no source behavior changes;
- reviewers agree on naming/contract before extraction starts.

---

## C1 — Add core-script guardrails

Add/extend static checks before moving logic.

Required checks:

```bash
bash -n $(find src/core -name '*.sh')
python3 -m py_compile $(find src/core -name '*.py')
```

Add a basename-collision check equivalent to flattened deployment.

Once `src/core/backend/` exists, add:

```bash
! grep -RInE '\brofi\b|haku_pick\.sh|picker open' src/core/backend
```

The check may whitelist comments only if needed, but executable backend code must remain UI-free.

Commit:

```text
p3(core): add script boundary guardrails
```

Gate:

- existing tree still passes;
- install/update deployment behavior unchanged.

---

## C2 — Prove the pattern with Taskbar

Current issue:

```text
taskbar_manager.sh --icon-size
```

shows Rofi and mutates theme files in the same script.

Extract:

```text
taskbar_ctl.sh
    status/get-app-name
    toggle-app-name
    get-icon-size
    set-icon-size <px>
    startup/toggle operations as appropriate

taskbar_rofi.sh
    icon-size picker only

taskbar_manager.sh
    stable compatibility facade
```

Do not change Taskbar semantics.

Commit:

```text
p3(core): split taskbar selector from control logic
```

Gate:

- `--toggle`, `--startup`, `--app-name`, `--icon-size` behave as before;
- backend control file contains no Rofi call;
- Classic UI still opens the same picker.

---

## C3 — Waybar selector split

Current issue:

```text
waybar_manager.sh --select
```

mixes Rofi selection with symlink/process/state management.

Extract:

```text
waybar_ctl.sh
    list
    current
    set <mode>
    cycle
    toggle
    reload

waybar_rofi.sh
    select mode -> waybar_ctl.sh set <id>

waybar_manager.sh
    stable facade
```

Commit:

```text
p3(core): split waybar selector from manager logic
```

Gate:

- Classic selector parity;
- Hikai’s current “top only” policy remains unchanged;
- no Rofi in `waybar_ctl.sh`.

---

## C4 — Theme mutation core

This is the important prerequisite for future HakuMenu Theme work.

Current `change_theme.sh` contains:

- the top-level Rofi menu;
- font-size picker;
- font picker;
- accent picker/list;
- mutation via `gen_style.sh` + `apply_style.sh`.

Extract a headless contract such as:

```text
theme_ctl.sh status --json
theme_ctl.sh list-fonts
theme_ctl.sh set-font '<family>'
theme_ctl.sh set-font-size <px>
theme_ctl.sh set-accent <#RRGGBB>
theme_ctl.sh apply
```

Keep color-picker launch in frontend/facade; the backend receives the selected color.

Classic frontend:

```text
theme_rofi.sh
```

Public compatibility:

```text
change_theme.sh
```

Commit:

```text
p3(core): split theme picker from mutation backend
```

Gate:

- same generated theme output for identical explicit inputs;
- no Rofi in `theme_ctl.sh`;
- no new HakuMenu Theme UI yet.

---

## C5 — Rofi-theme subfeature split

`rofi_theme_switcher.sh` currently discovers theme files, picks one, then writes the Rofi theme reference.

Extract:

```text
rofi_theme_ctl.sh list
rofi_theme_ctl.sh current
rofi_theme_ctl.sh set <theme-id>

rofi_theme_rofi.sh
    list -> picker -> set

rofi_theme_switcher.sh
    compatibility facade
```

This backend remains “Rofi-theme domain” but must not itself invoke a Rofi window.

Commit:

```text
p3(core): split rofi theme picker from theme control
```

---

## C6 — Niri animation split

Current `niri_animation_switcher.sh` combines:

- KDL parsing;
- active-state detection;
- KDL mutation;
- Rofi script-mode launcher/handler.

Extract:

```text
niri_animation_ctl.sh list --json
niri_animation_ctl.sh get <mode>
niri_animation_ctl.sh set <mode> <option-id>

niri_animation_rofi.sh
    Rofi mode UI only

niri_animation_switcher.sh
    compatibility facade
```

Commit:

```text
p3(core): split niri animation ui from kdl backend
```

Gate:

- identical KDL mutation for the same explicit mode/option;
- Niri-only validation remains in backend;
- no Rofi in backend.

---

## C7 — Wallpaper backend split

This is the important prerequisite for the P3 Wallpaper carousel.

Current `wallpaper_select.sh` combines:

- static/lively discovery;
- thumbnail generation;
- accent extraction/application;
- wallpaper application;
- lively stop/restore;
- Rofi script modes + geometry.

Extract:

```text
wallpaper_ctl.sh list-static --json
wallpaper_ctl.sh list-lively --json
wallpaper_ctl.sh apply-static <id/path>
wallpaper_ctl.sh apply-lively <id/path>
wallpaper_ctl.sh stop-lively
wallpaper_ctl.sh current/status --json
wallpaper_ctl.sh ensure-thumbnails   # if still required

wallpaper_rofi.sh
    Classic script-mode adapter

wallpaper_select.sh
    compatibility facade
```

Structured list output must include enough information for QML without parsing Rofi escape codes:

```text
id
kind
path
label
thumbnail/icon
selected/current if available
```

Commit:

```text
p3(core): split wallpaper model actions from rofi frontend
```

Gate:

- Classic wallpaper selector unchanged visually/functionally;
- explicit backend apply path works without Rofi;
- accent update semantics unchanged;
- lively stop/restore unchanged.

---

## C8 — Power menu split

Current `shutdown.sh` mixes Rofi presentation with system actions.

Extract:

```text
power_ctl.sh suspend
power_ctl.sh reboot
power_ctl.sh poweroff
power_ctl.sh hibernate
power_ctl.sh lock
power_ctl.sh logout

power_rofi.sh
    Classic action picker

shutdown.sh
    compatibility facade
```

Do not execute a destructive action from a display label. Frontend maps stable IDs to explicit backend subcommands.

Commit:

```text
p3(core): split power menu from power actions
```

Gate:

- no accidental action during list/query tests;
- current Classic shutdown UI remains usable;
- `-e/--extend` and vertical Rofi geometry belong only to Classic frontend.

---

## C9 — Session-exit confirmation split

`exit.sh` is high risk because it combines process inventory, confirmation UI and destructive cleanup.

Extract:

```text
session_exit_ctl.sh process-report
session_exit_ctl.sh execute

exit_rofi.sh
    render process report + explicit confirmation

exit.sh
    compatibility facade
```

`execute` must require an explicit subcommand; running the backend with no args must never terminate the session.

Commit:

```text
p3(core): split session exit confirmation from cleanup backend
```

Gate:

- query/report path is side-effect free;
- cancellation is frontend-only;
- Hyprland/Niri/Mango/Labwc exit branches preserved exactly.

---

## C10 — Recorder split

Current `record.sh` mixes:

- recording lifecycle/audio setup;
- mode selection;
- microphone selection.

Extract:

```text
record_ctl.sh status --json
record_ctl.sh list-modes
record_ctl.sh list-sources
record_ctl.sh start <mode-id> [--source <id>]
record_ctl.sh stop

record_rofi.sh
    mode/source selection

record.sh
    compatibility facade
```

All PipeWire/Pulse/wl-screenrec setup/teardown stays backend-side.

Commit:

```text
p3(core): split recorder ui from capture backend
```

Gate:

- no-audio/system-audio/mic+system parity;
- stop/cleanup parity;
- timer/PID state parity;
- backend start path can be called non-interactively.

---

## C11 — Clipboard split

Current `clipboard_menu.sh` combines cliphist lifecycle, picker and copy action.

Extract:

```text
clipboard_ctl.sh ensure-watchers
clipboard_ctl.sh list
clipboard_ctl.sh copy <entry-id/raw-contract>
clipboard_ctl.sh wipe

clipboard_rofi.sh
    picker only

clipboard_menu.sh
    compatibility facade
```

Commit:

```text
p3(core): split clipboard picker from history backend
```

Gate:

- text/image history behavior preserved;
- wipe remains explicit;
- no Rofi in backend.

---

## C12 — Shell switcher split

Current `shell_switcher.sh` mixes discovery/mutation with Rofi selection and Rofi password entry.

Extract:

```text
shell_ctl.sh list --json
shell_ctl.sh current
shell_ctl.sh set <shell-id/path>

shell_rofi.sh
    shell picker + Classic authentication UX

shell_switcher.sh
    compatibility facade
```

Backend must not ask for a Rofi password. If elevation is required and no usable authorization path exists, return a clear status/error for frontend handling.

Commit:

```text
p3(core): split shell picker from login shell backend
```

Gate:

- NixOS guard preserved;
- `/etc/shells` registration preserved;
- terminal behavior preserved;
- no credential UI in backend.

---

## C13 — Shortcut generator split

Current `gen_shortcut.sh --menu` combines discovery/picker with the otherwise useful query/add/create backend.

Extract frontend only:

```text
shortcut_rofi.sh
```

Keep headless query/add/create in `gen_shortcut.sh` or rename it to `shortcut_ctl.sh` with a compatibility facade, depending on which produces the smaller and clearer diff.

Commit:

```text
p3(core): split shortcut picker from shortcut operations
```

---

## C14 — Source-tree taxonomy + README

Only after the above families have stable contracts, move source files into their final responsibility directories.

Rules:

- use `git mv`;
- do not combine behavior changes with mass moves;
- keep every deployed/public basename stable;
- update `src/core/README.md` to describe `backend/`, `frontend/classic/`, `facade/`, flattened deployment and no-collision rule;
- update source-lib fallback paths where needed.

Commit:

```text
p3(core): organize scripts by runtime responsibility
```

Gate:

```text
install/update script inventory before == after for public entrypoints
```

---

## C15 — Final direct-Rofi audit

Run:

```bash
grep -RInE '\brofi\b|rofi -|rofi-wayland' src/core
```

Expected remaining categories only:

```text
frontend/classic/*
facade scripts that intentionally route to Classic UI
lib/haku_pick.sh
Classic edge-trigger integration
Rofi theme renderer/config references (not picker invocation)
backend verification that checks/kills a rofi process
```

There must be **zero direct picker invocation in `src/core/backend/`**.

### C15 execution result

Final audit result after C2–C14 migration:

```text
PASS  src/core/backend/** has zero direct picker invocation
PASS  launcher.sh no longer invokes Rofi directly; Classic UI is launcher_rofi.sh
PASS  hakumenu.sh no longer invokes Rofi directly; Classic UI is hakumenu_rofi.sh
PASS  remaining Rofi references are limited to Classic frontend, haku_pick,
      Classic edge-trigger/process management, or theme/config rendering
PASS  flattened deployment basename set remains collision-free
```

Known follow-ups that do not block this boundary refactor:

```text
C6  Rofi WindowOpen/WindowClose sidebar Nerd Font icon display: BACKLOG
C9  destructive real session-exit path: NEEDS VERIFY
```

Commit:

```text
p3(core): finalize frontend backend script boundaries
```

---

# 7. Explicit non-goals

Do not bundle these into the refactor:

- implementing the HakuMenu Theme tab;
- implementing Wallpaper carousel UI;
- replacing every Classic Rofi screen with QML;
- changing Classic visual themes;
- rewriting `hm_general.sh` / `hm_theme.sh` / `hm_setting.sh` label contracts unless a migration task specifically requires it;
- changing backend-selection semantics in `haku_backend.sh`;
- redesigning edge-trigger behavior;
- removing `haku_pick.sh`.

This batch creates headless contracts so those future tasks become cheap and safe.

---

# 8. Per-task validation

Static after every commit:

```bash
git diff --check
bash -n $(find src/core -name '*.sh')
python3 -m py_compile $(find src/core -name '*.py')
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

Also run the basename-collision check introduced in C1.

Focused runtime matrix for each migrated family:

```text
Classic:
- open existing public command
- picker UX appears where it appeared before
- cancel path has no side effects
- choose one action
- verify state/action

Headless/backend:
- list/query works without DISPLAY/Rofi
- explicit action works without opening UI
- bad argument fails safely

Hikai:
- current behavior remains unchanged
- no accidental Rofi launch from new backend contracts
- existing Quickshell IPC/QML callers still work
```

High-risk families (`power`, `exit`) require manual confirmation before destructive runtime actions.

---

# 9. Report format

```text
Task: C<n>
Base commit:
Public entrypoints touched:
New backend contract:
Classic frontend adapter:
Files changed:
Diff stat:
Direct Rofi remaining in backend: 0 / N/A
Static checks:
Classic runtime:
Headless runtime:
Hikai regression:
Known limitations:
Ready for manual commit: yes/no
```

Do not auto-commit. The user commits manually.

---

# 10. Dependency on remaining P3 work

Recommended order from the current point:

```text
HakuMenu General/Drun usable
        ↓
C0–C7 core split through Theme + Wallpaper contracts
        ↓
HakuMenu Theme stub/layout or future real Theme model
        ↓
Wallpaper carousel W1–W6 using wallpaper_ctl.sh
        ↓
C8–C15 remaining core split/migration
```

If the intent is to finish the entire core cleanup before returning to UI, C8–C15 may be completed immediately after C7. Do not let Theme/Wallpaper UI depend on Rofi script-mode contracts again.

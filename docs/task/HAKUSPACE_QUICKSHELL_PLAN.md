# HakuSpace × Quickshell

Companion documents that currently exist in `docs/task/`:

- `QUICKSHELL_TESTING.md` — manual/runtime verification matrix, updated for the P0 labwc pass; the other three WMs remain to be tested.
- `QUICKSHELL_STYLE.md` — visual/token conventions, synchronized with the P0 theme decision.
- `FLARE_LIB_SPEC.md` — flare geometry/rendering contract. The core library exists; L3/L4 are not fully closed.

The old `WORKSPACES_PLAN.md` and `M2_WORKSPACES_PROBE.md` are deleted in the current working tree. Their useful conclusions are absorbed into this master plan; do not recreate them unless a new probe is needed.

---

## 0. Status vocabulary

Use these labels consistently in reports and future docs:

| Label | Meaning |
|---|---|
| **DONE** | Implemented in the repository and the relevant static/runtime acceptance checks have passed. |
| **IMPLEMENTED / VERIFY** | Code exists, but interactive, multi-monitor, compositor-specific, or deployed-machine verification is still required. |
| **PARTIAL** | A usable subset exists, but the feature is intentionally incomplete. |
| **BLOCKED** | Do not implement further until an upstream/dependency problem changes. |
| **PLANNED** | No production implementation exists yet. |
| **OPTIONAL** | Nice-to-have; must not block parity or release milestones. |

A feature is **not DONE** merely because `qml_syntax_check.py` or `scripts/precommit_check.sh` passes.

---

## 1. Reviewed repository snapshot

### 1.1 Git state

At review time:

- branch: `quickshell`;
- `HEAD`: `ddefc67e`;
- workspace work through the Niri reducer is committed;
- a large **uncommitted/staged N11 working tree** exists for Dynamic Center, MPRIS/Cava, level OSD, shared audio/brightness services, hardware-key routing, and related style cleanup;
- `WORKSPACES_PLAN.md` and `M2_WORKSPACES_PROBE.md` are deleted in the working tree;
- the current master plan and testing guide were already partially edited, but they do not accurately describe the code yet.

Do not flatten this distinction in reports. Until P0 is closed, say whether a finding is from `HEAD` or from the current working tree.

### 1.2 Static validation already run during this re-baseline

The following passed against the reviewed working tree:

```bash
scripts/precommit_check.sh
git diff --check
```

`precommit_check.sh` currently validates:

- banned debug-code grep with explicit exceptions;
- no untracked files under `src/` or `scripts/`;
- no root junk files;
- QML bracket/string syntax check;
- `FlareGeometry.js` Node tests;
- shell syntax for scripts under `scripts/`.

This gate does **not** replace `qmllint`, compositor runtime checks, D-Bus tests, or visual/manual checks.

---

## 2. Current architecture — what Hikai actually contains now

### 2.1 Shell surfaces

`shell.qml` currently creates:

1. one global `Picker` overlay;
2. one `TopBar` per `Quickshell.screens` screen;
3. one `LevelOsdOverlay` per screen;
4. one `RoundedScreen` per screen.

Current IPC targets:

| Target | Functions | Status |
|---|---|---|
| `shell` | `ping()`, `reload()`, `quit()` | **DONE** |
| `picker` | `open(fifo, jsonString)` | **DONE**, caller migration pending |
| `level` | `change(action)` | **IMPLEMENTED / VERIFY**; N11 is committed, with runtime checks still open |
| `notif` | planned `toggleCenter`, `toggleDnd`, `clearAll`, `count` | **PLANNED** |
| `launcher` | planned `open(mode)` | **PLANNED** |
| `hakumenu` | planned toggle/open contract | **PLANNED** |
| `power` | planned toggle/open contract | **PLANNED** |
| `wallpaper` | planned toggle/open contract | **PLANNED** |

Command form remains:

```bash
qs -c hakuspace ipc call <target> <function> [args...]
```

### 2.2 Shared services

Present singletons:

- `Env`
- `Theme`
- `AppState`
- `UiState`
- `HAnimation`
- `WM`
- `SysStats`
- `TooltipManager`
- `FlareEdges`
- `Audio`
- `Brightness`
- `Recorder`
- `Media`
- `CenterState`
- `Cava`

This is now the preferred architecture: hardware/system state belongs in a shared service, while top-bar components render and dispatch actions. Avoid putting duplicate polling processes in every per-screen component.

### 2.3 Top-bar composition

Current layout:

| Area | Modules | Current status |
|---|---|---|
| Left | Logo → Workspaces → WindowTitle | Implemented |
| Physical center | conditional Cava + `CenterModule` | N11 **IMPLEMENTED / VERIFY** |
| Right | Tray → Settings → Recorder → Clock → Notification | Notification remains a stub |

Not mounted:

- `MonitorGroup.qml` — functional drawer backed by ref-counted `SysStats`, intentionally not in the layout;
- `MusicGroup.qml` — obsolete placeholder; native MPRIS is now handled by `Media` + `CenterModule`.

### 2.4 Current shell-side integration

The classic/Hikai boundary already exists:

- `haku_backend_lib.sh` owns backend state and common QS helpers;
- `haku_backend.sh` switches `classic ↔ hikai`, stops the other stack, runs a health check, and rolls back if QS fails;
- `qs_supervisor.sh` restarts QS and falls back to Classic after a crash loop;
- `session_start.sh --early` starts the selected backend at session startup;
- manager guards prevent classic Waybar/taskbar/edge/rounded/cava/desktop-icon processes from reappearing in Hikai;
- `launcher.sh` and `notif.sh` already act as facades, but their Hikai IPC targets do not exist yet;
- `haku_pick.sh` is implemented, but no production caller uses it yet;
- Super+Esc remains the backend-independent emergency escape to Classic.

`swaync` is still intentionally allowed in Hikai through `QS_ALLOW_SWAYNC=1` until native notifications are ready.

---

## 3. Feature inventory — corrected against current code

### 3.1 Backend/runtime infrastructure — **DONE**

Existing behavior:

- persistent `classic` / `hikai` state;
- safe switch in both directions;
- supervisor and crash fallback;
- startup integration for Hyprland, Niri, MangoWM, and Labwc;
- emergency escape key on all WMs;
- classic manager guards;
- QS health check through `shell.ping()`;
- runtime log under `$XDG_RUNTIME_DIR/hakuspace/qs.log`.

Future work should extend this infrastructure, not replace it.

### 3.2 Theme and persistent shell state — **DONE core / VERIFY one policy**

Implemented:

- generated `quickshell.json` theme;
- live `FileView` reload in `Theme.qml`;
- live state for top-bar visibility, opaque mode, rounded-screen state, and rounded-screen dynamic mode;
- live rounded-screen radius/thickness from `rounded-screen.conf`;
- shared animation tokens.

**Current background policy:** `Theme.barColor` keeps the `AppState.opaqueThemeState ? inkBg : bg` binding, while both `inkBg` and `bg` are fixed to `#000000`. Ordinary idle modules/cards and the Picker scrim are opaque black. Hover/selection fills use the accent colour with black text/icons; Tray and WindowTitle hover use dark grey `Theme.hoverMuted`, with WindowTitle text/icon in accent. The Logo and Settings group stay accent-filled with black icons in both states. Logo hover grows the icon font size by 2 px and expands the pill by `Theme.pad`. `Theme.surfaceHi` is bound to `accent`; the generated JSON mirrors this, while `Theme.qml` ignores incoming values for fixed background tokens so old theme files cannot override them. The MPRIS icon circle remains accent-filled with a black glyph. The earlier P0 labwc pixel check (`#000000` with opaque off, `#111111` with opaque on) is historical and must be repeated for the current policy.

### 3.3 Picker — **DONE core / integration debt**

Implemented:

- QS picker overlay;
- filtering and keyboard navigation;
- password mode;
- no-custom mode;
- FIFO result protocol;
- cleanup and QS-death handling.

Still incomplete:

- no production script calls `haku_pick.sh`;
- Hikai currently ignores `--width`, `--height`, `--selected`, and `--lines` even though those values are sent in the JSON request.

### 3.4 Workspaces — **Hyprland/Niri/Mango implemented; Labwc intentionally disabled**

Common model is already split behind `services/WM/WM.qml` and compositor backends.

#### Hyprland — **DONE / light stability audit only**

Implemented:

- native `Quickshell.Hyprland` workspace model;
- active/focused state;
- occupancy and window count;
- urgent state;
- special workspaces;
- left-click activation;
- right-click special-workspace action;
- scroll cycling;
- active window class/title.

Do **not** rewrite this backend for architectural symmetry. Only fix it if the P0 audit reproduces a real problem.

Audit focus:

- multi-monitor `active` vs `focused` semantics;
- occupied/window count after open/close/move;
- urgent state;
- click/scroll after QS reload;
- no regression from older `Env.wmName` case-sensitive behavior.

#### Niri — **IMPLEMENTED / VERIFY after reducer refactor**

Current `NiriBackend.qml` uses `niri msg -j event-stream` with local workspace/window state and delta handling for:

- `WorkspacesChanged`;
- `WindowsChanged`;
- `WorkspaceActivated`;
- `WorkspaceUrgencyChanged`;
- `WorkspaceActiveWindowChanged`;
- `WindowOpenedOrChanged`;
- `WindowClosed`;
- `WindowFocusChanged`;
- `WindowUrgencyChanged`.

It also:

- uses workspace id as the stable key;
- filters workspaces per output;
- focuses the target monitor before focusing an output-local workspace index;
- clears stale state and reconnects if the event stream exits;
- publishes active window class/title from Niri data.

`ddefc67e` specifically refactored this path to reduce stale workspace state. It needs regression testing, not another redesign.

#### MangoWM — **IMPLEMENTED / light stability audit only**

Implemented:

- initial `mmsg get all-tags` snapshot;
- event-driven `mmsg watch all-tags` updates;
- per-output filtering;
- hide empty inactive tags;
- occupied/window count/urgent;
- left click `view`;
- right click `toggleview`;
- reconnect timer.

Known semantics to verify before any refactor:

- `focused` is currently copied from `is_active`; this may be insufficient on multi-monitor setups;
- the key contains the monitor name, but `activate()`/`secondary()` dispatch only the tag index. Verify that commands target the intended monitor in a real multi-monitor Mango session.

If the audit passes, **keep the code unchanged**.

#### Labwc — **BLOCKED by Quickshell 0.3.1 ext-workspace crash**

The previous probe showed `Quickshell.WindowManager.windowsets` causing a fatal `std::bad_function_call` on Labwc. Current `WM.qml` intentionally selects `NullBackend` for Labwc and hides workspaces instead of crashing the whole shell.

Rules:

- do not re-enable `ExtBackend` on Labwc under the same Quickshell version;
- do not replace the safe NullBackend with polling just to claim 4-WM parity;
- re-probe only after a Quickshell/ext-workspace version change or an upstream fix;
- Hikai on Labwc must still start successfully with the workspace module absent.

### 3.5 Window title — **Hyprland implemented; Niri code implemented/verify; Mango/Labwc absent**

Current code:

- renders class + title;
- uses a 32-Unicode-character visible title limit with ellipsis;
- keeps the full title in the tooltip;
- Hyprland supplies active window metadata;
- Niri now also publishes `activeWindowClass` / `activeWindowTitle` from the event-stream model;
- Mango and Labwc do not currently publish active-window metadata.

`QUICKSHELL_TESTING.md` still says “Hyprland only”; fix that during P0 after Niri runtime verification.

### 3.6 Tray — **QML + Flare menus IMPLEMENTED / VERIFY**

Current implementation:

- native `SystemTray.items`;
- icon loading;
- normal left click calls `activate()`; `onlyMenu` left click requests its menu;
- right click routes usable `SystemTrayItem.menu` models, short or long, through `QsMenuOpener`, `MenuContent`, and the shared Flare panel; unavailable/empty models retain compatibility `display()` fallback, and no-menu items use `secondaryActivate()`;
- scroll forwarding.

The controlled fixture passed action, checkbox, submenu/back, radio, repeated-open, Escape, outside click, and close animation on the deployed Niri session at scale 1.0. Wi-Fi, Bluetooth, and Fcitx5 expose usable DBusMenu models and now use the shared QML + Flare panel. Tall menus scroll inside a monitor-bounded panel; menu size no longer triggers native fallback. See `TRAY_FULL_QML_FLARE_REPORT.md` for the current runtime matrix and remaining cases.

Quickshell 0.3.1 exposes the primitives needed for this design:

- `SystemTrayItem.menu` is a menu handle consumable by `QsMenuOpener`;
- `SystemTrayItem.onlyMenu` identifies items whose primary action is the menu;
- `QsMenuOpener { menu: item.menu }` exposes the menu's children as `ObjectModel<QsMenuEntry>`;
- `QsMenuEntry` provides `text`, `icon`, `enabled`, `isSeparator`, `buttonType`, `checkState`, `hasChildren`, and `triggered()`;
- submenu entries can be opened recursively with another `QsMenuOpener`.

Implemented short-menu path and longer-term target UX:

- render DBusMenu content in HakuSpace QML instead of handing normal menus to the platform renderer;
- use the same Flare geometry/content stack as tooltips so a tray hover can morph into its menu instead of spawning an unrelated rectangular popup;
- for a right-edge tray item, preserve the visual attachment to the bar/right edge and keep the flare seam correct at fractional scale;
- support text, icons, disabled rows, separators, checkbox/radio state, nested submenus, and trigger actions;
- menu model changes must update without closing/reopening the menu where Quickshell provides change notifications.

The deployed protocol probe confirmed `nm-applet --indicator`, `blueman-applet`, and Fcitx5 expose `SystemTrayItem.menu` through `QsMenuOpener`. All three route through the same QML renderer. Live content mutation and raw/pixmap icon rendering still need direct visual verification. Do not hard-code app ids or app-specific menu parsing.

Important constraints / VERIFY items:

1. **Height and scrolling.** `TopBar.tipAreaH` remains 160 px for tooltips. All tray menus use `FlarePanelWindow` below the bar, and `MenuPage` clips and scrolls within monitor height. Recheck fractional scale and small outputs.
2. **Outside click and keyboard.** `FlarePanelWindow` captures outside clicks while open, drops its input mask during close animation, and handles Escape with generic Wayland keyboard focus. Directional row navigation remains a future improvement; test Niri, Hyprland, and Mango independently.
3. **`onlyMenu` left click.** If `SystemTrayItem.onlyMenu` is true, left click must open the QML menu instead of calling a no-op `activate()`. Normal items keep their primary activation semantics unless the tray protocol/app behavior proves otherwise.
4. **Fallback behavior.** Keep a compatibility path for items whose menu cannot be rendered reliably. If no usable custom menu is available, fall back to the protocol actions already exposed by Quickshell (`display()`, `secondaryActivate()`, and normal `activate()` as appropriate). **VERIFY** how Quickshell handles StatusNotifierItem implementations that expose only `ContextMenu`; do not assume that such items are represented as a usable `menu` handle.
5. **Menu icons.** `QsMenuEntry.icon` is documented as an image-source URL, but raw/pixmap-backed tray menu icons still need runtime verification with real applications. Mark unsupported icon forms as a rendering fallback, not a menu failure.
6. **Live DBusMenu updates.** Treat automatic live updates as the expected path, but test it explicitly with changing Wi-Fi/device lists. Quickshell's DBusMenu API also exposes layout refresh hooks for providers that fail to update correctly; use manual refresh only for reproduced compatibility cases, not as a polling loop.
7. **Item disappearance/reload.** Closing/removing a tray item while its menu is open must tear down menu/submenu state cleanly and must not leave a stuck flare, stale model object, focus grab, or overlay.

This is a visual/interaction improvement, not a reason to rewrite `SystemTray.items` ownership. Keep tray discovery in Quickshell and make the custom renderer a generic `QsMenuEntry` view reusable by Tray first and potentially by other DBusMenu surfaces later.

### 3.7 Settings group — **IMPLEMENTED / resource hardening pending**

Current features:

- shared `Brightness` service;
- shared `Audio` service;
- brightness scroll + night-light action;
- volume scroll, mute, and `pavucontrol`;
- UPower battery state;
- power-profiles-daemon state and cycling.

Current polling:

- Audio: every 2 s;
- Brightness: every 2 s;
- power profile: every 2 s;
- battery comes from UPower service.

P1 should reduce or gate avoidable idle polling where an event-driven API is available, but do not trade correctness for premature optimization.

### 3.8 Recorder — **DONE core**

`Recorder` is now a shared singleton polling recording status once per second. The right-side recorder module keeps elapsed-time display and start/stop behavior.

`CenterModule` also shows compact `REC` while recording. Recording takes priority over media in the center slot.

### 3.9 MPRIS media center — **IMPLEMENTED / VERIFY**

`Media.qml` uses native `Quickshell.Services.Mpris`:

- ignores stopped players;
- prefers a playing player;
- uses stable D-Bus name ordering as a tie-breaker;
- exposes title/artist/play state;
- center click toggles play/pause when supported.

`MusicGroup.qml` is now redundant. Do not build a second MPRIS stack around it.

### 3.10 Cava center visualizer — **IMPLEMENTED / VERIFY**

`Cava.qml` is a shared singleton:

- one process for the shell rather than one process per bar;
- runs only when media is playing and media center mode is active;
- waits for sustained detected sound before showing the visual;
- hides after silence;
- disables itself after an unexpected Cava failure until shell reload;
- center layout hides Cava when there is not enough safe horizontal space.

This is **not the same feature** as the old classic `cava_layer.py`/underbar effect. Porting that old layer is a separate future product decision; it is not required merely because the center Cava exists.

### 3.11 Volume/brightness OSD — **IMPLEMENTED / VERIFY**

Current N11 path:

- `level_control.sh` is the shared hardware-key facade;
- Hyprland, Niri, MangoWM, and Labwc keybindings are changed to call it;
- in Hikai it calls `level.change` IPC;
- in Classic or before QS is ready it executes the device command directly;
- mic mute bypasses the output-level OSD;
- Audio/Brightness queue rapid actions serially;
- `CenterState` keeps the OSD open until queued commands and feedback complete;
- a Top-layer flare extends from the bar;
- a separate Overlay window renders the level content over fullscreen clients;
- overlay input mask is empty so it should be click-through.

Do not call this DONE until P0 manual checks cover rapid input, fullscreen, classic fallback, multi-monitor, and screen scaling.

### 3.12 Rounded screen — **DONE core**

Implemented per screen:

- rounded-corner Canvas and border stroke;
- live radius/thickness;
- dynamic Top vs Overlay layer behavior;
- separate Bottom/Left/Right spacing windows;
- empty input mask.

P0 must verify that current top-bar padding/OSD work did not regress the four-edge frame when the bar is hidden.

### 3.13 Tooltip + Flare library — **core implemented; completion work remains**

Present:

- `FlareGeometry.js`;
- Node geometry test;
- `FlareSurface`;
- `FlareMorph`;
- `FlareContent`;
- `FlareHost`;
- `FlareEdges`;
- `TooltipLayer` migrated to `FlareHost`;
- multi-monitor ownership via `TooltipManager.activeBar`.

The core is real and usable, but the library should **not** be marked globally DONE yet:

- `FlareWindow.qml` does not exist;
- `components/flare/dev/FlareDemo.qml` does not exist;
- `docs/flare.md` does not exist;
- L3 tooltip lifecycle cases remain open (target disappears, bar hides, panel opening/click behavior);
- the Node suite does not yet cover every case requested by `FLARE_LIB_SPEC.md` (for example full left/right symmetry, all `k=0/0.5/1` piece cases, broader malformed-number cases);
- no performance baseline has been recorded.

Treat current flare code as **stable shared infrastructure**, then finish L3 before building large panel surfaces in P3.

### 3.14 Notifications — **PARTIAL fallback only**

Current state:

- top-bar `NotificationGroup` is a visual stub;
- no QS `NotificationServer`;
- no notification history;
- no DND state owned by QS;
- no notification center;
- no `notif` IPC target;
- `swaync` is intentionally kept alive as the temporary backend.

This is the largest missing core Hikai feature and is P2.

### 3.15 Launcher, HakuMenu, power, wallpaper — **PLANNED**

No production QML modules exist under:

- `modules/launcher/`;
- `modules/hakumenu/`;
- `modules/power/`;
- `modules/wallpaper/`.

`launcher.sh` already expects a `launcher` IPC target in Hikai. `UiState.activePanel` already provides the in-process one-panel-at-a-time state primitive and Logo already toggles `hakumenu`, but no panel consumes it.

### 3.16 Classic-parity surfaces — **PLANNED / selective porting**

Still absent in Hikai:

- edge trigger;
- taskbar;
- desktop icons;
- alternative bar variants.

Do not automatically port every Classic implementation 1:1. Each feature should first answer: “is this still desirable in a native QS shell, and what is the simplest native interaction model?”

### 3.17 Packaging, doctor, docs, Nix — **PLANNED**

Current gaps:

- no `src/packages/pkg-quickshell.txt`;
- `doctor.sh` has no QS health checks;
- install/update/rollback flows are not documented as Quickshell-aware release surfaces;
- Nix config has `cava` but no complete Hikai package/deployment contract;
- README still presents the Classic/Waybar stack as the primary feature set;
- no `docs/core/quickshell.md`;
- no Vietnamese Quickshell guide;
- no final flare guide.

---

## 4. Roadmap v2 — implementation order from this baseline

The old M0–M7 labels mixed already-finished work with future work and caused the master plan to drift. From this re-baseline, use **P0–P6** for new planning. Old commit messages may keep their historical M labels.

Priority order:

```text
P0 Freeze/stabilize current baseline
  ↓
P1 Top-bar + flare + Tray QML-menu hardening
  ↓
Tray full QML + Flare / shared large-panel primitive (implemented; runtime verification open)
  ↓
P2 Native notifications
  ↓
P3 Launcher / HakuMenu / power / wallpaper / picker migration
  ↓
P4 Remaining Classic-parity surfaces
  ↓
P5 Packaging / doctor / distro integration / release verification
  ↓
P6 Optional polish and experimental features
```

The Tray panel primitive is implemented ahead of native notifications so Notification Center can reuse its ownership/input model. P2 and the remaining P3 features may share primitives, but do not start both large feature families simultaneously before P0 is green.

---

## 5. P0 — Freeze and stabilize the current baseline — **IN PROGRESS**

### Goal

Turn the N11 and workspace implementation into a clean, reproducible baseline before adding another large surface.

Execution update (2026-10-07): N11 is already committed in `2da1b0cd`; the P0 work started from clean `HEAD` `68c3ba59`. Labwc startup, hidden workspaces, two Classic ↔ Hikai cycles, IPC reload, volume/brightness OSD, queued volume presses, Classic volume fallback, opaque state, and RoundedScreen with the bar hidden passed. The Hyprland, Niri, and MangoWM runtime matrices are pending until those sessions are available. P0 remains **IMPLEMENTED / VERIFY**, not DONE.

### P0.1 Close N11 as one coherent feature set

Scope already committed in N11:

- `Audio.qml`;
- `Brightness.qml`;
- `Media.qml`;
- `Recorder.qml`;
- `CenterState.qml`;
- `Cava.qml`;
- `CenterModule.qml`;
- `LevelOsdOverlay.qml`;
- `LevelOsdContent.qml`;
- `level_control.sh`;
- four-WM multimedia keybinding changes;
- TopBar center/flare changes;
- service registrations and related style/animation changes.

Required actions:

1. read the final diff end-to-end;
2. ensure no accidental unrelated formatting/refactor is mixed in;
3. reconcile the `Theme.barColor` policy;
4. verify all new files are tracked;
5. keep the Classic fallback path in `level_control.sh` functional;
6. do not claim completion until the runtime matrix below passes.

### P0.2 Runtime matrix for Dynamic Center + OSD

Verify on the deployed machine:

- scroll volume in Settings;
- scroll brightness in Settings;
- hardware volume up/down/mute;
- hardware brightness up/down;
- mic mute changes the source without showing the sink OSD;
- 10–20 rapid repeated hardware presses preserve every action in order;
- switch directly volume → brightness and brightness → volume;
- OSD remains visible over fullscreen clients;
- overlay is click-through;
- OSD closes only after action queue + feedback settle;
- QS reload/background polling does not spontaneously show the OSD;
- Classic mode still adjusts levels directly when QS is absent;
- recording center state overrides media;
- OSD temporarily overrides/hides center content correctly;
- media title elides before colliding with left/right modules;
- Cava hides before the physical center cluster collides on narrow screens;
- Cava failure does not spin-restart forever;
- multi-monitor outputs with different widths/scales remain centered;
- bar hide/show does not break RoundedScreen.

### P0.3 Workspace regression matrix

Run the same functional matrix on each supported backend:

```text
startup
keyboard workspace switch
left-click workspace
scroll workspace
open window
close window
move window to another workspace
urgent state if available
QS reload
backend event-stream/socket reconnect where applicable
multi-monitor active/focused behavior
```

Backend-specific policy:

- **Hyprland:** audit only; do not rewrite if it passes.
- **Niri:** verify the new event reducer carefully, including stale-state recovery after stream reconnect.
- **MangoWM:** audit only; specifically verify focused/active semantics and target monitor behavior.
- **Labwc:** verify Hikai starts and remains stable with workspace module hidden. Do not touch ext-workspace unless the upstream condition changed.

### P0.4 Documentation synchronization

After runtime results are known:

- update `QUICKSHELL_TESTING.md` so it stops saying Mango is unsupported;
- update WindowTitle notes to include verified Niri support if it passes;
- remove stale references to the deleted M2 plan from existing docs;
- remove outdated observations that refer to fixed `Env.wmName` activation logic;
- keep Labwc documented as an upstream Quickshell limitation, not an unfinished local implementation;
- make `FLARE_LIB_SPEC.md` status wording match actual L3/L4 state.

### P0 acceptance

All of the following are required:

```bash
git diff --check
scripts/precommit_check.sh
```

and, on the deployed system:

- no new `TypeError`, `ReferenceError`, singleton/type errors, or crash loop in QS logs;
- Dynamic Center/OSD manual matrix passes;
- Hyprland workspace matrix passes;
- Niri workspace matrix passes;
- Mango workspace matrix passes;
- Labwc Hikai startup passes with workspaces intentionally hidden;
- Classic ↔ Hikai switch still works repeatedly;
- clean intentional git status for the handoff/commit.

---

## 6. P1 — Top-bar and flare hardening — **IMPLEMENTED / VERIFY**

The 2026-10-08 Clock/Tray closeout fixed component-only tooltip activation and verified Clock hover, left click, scroll, reset, hide/restore, and clean reload on one Niri output at scale 1.0. The subsequent Tray milestone routes both short and long usable DBusMenus through a shared QML + Flare panel. See `P1_STATUS.md` and `TRAY_FULL_QML_FLARE_REPORT.md` for runtime matrices. T1–T13 as a whole, fractional scale, multi-monitor, and hover performance remain VERIFY.

### Goal

Finish the current shell frame before using it as the base for multiple large panels.

### P1.1 Tooltip lifecycle correctness

Fix/verify:

- hide tooltip when its target becomes invisible or is destroyed;
- hide tooltip when the bar is hidden;
- hide or hand off tooltip state when opening a panel;
- no stuck tooltip after rapid hover + module disappearance;
- no cross-monitor tooltip ownership leak.

Do not move geometry math back into Tooltip code.

### P1.2 Finish Flare L3 verification

Expand `test_flare_geometry.js` to cover the contract in `FLARE_LIB_SPEC.md`, including:

- left/right symmetry;
- `pieces()` at `k=0`, `0.5`, and `1` on both sides;
- connection-edge invariants;
- malformed/NaN inputs;
- zero-radius/zero-hug-radius handling where meaningful.

Record a lightweight performance baseline:

- idle QS CPU;
- hover/morph CPU;
- scene-graph frame timing;
- no Wayland popup resize/reposition churn caused by tooltip morphing.

### P1.3 Clock/calendar completion

The placeholder calendar text has been replaced by `CalendarGrid` in the existing tooltip/Flare path. The component-only hover gate and left-click request were fixed in the 2026-10-08 closeout. Runtime interaction passed at scale 1.0; fractional scale and a second monitor remain VERIFY.

Requirements:

- current month initially;
- scroll changes month;
- right-click resets to current month;
- today highlighted;
- no separate popup window for a small tooltip calendar;
- width fits flare bounds and fractional scale.

### P1.4 Tray QML menu renderer — model + short-menu path

The `QsMenuOpener`-backed generic QML renderer is implemented for short and long menus. The short fixture and Wi-Fi submenu paths have passed on Niri at scale 1.0. The staged sections below retain the original design requirements; the shared panel implementation is recorded in `TRAY_FULL_QML_FLARE_REPORT.md`. Native fallback remains only for unavailable or persistently empty menu models.

**Stage A — protocol/model probe before styling**

Build a minimal probe/dev surface that opens `SystemTrayItem.menu` through `QsMenuOpener` and records/visually exposes:

- top-level `children`;
- text/icon/enabled/separator state;
- checkbox/radio `buttonType` + `checkState`;
- `hasChildren` and recursive submenu contents;
- `triggered()` behavior;
- `onlyMenu`;
- model changes while the menu stays open.

Probe at minimum:

- `nm-applet --indicator`;
- `blueman-applet`;
- one ordinary application tray menu;
- one item with no menu if available;
- one app suspected to expose only `ContextMenu` if available.

Do not proceed by app-specific heuristics. Record any Quickshell/upstream incompatibility as a capability/fallback case.

**Stage B — reusable QML menu content**

Create a generic menu content component, separate from Tray ownership, capable of rendering:

- normal action rows;
- icon + label;
- disabled state;
- separators;
- checkbox and radio indicators;
- submenu affordance;
- nested `QsMenuOpener`;
- bounded width and text elision/wrap policy;
- vertical scrolling when content exceeds the host's safe height.

The renderer must consume `QsMenuEntry` state directly rather than copying the whole menu into a second stale JS model.

**Stage C — Flare integration for short menus**

For menus that fit the current top-bar interaction surface:

- render the menu through the existing `FlareHost`/Flare geometry path;
- preserve the tray item's anchor and right-edge hugging;
- morph tooltip → menu when the same tray target owns both states;
- suppress the tooltip while the menu is open;
- close cleanly if the tray item disappears or the bar hides;
- verify 1.0x, 1.25x, and 1.5x scale plus multi-monitor right edges.

Do **not** resize the TopBar window to accommodate long menus. Long-menu input/window handling is completed with the reusable large-panel/overlay primitive in P3.0.

**Click policy**

- left click + `onlyMenu == true` → open the QML menu;
- left click + normal item → `activate()`;
- right click + usable menu → open the QML menu;
- custom renderer unsupported/fails → platform `display()` fallback where available;
- no menu → preserve a tested `secondaryActivate()`/activation fallback;
- middle-click behavior remains protocol/app dependent and is added only after a real use case is reproduced.

**VERIFY before closing P1.4**

- raw/pixmap menu icon rendering;
- ContextMenu-only tray items;
- live Wi-Fi/Bluetooth menu mutations without stale rows;
- checkbox/radio state updating after trigger;
- submenu lifecycle and back/hover/click policy;
- item disappearance and Quickshell reload while menu is open.

### P1.5 Polling/resource audit

Measure before optimizing.

Candidates:

- Audio 2 s poll;
- Brightness 2 s poll;
- Recorder 1 s poll;
- power profile 2 s poll.

Prefer event-driven APIs if Quickshell exposes reliable ones. Otherwise gate only where doing so does not make state stale when the component becomes visible again.

### P1.6 Remove/deprecate dead UI placeholders

Decision:

- `MusicGroup.qml`: native MPRIS center supersedes it; remove or clearly mark deprecated after confirming no import/caller depends on it.
- `MonitorGroup.qml`: keep as an optional component if wanted; do not mount it by default unless the user requests it.

### P1 acceptance

- tooltip tests T1–T13 pass or have explicit upstream exceptions;
- no stuck tooltip when bar/target hides;
- geometry tests cover the full Flare spec contract;
- calendar is functional;
- tray `QsMenuOpener` probe is documented against real tray applications;
- short custom tray menus render text/icons/state/separators/submenus without stale copied models;
- `onlyMenu` left-click semantics are correct;
- unsupported/custom-menu edge cases fall back without breaking tray activation;
- idle resource numbers are recorded;
- no new poller is introduced per screen unnecessarily.

---

## 7. P2 — Native notifications and control center

### Goal

Remove the largest remaining dependency on the Classic shell stack: `swaync`.

### P2.1 Notification ownership transition

Hard rule: QS must successfully own `org.freedesktop.Notifications` **before** Hikai stops allowing swaync.

Transition order:

1. implement QS `NotificationServer`;
2. prove `notify-send` reaches QS;
3. prove replacement/update/close semantics work;
4. implement popup UI;
5. implement history/control center;
6. implement DND state;
7. implement `notif` IPC facade target;
8. only then remove `QS_ALLOW_SWAYNC=1` and restore swaync as a violation in `haku_backend.sh --verify`.

Never create a deployment state where both servers race for the same D-Bus name.

### P2.2 Notification data model

Minimum fields:

- id;
- app name / desktop entry when available;
- summary;
- body;
- icon/image;
- urgency;
- timestamp;
- timeout;
- actions;
- read/dismissed state as needed by the UI.

Keep rendering separate from the notification model.

### P2.3 Popup behavior

Requirements:

- multiple notifications queue cleanly;
- replacement id updates existing notification;
- expiration works;
- critical notification policy is explicit;
- DND suppresses popup but not history unless intentionally configured otherwise;
- multi-monitor placement policy is explicit and stable;
- notifications do not steal keyboard focus.

### P2.4 Control center

Minimum:

- open/close from top-bar Notification module;
- history list;
- clear all;
- DND toggle;
- empty state;
- action buttons where supplied;
- closes reliably on outside action / state toggle according to panel policy.

Reuse Flare/large-panel infrastructure where practical; do not duplicate corner/hugging math.

### P2.5 IPC contract

Implement:

```text
notif.toggleCenter()
notif.toggleDnd()
notif.clearAll()
notif.count() -> int/string suitable for CLI output
```

`src/core/util/notif.sh` must work unchanged or with a minimal documented contract update.

### P2 acceptance

- `notify-send` appears in QS without swaync;
- notification actions work;
- DND works;
- clear/count/toggle work through `notif.sh`;
- Hikai `--verify` again treats swaync as forbidden;
- Classic notifications remain unchanged;
- crash/reload behavior does not silently lose D-Bus ownership without fallback visibility.

---

## 8. P3 — Launcher, HakuMenu, power, wallpaper, and picker migration

### Goal

Remove Hikai's remaining dependency on rofi for normal shell interaction.

### P3.0 Large-panel primitive first — **Tray primitive IMPLEMENTED / VERIFY**

`FlarePanelWindow` now provides the reusable large-panel host for Tray. Notification Center and later panels should reuse its ownership and input contract. Fractional-scale, multi-monitor, and cross-compositor runtime verification remain open.

Requirements:

- transparent fixed-size `PanelWindow` below/around the bar rather than runtime window resizing;
- `ExclusionMode.Ignore`;
- full outside-click input capture while the menu is open, followed by an empty input mask during close morph so desktop clicks are unblocked;
- safe multi-monitor ownership;
- no duplicated flare geometry;
- verify the seam with TopBar at 1.0x, 1.25x, and 1.5x scale.

Also finish the opt-in flare demo and `docs/flare.md` as the acceptance example for this reusable primitive.

#### P3.0a Tray long-menu / interaction overlay — **IMPLEMENTED / VERIFY**

The Tray implementation now uses the reusable window/input primitive for menus that cannot safely live inside the 160 px tooltip area:

- tall DBusMenu content with a bounded, scrollable viewport;
- transparent outside-click capture that closes menu/submenu state without blocking the rest of the desktop after close;
- keyboard focus and navigation policy (at minimum close/escape, directional/submenu navigation where implemented, activate, and scroll);
- correct ownership when switching between tray items or monitors;
- no Hyprland-only focus dependency: any `HyprlandFocusGrab` support is an optimization behind a generic behavior contract;
- tooltip → tray menu → submenu transitions reuse Flare geometry/state rather than opening unrelated platform popups.

The overlay may be shared by Launcher/HakuMenu/Power/other large panels, but Tray must not create a second incompatible full-screen click-catcher. Define one ownership/input model and reuse it.

### P3.1 Launcher

Implement `modules/launcher/` with at least:

- `drun` mode;
- emoji mode;
- keyboard-first filtering;
- launch and close behavior;
- one panel active at a time through `UiState`;
- `launcher.open(mode)` IPC.

`src/core/util/launcher.sh` is the external facade and should not need compositor-specific logic.

### P3.2 HakuMenu

Logo already toggles `UiState.toggle("hakumenu")`.

Build the actual panel around existing HakuSpace script/actions instead of copying their implementation into QML. QML should be the UI/orchestration layer; shell scripts remain the action layer unless there is a strong reason to replace them.

### P3.3 Power menu

Provide a native Hikai power surface for shutdown/reboot/logout/lock/suspend actions as supported by existing HakuSpace scripts.

Require a deliberate confirmation policy for destructive actions; preserve Classic behavior.

### P3.4 Wallpaper picker

Build the Hikai wallpaper browser on the current wallpaper tooling rather than creating a second wallpaper engine.

If the existing scripts need machine-readable enumeration, add one stable JSON/list contract and consume it from QS.

### P3.5 Clipboard menu

Move the user-facing clipboard selection path away from direct `rofi -dmenu` in Hikai. Reuse `haku_pick` if a simple textual selector is sufficient; use a dedicated panel only if previews/actions justify it.

### P3.6 Migrate direct `rofi -dmenu` call sites

Current scan finds **15 direct calls** in these scripts:

- `src/core/app/taskbar/taskbar_manager.sh` — 1;
- `src/core/sys/shutdown.sh` — 1;
- `src/core/sys/exit.sh` — 1;
- `src/core/util/clipboard_menu.sh` — 1;
- `src/core/util/gen_shortcut.sh` — 1;
- `src/core/util/waybar_manager.sh` — 1;
- `src/core/theme/rofi_theme_switcher.sh` — 1;
- `src/core/util/record.sh` — 2;
- `src/core/util/shell_switcher.sh` — 2;
- `src/core/theme/change_theme.sh` — 4.

Migration policy:

- generic textual choice → `haku_pick.sh`;
- password prompt → `haku_pick.sh --password`;
- fixed-list selection that forbids custom text → `--no-custom`;
- launcher/emoji → launcher IPC, not generic picker;
- shutdown/power → power panel where appropriate;
- rofi-theme-only tools may be hidden/disabled in Hikai instead of ported;
- Classic still uses rofi through the facade and must remain behavior-compatible.

After migration, add a CI/precommit check that rejects new direct `rofi -dmenu` usage from Hikai-capable paths unless explicitly allowlisted.

### P3.7 Finish picker request options

Make Hikai honor the request fields already sent by `haku_pick.sh` where they still make sense:

- initial selection;
- requested line count/height policy;
- width/height bounds.

Do not copy rofi pixel semantics blindly if they conflict with the native shell layout; document the mapping.

### P3 acceptance

- Super+R / launcher key works in Hikai;
- emoji picker works;
- Logo opens/closes HakuMenu;
- power menu works;
- wallpaper picker works;
- clipboard selection works;
- record/shell/theme flows no longer fail because rofi is forbidden in Hikai;
- long tray menus scroll correctly, close on outside click/Escape, and do not require Hyprland-specific focus behavior;
- tray menu ownership cannot conflict with Launcher/HakuMenu/Power overlay ownership;
- no duplicate panel can remain open through `UiState`;
- Classic paths remain unchanged from the user's perspective.

---

## 9. P4 — Remaining Classic-parity surfaces

### Goal

Decide and implement only the Classic features that still improve the Hikai experience.

### P4.1 Edge trigger

Port only after launcher/menu surfaces have a stable open/close contract.

Requirements:

- no accidental activation during normal pointer use;
- multi-monitor policy explicit;
- no keyboard grab unless needed;
- layer-shell input region minimal;
- integrates with `UiState` instead of launching an independent competing UI.

### P4.2 Taskbar

Before coding, choose the Hikai product behavior:

- classic-style persistent taskbar;
- compact running-app strip;
- task switcher integrated into a panel;
- or intentionally omit it.

Do not copy the old implementation mechanically.

### P4.3 Desktop icons

Optional and low priority. Desktop icons are a much larger interaction problem than a bar module: drag/drop, selection, context menu, output layout, scaling, file monitoring.

Only start if the user still wants them after launcher/taskbar parity is usable.

### P4.4 Classic Cava layer decision

The current center Cava does not replace the classic underbar/layer aesthetic feature. Decide explicitly:

- center Cava is enough → no port;
- or native Hikai underbar is still desired → design it as a separate surface.

Do not run two Cava processes if one shared audio stream can support both visuals.

### P4.5 Additional bar variants

Keep `top` as the only supported Hikai bar until the base shell is stable. Alternative variants are optional and should reuse the same services/modules rather than forking state logic.

### P4 acceptance

This phase is complete when the **selected** parity set is documented and implemented. Omitted features are acceptable if the decision is explicit; parity does not mean blind 1:1 copying.

---

## 10. P5 — Packaging, doctor, distro integration, release verification

### Goal

Make Hikai installable, diagnosable, and supportable rather than a repository-only development mode.

### P5.1 Package contract

Create/extend package lists for the actual runtime dependencies. Verify package names per supported distribution rather than guessing.

Expected categories include:

- Quickshell;
- Qt/Wayland dependencies pulled or required by it;
- `jq`;
- `brightnessctl`;
- PipeWire/WirePlumber CLI used by `wpctl`;
- `cava` if center visualizer remains enabled;
- clipboard tools;
- power-profiles-daemon where Settings exposes it;
- Node only as a development/test dependency if production runtime does not need it.

### P5.2 Installer/update/rollback

Verify:

- QS config is deployed atomically enough to avoid half-updated shell startup;
- scripts such as `level_control.sh` are installed;
- update does not leave old QML files that were deleted from the repo;
- rollback restores a compatible QML + script set;
- Classic remains recoverable even if a Hikai update is broken.

### P5.3 `doctor.sh`

Add Hikai diagnostics:

```text
backend state
qs/quickshell executable
Quickshell version
hakuspace config present
shell.ping IPC
haku_backend.sh --verify
required external commands
qs log location / recent fatal errors
notification ownership after P2
WM backend detected
Labwc workspace limitation when applicable
```

Doctor output should distinguish warning vs fatal failure.

### P5.4 Nix / distro docs

Add the actual required packages and deployment notes to NixOS/Fedora/Arch-facing documentation. Do not claim support until tested.

### P5.5 Full release matrix

Minimum release verification:

| Area | Hyprland | Niri | MangoWM | Labwc |
|---|---:|---:|---:|---:|
| Hikai starts | required | required | required | required |
| Top bar | required | required | required | required |
| Workspaces | required | required | required | **expected hidden while upstream crash remains** |
| Dynamic Center/OSD | required | required | required | required |
| Notifications | required | required | required | required |
| Launcher/menu | required | required | required | required |
| Classic fallback | required | required | required | required |
| Reboot persistence | required | required | required | required |
| Multi-monitor | required on available test machines | required on available test machines | required on available test machines | required where available |

A known upstream Labwc workspace limitation does not block release if the shell itself remains stable and the limitation is documented.

### P5.6 User/developer documentation

Create/update:

- `docs/core/quickshell.md`;
- Vietnamese equivalent;
- `docs/flare.md`;
- architecture overview;
- README feature/status section;
- install/update/rollback notes;
- troubleshooting/doctor notes.

At this point `docs/task/HAKUSPACE_QUICKSHELL_PLAN.md` can become a historical roadmap rather than the only operational documentation.

---

## 11. P6 — Optional polish / experimental work

Only after P5 release readiness:

- alternative bar layouts;
- richer app icons/title mapping;
- themed tray menus if native menus are insufficient;
- desktop icons;
- additional animated surfaces;
- per-monitor panel preferences;
- accessibility polish;
- keyboard navigation across every panel;
- deeper event-driven replacement of remaining pollers;
- optional restored system monitor UI;
- advanced media controls/artwork.

Do not let P6 items delay native notifications, launcher/menu parity, or packaging.

---

## 12. WM contract going forward

Every workspace backend should normalize to the existing shape:

```text
key
label
name
output
active
focused
occupied
windows
focusedTitle
urgent
special
```

`WM.caps` remains the capability contract for data/actions a backend can actually support.

Rules:

1. no UI code should parse compositor IPC directly;
2. no backend should invent data it cannot know;
3. event-driven sources are preferred over polling;
4. reconnect must not leave stale workspaces indefinitely;
5. backend limitations are expressed through capabilities/visibility, not fake values;
6. multi-monitor semantics are compositor-specific and should not be forced into identical behavior when the compositors differ;
7. **verify before refactor**, especially for Hyprland and MangoWM.

---

## 13. UI/state architecture rules

1. Shared hardware/system state belongs in a singleton service when more than one screen/module consumes it.
2. Per-screen components must not start duplicate global processes unnecessarily.
3. `UiState.activePanel` is the one-panel-at-a-time coordinator for large shell surfaces.
4. Small hover content uses Tooltip/Flare; large interactive panels use the future large-panel host.
5. Flare geometry remains centralized; do not duplicate edge-hugging math in notifications/launcher/menu code.
6. `Theme` owns visual tokens. Hard-coded values require an explicit product reason.
7. Keep Classic script actions as the backend where appropriate; QML is not required to reimplement every shell action.
8. Hikai-specific failure must always preserve the emergency path back to Classic.

---

## 14. Code and review rules for Gemini

For every implementation handoff:

1. inspect `git status --short`, `git diff --cached`, and `git diff` before editing;
2. do not use regex/sed bulk patching on QML;
3. edit only the milestone scope;
4. do not “clean up” stable Hyprland/Mango code unless a test fails;
5. do not re-enable Labwc ext-workspace without a new successful probe;
6. do not guess Quickshell APIs — verify against the installed version/probe;
7. keep missing dependencies non-fatal where the feature can degrade gracefully;
8. run `git diff --check`;
9. run `scripts/precommit_check.sh`;
10. read the full final diff;
11. state exactly what runtime checks were not possible;
12. add/update manual checks in `QUICKSHELL_TESTING.md` for new interactive behavior.

Do not mark a milestone DONE in this plan solely from static tests.

---

## 15. Required implementation report format

Every Gemini report should contain:

### 15.1 Scope

- milestone/step implemented;
- files intentionally changed;
- files intentionally not changed.

### 15.2 Behavior changed

Describe user-visible behavior and contracts, not just filenames.

### 15.3 Verification run

Paste real commands and concise results for:

```bash
git diff --check
scripts/precommit_check.sh
```

plus any milestone-specific probes/tests.

### 15.4 Runtime checks not run

Explicitly list checks requiring the user's compositor, screen, D-Bus session, multi-monitor setup, or visual confirmation.

### 15.5 Git state

Include:

```bash
git status --short
git diff --stat
```

and identify whether changes are staged or unstaged.

### 15.6 Risks / follow-up

Only concrete unresolved items. Do not add speculative refactors.

---

## 16. Definition of Done for the Hikai project

Hikai can be considered release-ready when:

- backend switching/fallback is reliable;
- TopBar is stable on all four WMs, with Labwc workspace limitation handled gracefully;
- Hyprland/Niri/Mango workspace behavior is verified;
- Dynamic Center, MPRIS/Cava, volume/brightness OSD, tray, settings, recorder, clock/calendar are stable;
- QS owns notifications and swaync is no longer needed in Hikai;
- launcher/HakuMenu/power/wallpaper/clipboard user paths no longer depend on forbidden rofi processes in Hikai;
- selected parity surfaces are implemented or explicitly omitted;
- no stale classic process appears in Hikai;
- Classic remains fully recoverable;
- install/update/rollback/doctor understand Hikai;
- dependencies are packaged/documented;
- release matrix passes on Hyprland, Niri, MangoWM, and Labwc with the documented Labwc exception;
- README/core docs/Vietnamese docs match the code;
- static tests, runtime tests, and manual visual checks are all recorded.

---

## 17. Immediate next action

Finish the open P0 compositor matrix, interactive P1 checks, and remaining Tray full-QML runtime checks in `QUICKSHELL_TESTING.md`. The P1 baseline is recorded in `P1_STATUS.md`; the Tray migration and current acceptance matrix are recorded in `TRAY_FULL_QML_FLARE_REPORT.md`.

Do not mark P1 DONE from static checks or the Niri protocol probe alone. The tray short-menu input path, other WMs, fractional scales, multi-monitor behavior, hover performance, and remaining protocol fallback cases still need verification.

P2 native notifications follows this Tray verification work and reuses the shared panel ownership/input primitive.

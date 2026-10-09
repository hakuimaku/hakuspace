# HakuSpace × Quickshell

This is the **canonical master implementation plan** for HakuSpace Hikai/Quickshell. It covers the whole roadmap, not only P3.

Companion documents in `docs/task/`:

- `QUICKSHELL_STYLE.md` — canonical visual/token/surface contract;
- `QUICKSHELL_TESTING.md` — manual/runtime verification matrix;
- `FLARE_LIB_SPEC.md` — shared Flare geometry/rendering contract.

Canonical implementation baseline for this revision is the stable commit:

```text
a7b6f0e7  P2 notifications DONE
```

The user intends to discard/fallback the uncommitted P3 geometry experiments and start P3 again from a clean stable checkpoint. Therefore this document describes the desired repository **after that fallback**, not the abandoned experimental working tree.

> **2026-10-08 P3 mockup lock:** the seven latest Paint mockups — `base.png`, `navigation.png`, `dashboard.png`, `sidebar.png`, `setting.png`, `hakumenu.png`, `wallpaper-change.png` — supersede the earlier P3 Navigation/HakuMenu/Wallpaper visual drafts. The abandoned TopBar-center collar/notch/shoulder experiment remains cancelled.

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

For this plan, use `a7b6f0e7` (`P2 notifications DONE`) as the canonical stable fallback point before P3 product work.

Expected P3 starting state:

- branch: `quickshell`;
- P2 native notifications are committed and active in Hikai;
- Hikai no longer depends on swaync for notification ownership;
- the experimental P3 TopBar-center collar/profile work is discarded;
- the experimental first Wallpaper/Navigation pass is discarded unless a specific reusable primitive is deliberately recovered after review;
- product-code working tree is clean before the first P3 commit.

Before starting P3:

```bash
git status --short
git log -5 --oneline
git diff --check
scripts/precommit_check.sh
```

Recommended stable marker:

```bash
git tag p3-v2-baseline
```

Do not start P3 from a dirty product-code tree. Documentation-only edits may be committed separately.

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

At the P2-complete baseline, `shell.qml` creates:

1. one global `Picker` overlay;
2. one `TopBar` per `Quickshell.screens` screen;
3. one `TrayMenuPanel` per screen;
4. one `NotificationCenterPanel` per screen;
5. one `NotificationPopup` per screen;
6. one `LevelOsdOverlay` per screen;
7. one `RoundedScreen` per screen.

Current IPC targets at the P2-complete baseline:

| Target | Functions | Status |
|---|---|---|
| `shell` | `ping()`, `reload()`, `quit()` | **DONE** |
| `picker` | `open(fifo, jsonString)` | **DONE core**, remaining caller migration belongs to later native-surface work |
| `level` | `change(action)` | **DONE core / visual polish in P3** |
| `notif` | `toggleCenter()`, `toggleDnd()`, `clearAll()`, `count()` | **DONE** |
| `launcher` | Hikai routing to be redefined through HakuMenu Drun | **P3 PLANNED** |
| `hakumenu` | center-origin menu contract | **P3 PLANNED** |
| `power` | native surface contract | **P3/P4 PLANNED** |
| `wallpaper` | native carousel contract | **P3 PLANNED** |

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

Baseline layout:

| Area | Modules | Current status |
|---|---|---|
| Left | Logo → Workspaces → WindowTitle | Implemented |
| Physical center | conditional Cava + `CenterModule` | Implemented; keep the stable fallback visual silhouette in P3 |
| Right | Tray → Settings → Recorder → Clock → Notification | Implemented; Notification is native |

Not mounted by default:

- `MonitorGroup.qml` — functional drawer/service-backed implementation may exist, but Dashboard P3 uses a separate monitor card contract;
- obsolete Music placeholder — native MPRIS is handled through `Media` / center components and will also feed the Dashboard MPRIS card.

**P3 rule:** do not reintroduce the abandoned TopBar-center collar/notch/shoulder redesign. P3 may fix centering, input, OSD, and HakuMenu triggering without changing the base center silhouette.

### 2.4 Current shell-side integration

The Classic/Hikai boundary is already established:

- `haku_backend_lib.sh` owns backend state and common QS helpers;
- `haku_backend.sh` switches `classic ↔ hikai`, stops the opposite stack, verifies health, and rolls back on failure;
- `qs_supervisor.sh` handles Quickshell crash/restart fallback;
- `session_start.sh --early` starts the selected backend;
- manager guards prevent Classic Waybar/taskbar/edge/rounded/cava/desktop-icon processes from reappearing in Hikai;
- `notif.sh` routes to native Hikai notification IPC while Classic retains its Classic notification path;
- Hikai startup/verification treats native Quickshell as the owner of `org.freedesktop.Notifications` and does not intentionally keep swaync alive;
- `launcher.sh` remains an external facade; P3 will route its Hikai path into HakuMenu's Drun tab rather than a second unrelated launcher UI;
- `haku_pick.sh` remains available for generic picker-style workflows;
- Super+Esc remains the backend-independent emergency escape to Classic.

Future P3/P4 work extends these boundaries rather than bypassing them with direct compositor-specific UI commands.

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

### 3.14 Notifications — **DONE core / P3 visual polish**

At `a7b6f0e7` native Hikai notifications are committed:

- Quickshell owns `org.freedesktop.Notifications` in Hikai;
- notification history/store is native;
- popup and Notification Center are native Quickshell surfaces;
- replacement, timeout, remote close, DND and Clear All have runtime evidence from P2;
- `notif` IPC exists;
- Classic keeps its separate Classic notification route;
- swaync is no longer required as the Hikai notification backend.

P3 is **not** a notification-protocol rewrite. It only applies the approved shell geometry/style polish:

- RoundedScreen/frame attachment;
- popup Flare presentation;
- Notification Center spacing/height;
- primary `Clear` treatment;
- any small runtime hardening found during P3 regression tests.

### 3.15 Native P3 shell surfaces — **PLANNED from mockup-locked spec**

The current P3 source-of-truth surfaces are:

- **Navigation** — radial Logo-origin controller with Dashboard / Sidebar / Settings;
- **Dashboard** — avatar + Clock + MPRIS + Calendar + ROM/RAM/CPU/GPU cards, with intentionally reserved empty space;
- **Sidebar** — immediate hover expansion from the Navigation Sidebar sector;
- **Settings** — intentionally a stub during P3;
- **HakuMenu** — separate center-origin shell surface with General / Drun / Theme;
- **Wallpaper** — center-selected stacked carousel, not the old full-width dual-front Flare concept;
- **remaining native migration** — Power / Clipboard / any remaining direct Hikai rofi caller, one feature at a time.

Important semantic split:

```text
Navigation != HakuMenu
```

The Logo owns Navigation. The TopBar center interaction owns HakuMenu. Do not merge their state, content or geometry.

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

## 4. Roadmap v3 — implementation order from the P2-complete baseline

```text
P0  Baseline/runtime stabilization                       DONE for current P2 baseline
P1  TopBar / Tray / Flare foundation                    DONE core; residual audits are non-blocking
P2  Native notifications                                DONE
P3  Mockup-locked native shell surfaces                 CURRENT MAJOR MILESTONE
P4  Remaining Classic-parity surfaces                   PLANNED
P5  Packaging / doctor / distro / release verification  PLANNED
P6  Optional polish / experimental work                 OPTIONAL
```

P3 is intentionally executed as **small atomic commits**. Every accepted sub-part becomes a fallback point before the next dependent sub-part starts.

High-level P3 dependency order:

```text
baseline cleanup / RoundedScreen foundation
→ Navigation
→ Dashboard
→ Sidebar
→ Settings stub
→ HakuMenu shell
→ HakuMenu General
→ HakuMenu Drun
→ HakuMenu Theme stub
→ Wallpaper carousel
→ Notification / OSD / tooltip / tray frame polish
→ remaining native migration
→ cross-WM + scale verification
→ cleanup + canonical docs
```

Do not parallelize dependent visual foundations in one dirty tree.

## 5. P0 — Freeze and stabilize the current baseline — **DONE for P2 baseline**

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

## 6. P1 — Top-bar and flare hardening — **DONE core / light audit backlog**

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

## 7. P2 — Native notifications and control center — **DONE**

### Goal

Replace the Hikai swaync dependency with a native Quickshell notification server, popup stack, history/control center and IPC contract while preserving Classic behavior.

### Delivered baseline

At commit `a7b6f0e7`:

- Hikai owns `org.freedesktop.Notifications` through Quickshell;
- startup restores notification history before enabling the native server;
- popup and Notification Center are native;
- DND and Clear All exist;
- replacement-id semantics are handled;
- timeout/expire handling exists;
- remote close handling exists;
- `notif.toggleCenter`, `toggleDnd`, `clearAll`, and `count` IPC functions exist;
- backend verification rejects swaync in Hikai;
- Classic retains its Classic notification path;
- switching `Hikai → Classic → Hikai` was part of the P2 runtime verification evidence.

### P2 follow-up policy

P2 is not reopened as a large infrastructure milestone during P3.

If P3 finds notification defects, fix them as small isolated commits. P3 may change presentation/attachment but should preserve the native data model and protocol ownership unless a concrete regression proves otherwise.

### P2 acceptance — closed

P2 remains accepted while all of the following stay true:

- `notify-send` reaches native Hikai notifications;
- replacement does not duplicate the same active notification;
- timeout/close semantics work;
- DND suppresses popup appropriately;
- history/Center remains usable;
- `notif` IPC works;
- Hikai verification treats swaync as forbidden;
- Classic notification behavior is unchanged.

## 8. P3 — Mockup-locked native shell surfaces — **CURRENT**

### Goal

Build the next Hikai shell layer from the latest seven Paint mockups while preserving the stable P2 baseline and creating a Git fallback point after every accepted sub-part.

Authoritative P3 mockups:

```text
base.png
navigation.png
dashboard.png
sidebar.png
setting.png
hakumenu.png
wallpaper-change.png
```

If an older P3 mockup conflicts with these, the seven files above win. AI-generated concept images are not authoritative.

The abandoned TopBar-center collar/notch/shoulder experiment is explicitly out of scope.

---

### P3.0 — Git safety and RoundedScreen foundation

#### P3.0.1 Atomic-commit rule

Every accepted unit follows:

```text
implement
→ static checks
→ focused runtime check
→ screenshot/evidence where visual
→ review
→ commit
→ only then start the next dependent unit
```

Commit subjects should be narrow:

```text
p3(frame): lock RoundedScreen chassis
p3(navigation): implement three-region radial visual
p3(dashboard): add mpris control card
p3(hakumenu): add drun interaction
p3(wallpaper): add carousel navigation
```

Do not create a multi-feature `P3` mega-commit. Do not amend an accepted checkpoint after beginning the next task; make a new fix commit instead.

Recommended milestone tags:

```text
p3-v2-baseline
p3-v2-navigation-pass
p3-v2-hakumenu-pass
p3-v2-wallpaper-pass
p3-v2-shell-polish-pass
p3-v2-final
```

#### P3.0.2 Remove superseded experiments

From the clean fallback baseline, do not restore:

- TopBar center collar / shoulder / knee / rail-carve experiments;
- the old full-width Wallpaper dual-front reveal;
- stale debug geometry from those experiments.

Commit only if cleanup is actually needed:

```text
p3(baseline): remove superseded visual experiments
```

#### P3.0.3 RoundedScreen chassis

`base.png` defines the shell frame relationship.

Requirements:

- frame follows the physical output perimeter;
- no left/right/bottom edge gap;
- corners are continuous;
- TopBar ON must not make the RoundedScreen top rail disappear;
- the top frame/rail is visually stronger than side/bottom where configured;
- TopBar and RoundedScreen remain separate layers instead of faking one geometry by hiding the other.

Runtime matrix:

```text
Rounded ON + TopBar ON
Rounded ON + TopBar OFF
Rounded OFF + TopBar ON
TopBar hide → show
Rounded OFF → ON
Quickshell reload
```

Commit:

```text
p3(frame): lock RoundedScreen chassis
```

#### P3.0.4 Shared frame geometry

One per-output provider owns equivalent metrics:

```text
frameTopY
frameTopThickness
frameInnerTopY
frameInnerLeftX
frameInnerRightX
frameInnerBottomY
cornerRadius
roundedEnabled
```

Surfaces consume these values instead of rebuilding `Theme.topBarHeight + N` locally.

Commit:

```text
p3(geometry): expose shared frame bounds
```

Add/reuse one bounded attachment helper for TopBar-origin surfaces, then commit separately:

```text
p3(geometry): standardize frame attachment
```

---

### P3.1 — Navigation

Reference: `navigation.png`.

Navigation is the temporary radial Logo-origin controller. It is **not HakuMenu**.

#### P3.1.1 State/lifecycle

Explicit logical states:

```text
closed
open
handoff-dashboard
handoff-sidebar
handoff-settings
```

Requirements:

- Logo opens Navigation;
- close/reopen is deterministic;
- Escape closes;
- no duplicate instance;
- correct output ownership;
- focus/input cleanup after close/reload;
- one-large-surface ownership is respected.

Commit:

```text
p3(navigation): add explicit navigation state model
```

#### P3.1.2 Radial visual

Visible regions:

```text
Dashboard
Sidebar
Settings
```

Requirements:

- reads as one circular/radial controller;
- no generic rectangular popup;
- visible segmentation follows the mockup;
- internal hitboxes may be simplified for robust pointer/keyboard use;
- keyboard access exists even if pointer selection is primary.

Commit:

```text
p3(navigation): implement three-region radial visual
```

---

### P3.2 — Dashboard

Reference: `dashboard.png`.

Dashboard is a real shell surface. Do not fill its intentionally empty lower/large area with invented widgets.

#### P3.2.1 Dashboard shell

Implement page geometry and the top widget-cluster layout placeholder only.

Commit:

```text
p3(dashboard): add mockup-locked dashboard shell
```

#### P3.2.2 Avatar

When Dashboard is active, the Navigation visual origin becomes a circular avatar.

Clicking the avatar starts the avatar selection/change flow.

User avatar data lives under:

```text
~/.local/share/hakuspace/user/
```

Inspect existing project conventions before choosing the exact persisted filename; document it once chosen.

Runtime checks:

```text
missing avatar
valid avatar
replacement
non-square source
reload/restart
broken source fallback
```

Commit:

```text
p3(dashboard): add persistent dashboard avatar
```

#### P3.2.3 Clock card

Reuse existing clock data/service rather than adding a second polling path.

Commit:

```text
p3(dashboard): add clock card
```

#### P3.2.4 MPRIS card

Contains:

- media metadata;
- thumbnail/artwork;
- playback controls;
- bounded text slots.

Metadata length or artwork availability must not resize the card unexpectedly.

Commit:

```text
p3(dashboard): add mpris control card
```

#### P3.2.5 Calendar card

Contains calendar + month navigation. Month changes must not change outer card geometry.

Commit:

```text
p3(dashboard): add calendar card
```

#### P3.2.6 Monitor card

Display the mockup-defined categories exactly:

```text
ROM
RAM
CPU
GPU
```

Prefer existing shared services / low-cost sources. Do not introduce needless high-frequency polling.

Commit:

```text
p3(dashboard): add monitor information card
```

#### P3.2.7 Dashboard integration

Only after all cards function:

- normalize radii;
- normalize gaps;
- verify avatar/card spacing;
- verify 1.0x and fractional scale;
- ensure reserved Dashboard space remains empty.

Commit:

```text
p3(dashboard): finalize mockup layout
```

---

### P3.3 — Sidebar

Reference: `sidebar.png`.

Sidebar is a left-edge expansion reached from the Navigation Sidebar sector.

#### P3.3.1 Hover handoff

Required pointer state:

```text
Navigation open
→ pointer enters Sidebar sector
→ Sidebar expands immediately
→ pointer travels through an invisible transition bridge
→ Sidebar stays open while pointer is in sector ∪ bridge ∪ Sidebar
→ close only after leaving that union
```

Do not add a noticeable artificial hover delay.

Commit:

```text
p3(sidebar): add stable hover handoff
```

#### P3.3.2 Visual

Requirements:

- attached to the left RoundedScreen edge;
- elongated rounded lobe rather than generic drawer;
- option controls are circular dots;
- plus action is circular.

The mockup specifies shape, not the meaning of each dot.

Commit:

```text
p3(sidebar): implement mockup visual
```

#### P3.3.3 Actions

Wire only actions already specified elsewhere. Unknown dot/plus semantics remain explicit stubs/disabled states rather than guessed product behavior.

Commit only if real actions are wired:

```text
p3(sidebar): wire specified sidebar actions
```

---

### P3.4 — Settings stub

Reference: `setting.png`.

Settings is intentionally a **stub during P3**.

Implement only:

- centered inner Settings surface;
- stable/equal radius family;
- `Setting` header/control;
- approved stub text such as `still working rn...`.

Do not build a theme editor, monitor settings, daemon settings, or persistence framework here.

Commit:

```text
p3(settings): add hikai settings stub
```

---

### P3.5 — HakuMenu shell

Reference: `hakumenu.png`.

HakuMenu is a distinct top-center shell surface. It is not Navigation.

Use the approved center interaction without redesigning the base TopBar-center silhouette.

#### P3.5.1 Lifecycle

States:

```text
closed
general
drun
theme
```

Requirements:

- continuous pointer handoff between center trigger and menu so hover does not flicker;
- click/keyboard access remains possible;
- Escape closes;
- outside click closes when applicable;
- opening another large panel closes/owns state consistently;
- correct output ownership.

Commit:

```text
p3(hakumenu): add center-triggered lifecycle
```

#### P3.5.2 Stable physical geometry

Invariant:

```text
menuCenterX = outputWidth / 2
menuHeight  = stable across tabs
```

Do not derive menu position from changing MPRIS title width.

Vertical origin is frame-derived. HakuMenu remains physically centered while its width may morph by tab: General uses the approved compact width (95% of the standard HakuMenu width; currently 38% of output versus 40% for Drun/Theme). The width transition uses the dedicated HakuMenu resize motion, not the bouncy open curve. Use one radius family for outer menu, tab strip, list area and Theme state area.

Commit:

```text
p3(hakumenu): lock centered equal-radius geometry
```

#### P3.5.3 Three tabs

Exactly:

```text
General
Drun
Theme
```

Commit shell/tab structure before tab content:

```text
p3(hakumenu): add general drun theme tabs
```

#### P3.5.4 Shared interactive motion foundation

Hikai interactive controls must not switch visible hover/press/selection/focus state in a single frame. Establish the shared motion primitives before expanding P3 into more button-heavy surfaces.

Shared layer:

```text
HAnimation button motion tokens
components/motion/ButtonMotion.qml
components/motion/MorphButton.qml
components/motion/MorphIconButton.qml
components/motion/SelectionPill.qml
```

Rules:

- hover is quick and restrained;
- press compresses slightly and releases softly;
- selection/focus use dedicated non-shell curves;
- HakuMenu's bouncy open curve is not reused for ordinary buttons;
- tab switching uses one moving selection pill rather than three instant active backgrounds;
- list-row selection/hover morphs inside stable row bounds;
- search focus/hover morphs without resizing the field;
- interaction motion must not alter implicit layout size or push neighboring controls.

Initial migration scope:

```text
HakuMenu tabs/search/General rows/Drun rows
Tray menu rows/back action
Notification dismiss/DND/Clear/close buttons
```

Commits may be split between the primitive library and migrations, but all new P3 interactive controls should reuse this layer rather than duplicating ad-hoc `Behavior` blocks.

Suggested commits:

```text
p3(motion): add shared button morph primitives
p3(motion): migrate hakumenu tray and notifications
```

---

### P3.6 — HakuMenu General

#### P3.6.1 Audit `hm_general.sh`

Before binding UI, document its actual:

- output format;
- fields;
- order;
- empty/error behavior;
- command cost.

Do not invent data fields.

If the script needs a small stable output contract, commit that change separately:

```text
p3(hakumenu): stabilize hm_general data contract
```

#### P3.6.2 General model

Separate parsing/model logic from rendering.

Commit:

```text
p3(hakumenu): add general data model
```

#### P3.6.3 General UI

Render the parsed model in the HakuMenu main list region.

Commit:

```text
p3(hakumenu): render general list
```

---

### P3.7 — HakuMenu Drun

Drun is the Hikai-native presentation replacing the interaction equivalent of `rofi -show drun`.

#### P3.7.1 Application model

Requirements:

- application list;
- search/filter;
- stable ordering;
- icon fallback;
- action logic separated from delegate rendering.

Commit:

```text
p3(hakumenu): add drun application model
```

#### P3.7.2 Interaction

Requirements:

- type to filter;
- keyboard navigation;
- Enter launches selected app;
- pointer selection works;
- launch closes HakuMenu cleanly;
- Escape obeys the HakuMenu lifecycle.

Commit:

```text
p3(hakumenu): add drun interaction
```

#### P3.7.3 Hikai launcher routing

Route the Hikai launcher facade/IPC into HakuMenu Drun. Classic remains unchanged.

Commit:

```text
p3(launcher): route hikai launcher to hakumenu drun
```

---

### P3.8 — HakuMenu Theme stub

Theme remains a stub in this P3 revision.

When Theme is active:

```text
main list region + narrow right state region
```

For General/Drun the right state region is hidden. Physical center X and height stay fixed; width follows the approved General-compact versus Drun/Theme-standard morph.

Commits:

```text
p3(hakumenu): add theme state-region layout
p3(hakumenu): mark theme tab as stub
```

Do not build the real theme editor in this milestone.

---

### P3.9 — Wallpaper carousel

Reference: `wallpaper-change.png`.

This supersedes the previous full-width Flare / dual-front Wallpaper plan.

#### P3.9.1 Model audit

Document current:

- wallpaper discovery;
- image/video support;
- selected/current state;
- apply action;
- thumbnail path;
- monitor/output semantics.

No visual rewrite in the audit step.

#### P3.9.2 Fixed center selection slot

The selected wallpaper occupies a stable physical center slot and does not drift while thumbnails load or aspect ratios differ.

Commit:

```text
p3(wallpaper): add fixed center selection slot
```

#### P3.9.3 Stacked side carousel

Implement overlapping/stacked side items around the center selection.

**No large generic panel background** behind the carousel.

Commit:

```text
p3(wallpaper): add stacked side carousel
```

#### P3.9.4 Navigation

One source of truth:

```text
selectedIndex
```

Required inputs:

```text
Left
Right
mouse wheel
```

Item placement derives from `index - selectedIndex`.

Commit:

```text
p3(wallpaper): add carousel navigation
```

#### P3.9.5 Apply

```text
Enter → apply selected wallpaper
```

Keep shell-side wallpaper execution in the existing action/service boundary.

Commit:

```text
p3(wallpaper): apply selected item on enter
```

#### P3.9.6 Performance

For large directories:

- bounded/lazy thumbnail work;
- stable placeholder;
- selected index survives thumbnail loading;
- no unbounded simultaneous decode/preview workload.

Commit:

```text
p3(wallpaper): harden carousel thumbnail loading
```

---

### P3.10 — Existing shell polish retained

These surfaces are not redesigned by the seven new mockups; they are aligned to the RoundedScreen/frame contract.

#### P3.10.1 Tooltip

```text
p3(anchor): attach tooltips to rounded frame
```

#### P3.10.2 Tray

```text
p3(anchor): attach tray menu to rounded frame
```

Tray menu rows, Back, checkbox/radio state and press/hover feedback use the shared Hikai button-motion primitives; do not restore instant row colour switching.

#### P3.10.3 Notification popup

Preserve the native popup model; attach/polish as a borderless frame-related Flare toast.

```text
p3(anchor): attach notification popup to rounded frame
```

#### P3.10.4 Notification Center

Prefer two commits if geometry and visual polish both change:

```text
p3(anchor): attach notification center to rounded frame
p3(notifications): polish center spacing and clear action
```

Visual requirements:

- roomier outer/header spacing;
- taller history viewport;
- `Clear` accent-filled with black text;
- DND/Clear/close/dismiss interaction states use shared button motion instead of instant colour changes;
- hover can increase label size without reallocating the header.

#### P3.10.5 Level OSD

Separate attachment from layout polish:

```text
p3(anchor): attach level osd to rounded frame
p3(osd): stabilize compact centered layout
```

Requirements:

- compact padding;
- physical X center does not move between `0%` and `100%`;
- fixed percentage slot;
- volume and brightness share the same layout model.

---

### P3.11 — Remaining native migration

Because Drun is now represented inside HakuMenu, do not build a second unrelated launcher panel.

Remaining native migrations are handled one feature/caller family at a time, for example:

```text
Power
Clipboard
remaining direct Hikai rofi callers
```

For each:

```text
audit
→ implement
→ runtime verify
→ confirm Classic unchanged
→ commit
```

Do not globally delete rofi if Classic still legitimately uses it.

---

### P3.12 — Runtime verification

Run final matrices on **committed code only**.

Core surface matrix:

```text
Navigation
Dashboard
avatar replace/reload
Sidebar hover handoff
Settings stub
HakuMenu General
HakuMenu Drun
HakuMenu Theme
Wallpaper carousel
Notification popup
Notification Center
OSD
Tray
tooltips
```

Lifecycle where applicable:

```text
open
close
reopen
Escape
outside click
switch directly to another large surface
reload Quickshell
```

WM matrix:

```text
Hyprland
Niri
MangoWM
```

Classic regression:

```text
Classic startup
Classic launcher
Classic notifications
Classic → Hikai → Classic
```

Scale:

```text
1.0x
at least one fractional scale
```

Commit compositor-specific fixes only when the defect is reproduced. Do not leak compositor-specific workarounds into shared UI code without evidence.

---

### P3.13 — Cleanup and docs

Remove/disable temporary:

- debug outlines/axes;
- geometry probes;
- experimental feature flags;
- abandoned mockup variants;
- dead imports/properties/logging.

Commit:

```text
p3(cleanup): remove temporary diagnostics
```

Then synchronize canonical docs:

```text
HAKUSPACE_QUICKSHELL_PLAN.md
QUICKSHELL_STYLE.md
QUICKSHELL_TESTING.md
P3 status/report
```

Commit:

```text
docs(p3): sync mockup-locked implementation
```

---

### P3 visual-review gate

Use only:

```text
PASS
METRIC_TUNE_ONLY
TOPOLOGY_WRONG
FUNCTIONAL_FAIL
```

Rules:

- `PASS` → commit immediately;
- `METRIC_TUNE_ONLY` → freeze topology and tune at most 3 metrics in the next pass;
- `TOPOLOGY_WRONG` → stop implementation and revise the local component plan before more editing;
- `FUNCTIONAL_FAIL` → fix behavior before visual polish.

If two consecutive metric-only rounds do not converge, stop tuning and revise the geometry model. Do not continue open-ended visual trial-and-error.

---

### P3 acceptance

P3 is complete only when:

- stable fallback TopBar center is retained; cancelled collar work is absent;
- RoundedScreen is continuous and supplies shared frame bounds;
- Navigation has Dashboard / Sidebar / Settings;
- Dashboard has avatar, Clock, MPRIS, Calendar, ROM/RAM/CPU/GPU cards and leaves unspecified space empty;
- avatar persists under the HakuSpace user-data directory;
- Sidebar opens immediately from Navigation hover without flicker and uses circular controls;
- Settings is only the approved stub;
- HakuMenu is distinct from Navigation, physically centered with stable height and the approved tab-width morph;
- HakuMenu General uses the real `hm_general.sh` contract;
- HakuMenu Drun is the native Hikai launcher route;
- HakuMenu Theme remains a stub with its right state region;
- Wallpaper is the approved center-selected stacked carousel, with no large panel background;
- wheel/arrows move Wallpaper selection and Enter applies it;
- notification/tray/tooltip/OSD geometry follows the frame contract;
- OSD remains centered from `0%` to `100%`;
- large surfaces cannot create stale/duplicate ownership;
- Hyprland, Niri and MangoWM smoke tests pass;
- Classic regression checks pass;
- 1.0x and fractional-scale checks pass;
- static validation passes;
- canonical docs match committed code;
- final working tree is clean.

Recommended final tag:

```bash
git tag p3-v2-final
```

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

The Hikai project is not complete merely because P3 is complete. Final project-level DONE requires:

- backend switching and crash fallback remain reliable;
- supported WM workspace/window-title contracts are stable;
- shared services avoid duplicate per-screen polling;
- Tray, Notifications, OSD, Tooltip/Flare and RoundedScreen remain stable;
- native Hikai Navigation / Dashboard / Sidebar / HakuMenu / Wallpaper behavior is complete according to the current canonical mockups;
- required launcher/menu/power/clipboard paths no longer depend on forbidden Hikai rofi processes, while Classic is allowed to keep its Classic tooling where planned;
- P4 parity decisions are resolved or explicitly waived;
- packaging, doctor and distro/release verification are complete;
- Hyprland, Niri and MangoWM release matrices pass, with Labwc handled according to its upstream support status;
- Classic regression tests pass;
- canonical user/developer docs match the shipping implementation;
- repository and generated runtime state are free of abandoned debug/experimental paths.

Optional P6 polish must not block release once all required milestones are green.

## 17. Immediate next action

After the repository is reset/fallback to the stable P2 baseline (`a7b6f0e7` or the chosen equivalent clean checkpoint):

1. commit these canonical docs separately;
2. confirm no abandoned P3 center-collar / old Wallpaper dual-front code remains;
3. tag/record the P3 baseline;
4. start **P3.0 RoundedScreen + shared frame foundation**;
5. commit each accepted unit before moving to the next dependency.

Do not begin Dashboard/HakuMenu/Wallpaper in parallel before the underlying frame/ownership contract is accepted and committed.

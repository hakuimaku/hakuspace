# M2.W — Workspaces for 4 WMs (Hyprland, Niri, MangoWM, Labwc)

> Sub-plan of M2 (`HAKUSPACE_QUICKSHELL_PLAN.md` §0, `M2_PLAN.md` §4.1). This is the remaining work **blocking** the completion of M2 before M3 (notifications).
> Written on 2026-10-06, based on the current code (`services/WM/WM.qml`, `components/top/Workspaces.qml`) and probe commands already run on the user's machine (section 1).
> All **VERIFY** items require a probe before that part is implemented. General working rules: §1 of the master plan (green precommit, no regex-patching QML, no hard-coded colors/durations, temp files go in `temp/`).

---

## 0. Goals

One shared `Workspaces` module for all 4 WMs, with:

| Feature | Required | Notes |
|---|---|---|
| Show the real workspace list and update from events (no polling) | ✅ | Mango/Labwc must also be event-driven (`mmsg watch`, ext-workspace) |
| Mark the **focused** workspace (keep the current worm) | ✅ | |
| Distinguish **occupied** / **empty** | ✅ | Labwc: no data means skip occupancy state (see §3.4) |
| **Urgent**: blink | ✅ if the WM provides the data | |
| **Left click → switch to that workspace** | ✅ | Hit-test each cell; do not use the current approximate calculation |
| **Per-cell tooltip**: workspace name (+ window count, focused window, output) | ✅ | Use `HTooltip`/`TooltipManager` (flare), like other modules |
| Hover: expand/highlight the cell, hand cursor | ✅ | |
| Scroll → previous/next workspace (with touchpad overscroll protection) | ✅ | |
| Right click: WM-specific secondary action | Optional | Mango: `toggleview`; Hyprland: special workspace |
| Multi-monitor: each bar shows the workspaces appropriate to its output | ✅ | WM-specific rules in §2.3 |
| Unsupported WM / empty list → compactly hidden (width 0) | ✅ | |

Out of scope: dragging windows between workspaces, renaming workspaces,
overview, and WindowTitle for Niri/Mango/Labwc (deferred to optional step W6).

## 1. Current state (verified on the machine, 2026-10-06)

### 1.1 Versions

| Component | Version | Source |
|---|---|---|
| Quickshell | 0.3.1 (Arch) | `quickshell --version` |
| Hyprland | 0.56.2 (**Lua configuration**) | `pacman -Q hyprland`, `hypr/config/*.lua` |
| Niri | 26.04 | `niri --version` |
| Labwc | 0.20.2 (wlroots 0.20.2) | `labwc --version` |
| MangoWM | `/usr/sbin/mango` and `/usr/sbin/mmsg` exist (no pacman package named `mango`/`mangowc`) | `command -v` |

### 1.2 Available Quickshell modules

- `Quickshell.Hyprland`: `Hyprland.workspaces`, `focusedWorkspace`,
  `toplevels`, `dispatch()`, **`usingLua`**, `monitorFor(screen)`.
  `HyprlandWorkspace` provides: `id, name, active, focused, urgent,
  hasFullscreen, lastIpcObject, monitor, toplevels`, and **`activate()`**.
- **`Quickshell.WindowManager`** (available in 0.3.1, at
  `/usr/lib/qt6/qml/Quickshell/WindowManager/`):
  `WindowManager.windowsets`, `windowsetProjections`, `screenProjection(screen)`;
  `Windowset { id, name, coordinates, active, urgent, shouldDisplay,
  canActivate, canDeactivate, canRemove, projection; activate(), deactivate(),
  remove() }`.
  This is an abstraction over **ext-workspace-v1** → the data source for Labwc
  (and potentially a common fallback). **VERIFY** which WMs are supported
  (§4, W0).
- `mmsg` (Mango IPC): event streams **`mmsg watch all-tags`** /
  `watch tags <monitor>` and the `mmsg get all-tags` query; switch tags with
  `mmsg dispatch view,<n>,0` (matching `mango/bind.conf`:
  `bind=SUPER,1,view,1,0`). The socket uses the `MANGO_INSTANCE_SIGNATURE`
  environment variable.

### 1.3 Bugs in the current code (fixed by this plan)

1. **Hyprland occupancy is always empty:** `WM.qml` uses `w.windows > 0`,
   but `HyprlandWorkspace` has no `windows` property (only
   `lastIpcObject.windows` or `toplevels`). Every dot therefore appears empty.
2. **`activate()` compares `Env.wmName === "hyprland"`** without lowercasing.
   On Hyprland (`XDG_CURRENT_DESKTOP=Hyprland`) click/scroll does nothing
   (Appendix C.1 of the master plan). Hyprland 0.56 also uses Lua
   (`Hyprland.usingLua`), so `dispatch("workspace N")` may differ; use
   `HyprlandWorkspace.activate()`.
3. **Niri uses `idx` as the key:** `idx` is unique only **within one output**,
   so multi-monitor setups collide/jump. Use `id` as the key and `idx` as the
   label.
4. **Niri `occupied` means every workspace** (the code pushes all workspaces
   into `occupied`).
5. **Approximate hit-testing:** one large `MouseArea` plus `getIndexAt()` based
   on the target layout is wrong while the layout is animating.
6. **No tooltip** (`tooltip: ""`).
7. Hyprland special workspaces (`id < 0`) are filtered out, while waybar has
   `show-special: true`.
8. WM detection relies only on `XDG_CURRENT_DESKTOP` (defaulting to
   `"Hyprland"` when empty — Appendix C.8).

## 2. Architecture

### 2.1 Files

```text
services/WM/
├── WM.qml                  singleton facade: select backend, expose common model (§2.2)
├── HyprlandBackend.qml     Quickshell.Hyprland
├── NiriBackend.qml         niri msg -j workspaces + event-stream (+ windows)
├── MangoBackend.qml        mmsg get/watch all-tags
├── ExtBackend.qml          Quickshell.WindowManager (ext-workspace-v1) — Labwc + fallback
└── NullBackend.qml         supported: false
services/WM/qmldir          (if declarations are required; keep WM singleton as it is)
components/top/Workspaces.qml   rewrite rendering: one delegate/cell, MouseArea + per-cell HTooltip
```

`WM.qml` creates a backend with `Loader { sourceComponent: … }` (or
`Component.createObject`) according to detection; **do not** run all 4 WM
implementations in parallel. Backends update the model only; `WM` must not
contain WM-specific logic.

### 2.2 Common data model (every backend must expose exactly this shape)

```js
// WM.workspaces: sorted array, each element:
{
  key:      string,   // globally unique key (e.g. "hypr:3", "niri:17", "mango:DP-1:2", "ext:<id>")
  label:    string,   // short display label when needed ("1", "2", "web")
  name:     string,   // full tooltip name ("Workspace 3", or user-defined name)
  output:   string,   // output name ("DP-1"); "" if the WM does not bind workspaces to outputs
  active:   bool,     // active on its output
  focused:  bool,     // globally focused (at most 1)
  occupied: bool,     // has windows (false when unknown)
  windows:  int,      // window count, -1 when unknown
  focusedTitle: string, // focused window title in this workspace, "" when unknown
  urgent:   bool,
  special:  bool      // Hyprland special / scratchpad
}
WM.supported: bool
WM.backendName: "hyprland" | "niri" | "mango" | "ext" | "none"
WM.caps: { occupied, windowCount, urgent, perOutput, special, secondary }   // bool
WM.activate(key)            // switch to workspace
WM.secondary(key)           // right-click action (Mango toggleview, Hyprland togglespecial); no-op if !caps.secondary
WM.cycle(step, outputName)  // scroll: ±1 in the list visible on that output
WM.workspacesFor(outputName) // filter according to §2.3
```

Keep `WM.activeWindowClass` / `activeWindowTitle` (currently used by
WindowTitle). The Hyprland backend continues to provide them; other backends
leave them empty until W6.

Remove the old `ids/activeId/occupied/urgent` properties after
`Workspaces.qml` switches to the new model (in the same commit; do not keep
both models).

Compare before assignment to avoid unnecessary rebinds/animations; retain the
current `JSON.stringify` approach for the array.

### 2.3 WM detection and multi-monitor rules

Detection order (environment variables are more reliable than
`XDG_CURRENT_DESKTOP`):

| Condition | Backend | `workspacesFor(output)` rule |
|---|---|---|
| `HYPRLAND_INSTANCE_SIGNATURE` exists | Hyprland | All workspaces, matching waybar's current behavior |
| `NIRI_SOCKET` exists | Niri | Only workspaces whose `output` is the bar's output (Niri assigns workspaces per output) |
| `MANGO_INSTANCE_SIGNATURE` exists | Mango | Tags on the bar's output; hide empty, inactive tags (waybar `hide-empty: true`) |
| `LABWC_PID` exists, or `XDG_CURRENT_DESKTOP` contains `labwc` (**VERIFY** the env set by Labwc) | Ext | All windowsets with `shouldDisplay` |
| Otherwise, but `WindowManager.windowsets` is non-empty | Ext (fallback) | Same as above |
| Otherwise | Null | Empty → module hidden |

`TopBar.qml` passes `screenName: root.modelData.name` to `Workspaces`.
Fix Appendix C.1 / C.8 by no longer using `Env.wmName` inside `WM` (use only
the detection result above).

## 3. Backend details

### 3.1 Hyprland (`Quickshell.Hyprland`)

- Source: `Hyprland.workspaces.values` plus `Connections` for `valuesChanged`
  and `focusedWorkspaceChanged`. Each workspace may also require listeners
  for `toplevels`/`urgentChanged`; use an invisible `Instantiator`/`Repeater`
  on `Hyprland.workspaces` for per-object bindings instead of rebuilding
  everything.
- `occupied`/`windows`: `ws.toplevels.values.length` (**VERIFY** that
  `toplevels` is an `ObjectModel` with `.values`); fallback to
  `ws.lastIpcObject.windows`. Call `Hyprland.refreshWorkspaces()` after
  `openwindow`/`closewindow`/`movewindow` events via `Hyprland.rawEvent`.
- `focusedTitle`: `ws.lastIpcObject.lastwindowtitle` (**VERIFY** the JSON key),
  or the focused toplevel in `ws.toplevels`.
- `urgent`: `ws.urgent` (available).
- `special`: `id < 0`; name format `special:<name>` → `label` is the part after
  `special:`; display a separate glyph (copy it from the waybar config if
  available; do not retype it).
- `activate(key)`: `ws.activate()` (Quickshell handles Lua/non-Lua). For
  special workspaces, `secondary` uses `Hyprland.dispatch` to toggle the
  special workspace (**VERIFY** the Lua syntax: `Hyprland.usingLua = true` on
  this machine; if string dispatch fails, use `hyprctl dispatch …` via
  `Process` and record it).
- `caps`: occupied ✅, windowCount ✅, urgent ✅, perOutput ❌ (currently all
  workspaces), special ✅, secondary ✅ (special only).

### 3.2 Niri (`niri msg`)

- Initial state: `niri msg -j workspaces` plus `niri msg -j windows`. Then
  `niri msg -j event-stream` (available; retain the 1 s backoff, increasing
  to a maximum of 10 s).
- Events to handle: `WorkspacesChanged`, `WorkspaceActivated {id, focused}`,
  `WorkspaceActiveWindowChanged`, `WorkspaceUrgencyChanged` (**VERIFY**
  available in 26.04), `WindowsChanged`, `WindowOpenedOrChanged`,
  `WindowClosed`, and `WindowFocusChanged`. Ignore other events.
- Mapping: `key = "niri:" + id`; `label = name || idx`; `output = ws.output`;
  `active = is_active`; `focused = is_focused`; `urgent = is_urgent`;
  `windows` is the count of windows where `workspace_id === id`;
  `focusedTitle` is the title for `active_window_id`.
- `activate(key)`: `niri msg action focus-workspace <ref>`. **VERIFY**:
  the CLI interprets a number as the **idx on the currently focused output**,
  not the id. Options: call `focus-monitor <output>` first when the workspace
  belongs to another output, then call `focus-workspace <idx>`; or use the
  workspace name when available. Record the conclusion in the report.
- Do not run the two `Process` instances when `backendName !== "niri"`.
- `caps`: occupied ✅, windowCount ✅, urgent ✅ (if VERIFY succeeds),
  perOutput ✅, special ❌, secondary ❌.
- Low-cost bonus: because `windows` and `WindowFocusChanged` are already
  available, provide `activeWindowClass/Title` for Niri so WindowTitle works
  there (only if it does not expand the diff; otherwise defer to W6).

### 3.3 MangoWM (`mmsg`)

- **VERIFY first (run inside a Mango session):** `mmsg get all-tags`,
  `mmsg get all-monitors`, `mmsg watch all-tags | head -5` → determine the
  format (JSON or text) and fields (tag index, `is_active/selected`, client
  count, `urgent`, monitor). Save a sample to `temp/mango_probe.txt` and
  include an excerpt in the report.
- Initial state: `mmsg get all-tags`; stream: `mmsg watch all-tags` through
  `SplitParser` (one line / one event — **VERIFY**). On stream loss, use the
  same backoff as Niri.
- Mapping: `key = "mango:" + monitor + ":" + tag`; `label = tag (1..9)`;
  `name = "Tag " + n`; `output = monitor`.
- Display tags with windows **or** the active tag (hide-empty, like waybar).
- `activate`: `mmsg dispatch view,<n>,0` — **VERIFY** this acts on the
  currently focused monitor; if the tag belongs to another monitor, call
  `focusmon` first (function name **VERIFY** in `bind.conf`/Mango docs).
- `secondary` (right click, like waybar `on-click-right: toggle`):
  `mmsg dispatch toggleview,<n>,0` (**VERIFY** the function name).
- `caps`: occupied ✅ (if client count exists), windowCount according to the
  probe, urgent according to the probe, perOutput ✅, special ❌,
  secondary ✅.
- Fallback if `mmsg watch` is unreliable: try `ExtBackend` (if Mango supports
  ext-workspace; see W0). **Do not** use timer polling.

### 3.4 Labwc (`Quickshell.WindowManager`, ext-workspace-v1)

- Labwc 0.20 has workspaces ("desktops") in `rc.xml` (4 by default) and
  supports ext-workspace (waybar classic uses `ext/workspaces` for Labwc).
- Source: `WindowManager.windowsets` (`Windowset` list), filtered by
  `shouldDisplay`. Sort by `coordinates` when available (like waybar
  `sort-by-direction`); otherwise preserve list order.
- Mapping: `key = "ext:" + ws.id`; `label`/`name` = `ws.name` (Labwc sets
  this from `rc.xml`, e.g. "1".."4" or custom names); `active = ws.active`;
  `focused = ws.active`; `urgent = ws.urgent`.
- `occupied`/`windows`: **not provided by the protocol** →
  `caps.occupied = false`, `windows = -1`; render every cell as a dim
  "occupied" state (do not guess). The tooltip shows the name only.
- `activate`: `ws.activate()` when `canActivate`.
- **VERIFY:** `WindowManager.windowsets` actually contains data on Labwc
  0.20.2 (W0). If not, set `supported = false`, hide the module, and record
  the limitation in the docs. There is no CLI alternative (Labwc has no
  workspace IPC; `wlrctl` is not installed).
- `caps`: occupied ❌, windowCount ❌, urgent ✅, perOutput ❌ (W0 checks
  `projection`), special ❌, secondary ❌.

## 4. UI (`components/top/Workspaces.qml`)

Keep the current visual language (dots plus the sliding "worm" for the active
cell, using `HAnimation.spatial*`). Change the following:

1. **Model:** `property var items: WM.workspacesFor(screenName)`;
   `Repeater { model: items.length }` (or use the array as the model). Each
   delegate is a cell `Item` with its own `MouseArea`
   (`hoverEnabled`, `cursorShape: Qt.PointingHandCursor`,
   `acceptedButtons: Left | Right`).
2. **Cell states** (colors from `Theme` only):

   | State | Style |
   |---|---|
   | empty | `Theme.fgMuted`, opacity 0.4 |
   | occupied | `Theme.accent`, opacity 0.6 |
   | unknown (`caps.occupied` false) | `Theme.accent`, opacity 0.5 for every cell |
   | active | `Theme.accent` worm overlaid (preserve the current behavior) |
   | hover | opacity +0.3 and extra width (dot → dot + 8), `HAnimation.effects` |
   | urgent | blink opacity (use the existing `TopModule` `blink` mechanism or a local `SequentialAnimation`), stop when urgency ends |
   | special | 1 px `Theme.accent` border, transparent fill; place after regular workspaces with an extra `gap` |
   | active on another output but not focused (Hyprland) | dim border (optional) |

3. **Per-cell tooltip:** each cell has
   `HTooltip { target: slot; text: … }`, enabled/disabled by
   `containsMouse` (like `SettingsGroup`). Content is multiline and omits
   unavailable data:

   ```text
   <name>                       ← always present (e.g. "Workspace 3", "web", "Tag 2", "special: magic")
   3 windows · <focusedTitle>   ← when caps.windowCount (truncate to 40 characters, "…")
   Output: DP-1                 ← only when there is more than one output
   Urgent                       ← when urgent
   ```

   The tooltip must follow the existing flare/tooltip behavior.
4. **Left click** → `WM.activate(key)`. **Right click** →
   `WM.secondary(key)` when `WM.caps.secondary`.
5. **Scroll:** accumulate `angleDelta.y`; every 120 units is one step, with a
   150 ms cooldown (`HAnimation` has no time token for this → add a token such
   as `HAnimation.scrollCooldown`, or list it as an exception in
   `quickshell_style.md`). Call `WM.cycle(±1, screenName)`; do not wrap around
   (stop at the first/last item), as currently.
6. **Compact hiding:** `visible: WM.supported && items.length > 0`;
   `implicitWidth = 0` when hidden so `Row` leaves no gap.
7. Keep the worm's `retargetTimer`; also retarget when `screenName` or
   `items` changes.

## 5. Steps (each step: green precommit, report according to §15 of the master plan, stop and wait for on-screen user confirmation)

| Step | Content | Who runs probes | Acceptance |
|---|---|---|---|
| **W0** | **Probe.** `temp/ws_probe/shell.qml` (minimal qs config, run `qs -p temp/ws_probe`) prints: `WindowManager.windowsets` (id, name, active, urgent, shouldDisplay, coordinates), `Hyprland.workspaces` (toplevels count, urgent, lastIpcObject), and WM env. Include `temp/ws_probe/probe.sh` for Mango (`mmsg get/watch …`) and Niri (`niri msg -j workspaces/windows`, several event-stream lines). The user runs it in **each WM** and sends back the logs. | User (Mango, Labwc, and Niri require their respective sessions); agent can run Hyprland | A VERIFY conclusion table for every §3 item is recorded in `docs/task/M2_WORKSPACES_PROBE.md` |
| **W1** | `WM.qml` facade + `NullBackend` + `HyprlandBackend` (fix bugs 1, 2, 7, 8); rewrite `Workspaces.qml` (individual cells, tooltip, hover, scroll, special); `TopBar` passes `screenName` | Agent (currently on Hyprland) | Click/scroll switches correctly; occupied and empty dots differ; tooltip shows the correct name + window count; special workspaces appear and toggle; clean `qs.log` |
| **W2** | `NiriBackend` (fix bugs 3, 4; key = id; per-output; urgent; multi-monitor activation) | User tests on Niri | Same as W1 + each monitor shows only its workspaces |
| **W3** | `MangoBackend` based on W0 results | User tests on Mango | Tags appear/hide like waybar (`hide-empty`), left click views, right click toggles view |
| **W4** | `ExtBackend` (Labwc + fallback) | User tests on Labwc | 4 desktops show the correct `rc.xml` names, click switches, active state is correct after keyboard switching |
| **W5** | Docs + cleanup: update `HAKUSPACE_QUICKSHELL_PLAN.md` (§0 M2 table, §9, Appendix C.1/C.8 → already fixed), `quickshell-testing.md` (4-WM checklist), and `M2_PLAN.md` §4.1 | Agent | Green precommit; docs match code |
| W6 *(optional)* | `activeWindowClass/Title` for Niri/Mango/Labwc (WindowTitle is no longer "Hyprland only") | — | — |

Do not merge steps. W2–W4 may change order depending on which WM the user
currently runs.

## 6. Final test checklist (add to `quickshell-testing.md`)

For **each WM**:

1. The bar shows the correct number of workspaces/tags; switching with the
   keyboard moves the worm immediately.
2. Clicking each cell switches correctly; scrolling up/down moves
   previous/next; the touchpad does not jump multiple steps.
3. Hovering each cell shows the correct tooltip name; moving horizontally
   across cells transitions the tooltip smoothly (no flicker or stuck state).
4. Opening/closing a window changes the occupied/empty state (except Labwc).
5. Urgent state (e.g. `notify`/an app requesting attention on another
   workspace) blinks the cell and stops after entering that workspace.
6. With two monitors, §2.3 rules are correct; connecting/disconnecting a
   monitor does not crash.
7. Restart `qs`, then restart WM IPC (for Niri/Mango: kill the
   `niri msg`/`mmsg watch` stream) → it reconnects automatically without a
   hot loop.
8. `qs.log` contains no `TypeError`/`ReferenceError`; idle `qs` CPU is
   approximately 0%.

## 7. Risks / open questions

1. **Mango output format** is unknown → W3 depends entirely on W0.
2. **ext-workspace on Labwc through `Quickshell.WindowManager`** has not been
   probed; without data, Labwc can only hide the module.
3. **Hyprland Lua dispatch:** use `ws.activate()` for workspace switching;
   only `togglespecialworkspace` still depends on the dispatch string.
4. **Niri cross-output activation:** choose the approach after the probe.
5. **Questions for the user (defaults already selected):**
   - Q-W1: Should Hyprland show **all** workspaces on every bar (like waybar),
     or only workspaces on that monitor? *(default: all)*
   - Q-W2: Should Hyprland **special workspaces** be shown? *(default: yes,
     placed last)*
   - Q-W3: Should cells show a **number/label** inside, or remain dots like
     today? *(default: dots only; label in tooltip)*
   - Q-W4: Should Mango hide empty tags (like waybar) or show all 9?
     *(default: hide)*

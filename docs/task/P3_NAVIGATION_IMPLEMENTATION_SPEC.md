# P3 Navigation Implementation Spec

> Status: **DONE / runtime accepted — 2026-10-10**

## Goal

Implement **P3.1 Navigation** first, because Sidebar depends on Navigation's origin, state, hover handoff, and monitor ownership.

This task covers **Navigation only**. Do **not** implement Dashboard, Sidebar body, Settings body, Power, Clipboard, or other later surfaces yet.

Canonical references already in the repo:

- `docs/task/HAKUSPACE_QUICKSHELL_PLAN.md` — P3.1
- `docs/task/P3_DETAILED_ATOMIC_COMMIT_PLAN.md` — N1 / N2
- `docs/task/QUICKSHELL_STYLE.md` — Navigation style contract
- visual reference: `navigation.png` if available in the working context

Final accepted implementation:

- explicit per-screen Navigation logical + visual ownership;
- Logo-triggered radial controller with Dashboard / Sidebar / Settings handoff states;
- `WlrLayer.Overlay`, `ExclusionMode.Ignore`, `exclusiveZone: 0`;
- persistent Flare backing aligned to `RoundedScreen` / `FlareEdges`;
- selected sector uses theme accent, hover uses neutral gray with sector/icon expansion;
- rounded annular sectors with icons instead of text labels;
- Logo morphs into the radial hub and returns to a stable circular footprint on close;
- close lifecycle folds sectors first, then returns the Logo while the Flare retracts into the RoundedScreen seam;
- TopBar Logo keeps its layout slot but is visually hidden while Navigation owns the proxy; non-Logo left modules slide right to clear the radial controller;
- Sidebar handoff contract is exposed and ready for P3 Sidebar implementation.

---

# Scope

Implement these two atomic stages in order:

```text
N1  explicit Navigation lifecycle/state
N2  three-region radial Navigation visual
```

Do not combine Navigation with HakuMenu.

Navigation visible regions are exactly:

```text
Dashboard
Sidebar
Settings
```

Navigation must read visually as **one circular/radial Logo-origin controller**, never as a rectangular popup/menu.

---

# N1 — Explicit Navigation state/lifecycle

## Required state

Add explicit Navigation state to `UiState.qml` rather than overloading the current generic `toggle(panel)` helper.

Required logical states:

```text
closed
open
handoff-dashboard
handoff-sidebar
handoff-settings
```

Keep explicit screen ownership as well, e.g. conceptually:

```text
navigationMode
navigationScreenName
```

Exact property/function names may follow current project conventions, but semantics must remain explicit and inspectable.

## Required operations

Navigation state must support:

- open on a specific screen;
- toggle on the same screen;
- deterministic switch to another screen;
- close;
- close-if-screen;
- begin/cancel handoff for Dashboard / Sidebar / Settings;
- reset state when another mutually-exclusive large panel becomes active.

`UiState.activePanel` remains the one-large-surface ownership authority.

Use one Navigation panel name consistently, e.g. `"navigation"`.

Do not make HakuMenu state depend on Navigation state.

## Logo wiring

`components/top/Logo.qml` must become the Navigation trigger.

Requirements:

- left click Logo toggles Navigation on that TopBar's screen;
- keep existing Logo hover/morph behavior;
- remove/avoid tooltip behavior that conflicts with an open Navigation surface;
- no external script/process is needed;
- do not route Logo click to HakuMenu.

The screen name must come from the owning `TopBar`; do not silently use `Quickshell.screens[0]` for a Logo click on another monitor.

If needed, pass `screenName` explicitly into `Logo.qml` from `TopBar.qml`.

## Panel ownership

Add a dedicated per-screen Navigation surface, likely a new component such as:

```text
components/NavigationPanel.qml
```

and instantiate it from `shell.qml` through `Variants { model: Quickshell.screens ... }`, matching the existing per-screen architecture.

Requirements:

- visible only on the screen owned by Navigation state;
- no duplicate Navigation instance;
- Escape closes;
- focus/input is released after close;
- reload/reopen does not leave stale ownership;
- when another large surface opens, Navigation disappears cleanly through `UiState.activePanel` ownership rules.

Do not make the Navigation surface fullscreen-modal unless the radial controller actually needs that window size. Prefer the smallest reliable layer/input geometry consistent with pointer reach and Wayland behavior.

## N1 acceptance

Pass only if all are true:

1. click Logo → Navigation state opens on that monitor;
2. click same Logo again → closes;
3. Escape → closes;
4. click Logo on monitor B while Navigation belongs to monitor A → ownership moves deterministically to B;
5. HakuMenu state is not modified except by normal one-large-panel ownership;
6. Wallpaper state is not modified except by normal one-large-panel ownership;
7. reload while closed → remains closed;
8. reload after opening → no stale input/focus or duplicate surface;
9. `git diff --check` clean;
10. QML syntax checks pass.

Do not begin N2 until N1 passes runtime.

---

# N2 — Three-region radial visual

## Topology

The visible controller must consist of one radial/circular composition at the Logo origin with three visually legible regions:

```text
Dashboard
Sidebar
Settings
```

The three regions must visually belong to one controller.

Forbidden result:

```text
+------------------+
| Dashboard        |
| Sidebar          |
| Settings         |
+------------------+
```

A rectangular context menu fails N2 even if all actions work.

## Origin / attachment

The Navigation origin must visually attach to the Logo rather than floating at an unrelated coordinate.

Use the existing TopBar/frame geometry conventions where possible. Avoid scattered `Theme.topBarHeight + N` offsets if a stable anchor/geometry value can be passed from the Logo/TopBar owner.

The design must remain stable if:

- font size changes;
- TopBar module widths change;
- screen width changes;
- monitor ownership changes.

## Hitboxes

Visible wedges/regions may have simplified internal hitboxes for reliability.

This is explicitly allowed by the project style contract.

Requirements:

- the visible region and its clickable/hoverable area must not substantially disagree;
- no tiny dead zones between regions;
- no overlapping hitbox that makes one region steal another region's click;
- selected/hovered region must clearly indicate state using current Hikai motion/tokens;
- do not introduce a second button-motion system if `MorphButton` / `ButtonMotion` patterns can be reused conceptually.

## Keyboard

Navigation must have basic keyboard accessibility before Sidebar is built.

Minimum:

```text
Left / Right or Up / Down -> change selected region
Enter / Return            -> activate selected region
Escape                    -> close Navigation
```

Choose one deterministic region order and document it.

Do not implement full Dashboard/Sidebar/Settings content yet. Activation only transitions Navigation to the matching handoff state and exposes a clean signal/state boundary for the next milestone.

## Region activation contract

### Dashboard

Activation must produce:

```text
open -> handoff-dashboard
```

No Dashboard body yet.

### Sidebar

Hover/activation must produce:

```text
open -> handoff-sidebar
```

This state is the key prerequisite for P3.3.

N2 must expose enough geometry/state for Sidebar to later implement this required flow without rewriting Navigation:

```text
Navigation open
→ pointer enters Sidebar region
→ handoff-sidebar
→ future Sidebar body opens immediately
→ pointer can cross region/bridge/sidebar union without flicker
```

For N2, create only the Navigation side of that contract. Do not invent the Sidebar body or dot actions.

### Settings

Activation must produce:

```text
open -> handoff-settings
```

No Settings body yet.

## Animation

Opening/closing should feel native Hikai but stay restrained.

Use existing shared timings/curves where reasonable:

- `HAnimation.fast`
- `HAnimation.normal`
- `HAnimation.shellCurve`
- shared button motion tokens

Avoid a large custom animation subsystem for this controller.

Recommended motion topology:

```text
open:
Logo origin
→ radial controller expands/unfolds
→ region labels/state settle

close:
regions contract toward Logo origin
→ surface fades/withdraws
→ input released
```

The visual must remain readable during animation; do not spin text around the radial controller.

## N2 acceptance

Runtime gate:

1. screenshot clearly reads as one radial/circular controller;
2. Dashboard / Sidebar / Settings are all legible;
3. not a rectangular menu;
4. controller is visually attached to Logo origin;
5. hover/click each region works;
6. keyboard selection + Enter works;
7. Escape closes;
8. rapid open/close/reopen does not duplicate surface;
9. monitor B Logo opens Navigation on monitor B;
10. opening HakuMenu/Wallpaper/Notification/Tray obeys one-large-panel ownership and does not leave stale Navigation input;
11. Sidebar region can enter `handoff-sidebar` without implementing Sidebar body;
12. no flicker caused merely by moving inside the Navigation controller;
13. `git diff --check` clean;
14. QML syntax checks pass;
15. `scripts/precommit_check.sh` passes.

If a screenshot has the right labels/actions but visually looks like a normal popup, classify as:

```text
TOPOLOGY_WRONG
```

Do not metric-tune a rectangular topology into submission; revise the geometry model.

---

# Files expected to be touched

Likely:

```text
src/home/.config/quickshell/hakuspace/services/UiState.qml
src/home/.config/quickshell/hakuspace/components/top/Logo.qml
src/home/.config/quickshell/hakuspace/components/TopBar.qml
src/home/.config/quickshell/hakuspace/components/NavigationPanel.qml        # new
src/home/.config/quickshell/hakuspace/components/navigation/...             # optional focused subcomponents
src/home/.config/quickshell/hakuspace/shell.qml
docs/task/P3_DETAILED_ATOMIC_COMMIT_PLAN.md
```

Touch `Theme.qml` / `HAnimation.qml` only if a genuinely shared token is missing. Prefer local Navigation geometry constants over polluting global theme with one-off values.

Do not modify WM backends for this task.

Do not modify WallpaperCarousel for this task.

Do not refactor Notification/Tray/HakuMenu while implementing Navigation.

---

# Runtime test matrix

Run at minimum:

```text
Case 1  cold reload, Navigation closed
Case 2  Logo click open
Case 3  same Logo click close
Case 4  open -> Escape
Case 5  rapid open/close/reopen
Case 6  hover Dashboard / Sidebar / Settings
Case 7  keyboard region selection + Enter
Case 8  Navigation -> HakuMenu ownership switch
Case 9  Navigation -> Wallpaper ownership switch
Case 10 monitor A -> monitor B ownership transfer
Case 11 shell reload after previous Navigation use
```

For N2 provide at least one screenshot with the whole Logo-origin controller visible.

On Niri/Hyprland/Mango, do not refactor compositor backends as part of a Navigation UI failure. First determine whether the failure is generic Quickshell layer/input ownership or compositor-specific.

---

# Validation commands

Use the repo's existing validators:

```bash
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
git diff --check
scripts/precommit_check.sh
```

Hot reload during runtime work:

```bash
qs -c hakuspace ipc call shell reload
```

No `sed`/regex mass-editing for QML refactors. Make targeted edits and inspect the final diff.

Do not commit unless the user explicitly asks. The current workflow batches the milestone before commit.

---

# Required report back

Return this exact structure:

```text
P3 Navigation report

Baseline HEAD:

N1 state/lifecycle:
- files changed:
- state fields/functions added:
- Logo ownership path:
- monitor ownership result:
- Escape result:
- reload result:
- PASS / FAIL:

N2 radial visual:
- files changed:
- geometry/topology summary:
- Dashboard region:
- Sidebar region:
- Settings region:
- keyboard behavior:
- screenshot path:
- PASS / FAIL:

Sidebar handoff readiness:
- exact state/signal used:
- pointer handoff boundary prepared:
- Sidebar body NOT implemented: yes/no

Regression matrix:
- HakuMenu:
- Wallpaper:
- Tray/Notification ownership:
- TopBar Logo hover:

Validation:
- qml_syntax_check:
- git diff --check:
- precommit_check:

git status --short:

git diff --stat:

Known risks / intentionally deferred:
```

If N1 fails, stop before N2.
If N2 topology is wrong, stop and report `TOPOLOGY_WRONG` rather than building Sidebar on top of it.

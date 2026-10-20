# HIKAI TASKBAR / DOCKBAR SEPARATION PLAN

## 0. Goal

Refactor Hikai chrome so that **Taskbar** and **Dockbar** are two different features with different responsibilities.

Current architecture:

```text
taskbar_manual_state
        +
dock.style = dock / bar
        ↓
one DockBar component changes presentation
```

This model must be removed.

Target architecture:

```text
Taskbar Mode
    ≠
Dockbar Feature
```

They may share app models, pins, icon rendering and visual primitives internally, but they must no longer share one enable/state semantic.

---

# 1. Final UX contract

There are exactly three meaningful Hikai chrome states.

## State A — Taskbar Mode ON

```text
TOP
(no TopBar)
(no HakuMenu edge trigger)

                    Desktop

┌──────────────────── TASKBAR ────────────────────┐
│ status left │ apps centered │ status right     │
└─────────────────────────────────────────────────┘
BOTTOM
```

Contract:

```text
Taskbar:
ON

TopBar:
OFF

Dockbar:
not rendered

Taskbar width:
full screen

Taskbar visibility:
always visible

Taskbar exclusive zone:
always ON

Top-edge HakuMenu hover:
OFF

Taskbar App Menu:
bottomFlare
```

Taskbar is conceptually similar to the Windows taskbar:

```text
it is the shell topology,
not a Dock style.
```

---

# 2. State B — TopBar + Dockbar ON

```text
TOP
┌──────────────────── TopBar ─────────────────────┐
│ modules...                                      │
└─────────────────────────────────────────────────┘

          ← top-edge HakuMenu hover trigger →

                    Desktop

                 ┌─ Dockbar ─┐
                 │ app icons │
                 └───────────┘
BOTTOM
```

Contract:

```text
Taskbar:
OFF

TopBar:
ON

Dockbar:
ON

Top-edge HakuMenu hover:
ON

edge HakuMenu style:
topFlare

Dockbar App Menu click:
dockFloating
```

Dockbar keeps its existing compact behavior:

```text
autohide / always
optional exclusive space
hover lift
hover enlargement
floating HakuMenu
```

---

# 3. State C — TopBar + Dockbar OFF

```text
TOP
┌──────────────────── TopBar ─────────────────────┐
│ modules...                                      │
└─────────────────────────────────────────────────┘

          ← top-edge HakuMenu hover trigger →

                    Desktop

(no Dockbar)
BOTTOM
```

Contract:

```text
Taskbar:
OFF

TopBar:
ON

Dockbar:
OFF

Top-edge HakuMenu hover:
ON

edge HakuMenu:
topFlare
```

This state must remain fully functional.

Turning Dockbar OFF must not remove:

```text
TopBar
HakuMenu
Navigation
Notifications
Tooltip
OSD
etc.
```

This directly fixes the current problem where disabling the shared "taskbar" feature removes too much shell behavior.

---

# 4. Canonical state model

## 4.1 Persisted states

Keep:

```text
taskbar_manual_state
```

but redefine/document its Hikai meaning as:

```text
Taskbar Mode enabled
```

Add:

```text
dockbar_manual_state
```

meaning:

```text
compact Dockbar requested
```

Do not use one file for both.

---

# 5. Requested state vs effective state

This distinction is important.

Example:

```text
dockbar_manual_state = 1
taskbar_manual_state = 1
```

Persisted Dockbar preference is still ON, but Taskbar Mode owns the shell.

Therefore:

```text
dockbarRequested = true
dockbarActive = false
```

When Taskbar Mode becomes OFF again:

```text
dockbarActive = true
```

Do NOT automatically erase:

```text
dockbar_manual_state
```

when Taskbar is enabled.

This preserves the independence of the two features.

---

# 6. Rewrite ChromeLayout

Current concepts such as:

```text
fullBarRequested
unifiedBottomBar
hakuMenuPresentation
```

come from the old "Dock style" architecture.

Replace the topology with semantics equivalent to:

```qml
readonly property bool taskbarMode:
    AppState.taskbarManualState

readonly property bool topBarMode:
    !taskbarMode

readonly property bool dockbarRequested:
    AppState.dockbarManualState

readonly property bool dockbarActive:
    topBarMode && dockbarRequested

readonly property bool taskbarActive:
    taskbarMode

readonly property bool topStatusBarVisible:
    topBarMode

readonly property bool topEdgeHakuMenuEnabled:
    topBarMode

readonly property bool statusAtBottom:
    taskbarMode

readonly property string statusEdge:
    taskbarMode ? "bottom" : "top"

readonly property string defaultHakuMenuPresentation:
    taskbarMode ? "bottomFlare" : "topFlare"
```

Do not add:

```text
dockbarActive → topBar false
```

Dockbar belongs inside TopBar mode.

---

# 7. Remove the single global HakuMenu presentation concept

This is critical.

Current code effectively assumes:

```text
one shell topology
→ one HakuMenu style
```

That is no longer true.

In TopBar + Dockbar state there are simultaneously two valid HakuMenu presentations:

```text
top edge hover
→ topFlare

Dockbar App Menu click
→ dockFloating
```

Therefore remove the idea that:

```text
ChromeLayout.hakuMenuPresentation
```

always determines the menu.

---

# 8. HakuMenu must resolve by activation SOURCE

Define activation sources.

Recommended:

```text
edge
taskbar
dockbar
default
```

Mapping:

```text
source = edge
    Taskbar Mode OFF
        → topFlare
    Taskbar Mode ON
        → reject / no-op
```

```text
source = taskbar
    Taskbar Mode ON
        → bottomFlare
    otherwise
        → reject / no-op
```

```text
source = dockbar
    Dockbar active
        → dockFloating
    otherwise
        → reject / no-op
```

```text
source = default
    Taskbar Mode ON
        → bottomFlare

    TopBar Mode
        → topFlare
```

---

# 9. Refactor UiState HakuMenu API

Current signature:

```text
openHakuMenu(screenName, mode, style, anchorRect)
```

is misleading because current implementation ignores the supplied `style`.

Fix this architecture.

Preferred API:

```text
openHakuMenu(screenName, mode, source, anchorRect)
toggleHakuMenu(screenName, mode, source, anchorRect)
```

or explicit helpers:

```text
openHakuMenuFromEdge(...)
toggleHakuMenuFromTaskbar(...)
toggleHakuMenuFromDockbar(...)
openHakuMenuDefault(...)
```

Explicit helpers are preferable if they keep QML callers clearer.

Central resolver:

```text
resolveHakuMenuPresentation(source)
```

must be the only place that maps activation source → presentation.

Do not let individual components repeat the state matrix.

---

# 10. Restore HakuMenuTopFlare

The old:

```text
components/hakumenu/HakuMenuTopFlare.qml
```

contained the correct architectural concept for TopBar mode:

```text
4 px top-edge trigger
20% screen width
centered
hover → open HakuMenu
top attached Flare
```

Restore this presentation.

Do NOT blindly restore the old file from HEAD and stop there.

Adapt it to the newer:

```text
FlareHost
FlareSurface
ScreenGeometry
SafeZone
animation
layer topology
```

that Codex already improved during the unified-bottom refactor.

---

# 11. Top edge trigger contract

Top trigger:

```text
enabled iff ChromeLayout.topEdgeHakuMenuEnabled
```

which means:

```text
Taskbar OFF → enabled
Taskbar ON  → disabled
```

It does NOT depend on:

```text
Dockbar ON/OFF
```

This is essential.

The edge HakuMenu belongs to:

```text
TopBar shell mode
```

not Dockbar.

---

# 12. Top edge HakuMenu geometry

Keep the established UX unless runtime testing shows a reason to change it:

```text
triggerHeight ≈ 4px
triggerWidth ≈ 20% screen
centered horizontally
```

Hover:

```text
top edge
    ↓
topFlare
    ↓
menu grows downward
```

Safe zone:

```text
trigger
↓
vertical bridge
↓
Flare body
```

It must work when:

```text
Dockbar OFF
Dockbar autohidden
Dockbar visible
```

identically.

---

# 13. HakuMenuPanel owns all three presentations

Final:

```text
HakuMenuPanel
 ├── HakuMenuTopFlare
 ├── HakuMenuBottomFlare
 └── HakuMenuDockFloating
```

Presentation ownership:

```text
TopFlare
→ TopBar mode edge/default callers

BottomFlare
→ Taskbar mode

DockFloating
→ explicit Dockbar App Menu click only
```

No presentation should steal another presentation's activation.

---

# 14. DockFloating must require Dockbar

Current floating menu can become active merely because:

```text
UiState.hakuMenuStyle == dockFloating
```

Strengthen its condition.

Required:

```text
ChromeLayout.dockbarActive
&&
UiState.hakuMenuStyle === "dockFloating"
```

If Dockbar disappears because Taskbar Mode is enabled:

```text
floating HakuMenu closes
```

It must never exist independently at the bottom of the screen without a Dockbar owner.

---

# 15. BottomFlare must require Taskbar Mode

Keep:

```text
Taskbar App Menu
→ bottomFlare
```

But its availability must now depend directly on:

```text
ChromeLayout.taskbarMode
```

not:

```text
dockStyle == bar
```

No `dock.style` concept should remain.

---

# 16. Default/IPC HakuMenu behavior

Keyboard/IPC/default calls do not come from a Dockbar icon.

Therefore:

## Taskbar Mode

```text
hakumenu.openDefault
launcher.open("drun")
keyboard launcher
→ bottomFlare
```

## TopBar Mode

```text
hakumenu.openDefault
launcher.open("drun")
keyboard launcher
→ topFlare
```

Never:

```text
default call
→ dockFloating
```

DockFloating requires an actual Dockbar source.

---

# 17. Separate Taskbar and Dockbar component ownership

Current `DockBar.qml` handles both:

```text
compact Dock
full unified bar
```

through:

```text
fullWidth
```

This is now the wrong abstraction.

Final shell should expose two explicit owners:

```text
Taskbar.qml
DockBar.qml
```

---

# 18. Taskbar owner

`Taskbar.qml` owns only:

```text
full-width bottom surface
bottom status modules
centered app strip
one fixed exclusive zone
Taskbar App Menu anchor
Taskbar tooltip host / OSD bridge as required
```

Properties:

```text
visible = ChromeLayout.taskbarMode

always visible = true

exclusive = true

width = output width

bottom inset = 0
```

It must NOT know about:

```text
autohide
Dockbar visibility setting
Dockbar exclusive preference
Dockbar floating menu lease
```

---

# 19. DockBar owner

`DockBar.qml` becomes compact-only.

It owns:

```text
compact background
autohide trigger
always/autohide preference
optional exclusive reservation
Dockbar floating App Menu
Dock hover envelope
```

Its enable condition:

```text
ChromeLayout.dockbarActive
```

Remove:

```text
fullWidth
unifiedBottomBar
full-bar background branch
bottom status modules
full-width status lane
```

from this component.

---

# 20. Do not duplicate the app implementation

Current DockBar contains substantial logic for:

```text
running apps
pins
reordering
termination
hover magnification
Trash
devices
tooltips
App Menu
```

Do NOT copy the whole implementation into `Taskbar.qml`.

Extract shared app-strip logic.

Recommended structure:

```text
components/appbar/AppBarContent.qml
components/appbar/AppBarController.qml       optional
components/Taskbar.qml
components/DockBar.qml
```

or equivalent.

Hosts should own geometry/layer behavior.

Shared content should own common app semantics.

Example:

```text
Taskbar
   ↓
AppBarContent

DockBar
   ↓
AppBarContent
```

---

# 21. App Menu activation from shared app strip

The shared system "Applications" item must not decide HakuMenu style itself.

Host tells it its source.

Example:

```text
Taskbar host:
source = "taskbar"

Dockbar host:
source = "dockbar"
```

Then:

```text
Applications clicked
→ host emits actual anchor rect
→ UiState.toggleHakuMenu(..., source, anchor)
```

Do not call:

```text
ChromeLayout.hakuMenuPresentation
```

from the app item.

---

# 22. Taskbar always reserves space

Taskbar contract:

```text
visible
→ exclusiveZone = taskbarHeight
```

Always.

Ignore:

```text
ShellSettingsStore.dockVisibilityMode
ShellSettingsStore.dockExclusiveSpace
```

for Taskbar.

Those become Dockbar-only preferences.

---

# 23. Dockbar reservation remains configurable

Dockbar keeps:

```text
visibilityMode:
autohide / always

exclusiveSpace:
false / true
```

Existing behavior should remain.

Example:

```text
Dockbar autohide + exclusive OFF
→ no permanent reservation

Dockbar shown + exclusive ON
→ reserve according to existing policy
```

Do not change this behavior as part of Taskbar split unless an existing runtime bug is exposed.

---

# 24. ScreenGeometry cleanup

Current geometry still uses:

```text
ChromeLayout.unifiedBottomBar
```

Replace with explicit Taskbar topology.

Semantic status attachment:

```text
bottomAttached = ChromeLayout.taskbarMode
```

Thus:

```text
Taskbar Mode:
status surfaces attach to bottom

TopBar Mode:
status surfaces attach to top
```

Dockbar does NOT change status attachment.

This is a major simplification.

---

# 25. Geometry naming

Prefer gradually moving generic concepts away from `dockHeight`.

Recommended:

```text
appBarHeight
taskbarHeight
dockbarHeight
```

They may currently be equal.

If they intentionally use the same formula:

```text
taskbarHeight = appBarHeight
dockbarHeight = appBarHeight
```

that's fine.

But do not make geometry imply that Taskbar is a Dock style.

Compatibility aliases may be retained temporarily.

---

# 26. Reservation state

Separate:

```text
Taskbar reservation
```

from:

```text
Dockbar reservation
```

Taskbar:

```text
Taskbar Mode
→ fixed bottom reservation
```

Dockbar:

```text
Dockbar active
+
current visibility/exclusive policy
→ optional reservation
```

Do not use one:

```text
shownDocks
```

registry to represent both semantic features.

---

# 27. New Dockbar state backend

Add a dedicated public control path.

Suggested:

```text
src/core/backend/desktop/dockbar_ctl.sh
src/core/facade/dockbar_manager.sh
```

CLI:

```text
dockbar_manager.sh --status
dockbar_manager.sh --toggle
dockbar_manager.sh --enable
dockbar_manager.sh --disable
```

State:

```text
$STATE_DIR/dockbar_manual_state
```

This controller does not launch Waybar.

Hikai Dockbar is native Quickshell state.

---

# 28. Taskbar controller meaning

Keep existing:

```text
taskbar_manager.sh
taskbar_ctl.sh
taskbar_manual_state
```

for compatibility.

In Hikai:

```text
Taskbar toggle
→ Taskbar Mode
```

In Classic:

preserve existing Classic Taskbar behavior.

Do not break Classic because Hikai semantics changed.

---

# 29. State transition behavior

## Turn Taskbar ON

Before topology handoff:

```text
dismiss tooltip
close tray menu
close notification center
close HakuMenu
close Navigation/handoff transient if necessary
```

Then:

```text
TopBar hides
Dockbar effective state becomes false
top edge HakuMenu trigger unmaps
Taskbar maps
bottom exclusive zone appears
```

Do NOT change:

```text
dockbar_manual_state
```

---

# 30. Turn Taskbar OFF

```text
Taskbar unmaps
bottom Taskbar zone releases
TopBar maps
top reservation maps
top-edge HakuMenu trigger becomes active
```

Then:

```text
if dockbar_manual_state == 1
    Dockbar becomes active
else
    no Dockbar
```

No shell reload required.

---

# 31. Remove Dock "Style"

Current setting:

```text
dock.style = dock / bar
```

must disappear.

There is no longer such thing as:

```text
Dock style = Full bar
```

Taskbar is its own feature.

---

# 32. Settings schema migration

Current schema is version 5.

Recommended:

```text
version 6
```

Remove:

```text
dock.style
```

Keep the remaining `dock` section as compact Dockbar / shared app-strip preferences:

```text
dock:
    visibilityMode
    exclusiveSpace
    iconSize
    hoverLift
    hoverScale
    showTrash
    showDevices
```

Do NOT add Taskbar:

```text
visibility
exclusiveSpace
style
```

because those are fixed by design.

---

# 33. Existing v5 migration

Need preserve users of the current in-development model.

Suggested mapping:

## Old

```text
taskbar_manual_state = 1
dock.style = "bar"
```

→

```text
taskbar_manual_state = 1
dockbar_manual_state = 0
```

## Old

```text
taskbar_manual_state = 1
dock.style = "dock"
```

→

```text
taskbar_manual_state = 0
dockbar_manual_state = 1
```

## Old

```text
taskbar_manual_state = 0
```

→

```text
taskbar_manual_state = 0
dockbar_manual_state = 0
```

Then remove `dock.style` while keeping all other Dock preferences.

Migration must be idempotent.

Use a migration marker/version so a later restart cannot reinterpret already-migrated states.

---

# 34. Migration ownership

Do not make QML mutate filesystem state for migration.

Use a backend migration command.

Possible:

```text
hikai_chrome_state_ctl.py migrate
```

or equivalent.

Run it before Quickshell startup from both:

```text
session_start.sh --early

and

haku_backend.sh set hikai
```

before `qs_supervisor.sh` starts.

If Codex finds a better existing startup hook, reuse it.

The important requirement:

```text
state split happens before AppState begins watching the files
```

---

# 35. Shell Settings UI

Remove:

```text
Style
[ Dock | Full bar ]
```

entirely.

Do not replace it with another style selector.

---

# 36. Reorganize Shell Settings

Suggested visual organization:

## App Bar

Shared visual preferences:

```text
Icon size
Hover lift
Hover enlargement
Trash
Mounted devices
```

These may apply to both Taskbar and Dockbar.

## Dockbar

Dockbar-only behavior:

```text
Visibility
Auto Hide / Always

Reserve space
Off / On
```

Hint:

```text
Dockbar is available only while Taskbar Mode is off.
```

## Top Bar

Keep current TopBar module preferences.

They remain stored while Taskbar Mode is active and return when TopBar mode resumes.

---

# 37. Do not add a Taskbar style setting

Taskbar has one design:

```text
full width
bottom
always visible
exclusive
unified status modules
```

No:

```text
compact Taskbar
autohide Taskbar
non-exclusive Taskbar
```

through the Dock settings UI.

That would recreate the architecture being removed.

---

# 38. HakuMenu Theme page

Current native Theme list has one entry:

```text
Taskbar
```

It must expose separate features.

Final entries:

```text
Taskbar Mode
Dockbar
```

with separate icons/labels if desired.

---

# 39. Theme Taskbar action

```text
Taskbar Mode
```

state:

```text
taskbar_manual_state
```

action:

```text
taskbar_manager.sh --toggle
```

Always available in Hikai.

---

# 40. Theme Dockbar action

```text
Dockbar
```

state:

```text
dockbar_manual_state
```

action:

```text
dockbar_manager.sh --toggle
```

Availability:

```text
Taskbar Mode OFF
```

When Taskbar Mode ON, visually communicate:

```text
Dockbar requires TopBar mode
```

Do not silently toggle it while hidden if the native UI can prevent that.

---

# 41. ThemeList should stop treating both as generic raw-file rows

Because Hikai QML already imports:

```text
AppState
ChromeLayout
```

prefer using authoritative native state for these two rows.

At minimum expose:

```text
available
enabled
```

separately.

Do not infer Dockbar state from:

```text
dock.style
```

after migration.

---

# 42. hm_theme.sh

Native ThemeList currently dispatches its actions through:

```text
hm_theme.sh
```

Add distinct action routing:

```text
*"Taskbar Mode"*)
    taskbar_manager.sh --toggle
```

```text
*"Dockbar"*)
    dockbar_manager.sh --toggle
```

Keep Classic behavior compatible.

If the no-argument Classic/Rofi list should not expose a native-only Dockbar, gate that row based on active backend.

Do not make Classic try to start a Hikai Dockbar.

---

# 43. Sidebar Quick Actions

Current Quick Actions has:

```text
Taskbar
```

Change to separate:

```text
Taskbar
Dockbar
```

or preferably:

```text
Taskbar Mode
Dockbar
```

---

# 44. quick_actions_ctl.py

Add:

```text
dockbar
→ dockbar_manager.sh
```

Taskbar remains:

```text
taskbar
→ taskbar_manager.sh
```

Do not map both keys to the same script.

---

# 45. Dockbar availability in Quick Actions

While Taskbar Mode is active:

```text
Dockbar.available = false
```

because Dockbar cannot be active in this topology.

Its persisted preference does NOT need to be erased.

When Taskbar Mode becomes OFF:

```text
Dockbar.available = true
```

and its state can be read normally.

---

# 46. Quick Actions response may need richer state

If useful, extend from:

```json
{
  "available": true,
  "enabled": true
}
```

to something like:

```json
{
  "available": false,
  "enabled": true,
  "effective": false,
  "reason": "taskbar-mode"
}
```

But only do this if UI needs it.

Do not over-generalize every Quick Action unnecessarily.

Minimum acceptable behavior:

```text
Dockbar button disabled while Taskbar Mode active
```

with clear visual state.

---

# 47. Sidebar grid must become dynamic

Current `SidebarQuickActions.qml` assumes exactly:

```text
5 columns × 2 rows = 10 actions
```

Adding Dockbar creates 11 actions.

Fix:

```text
columnCount
rowCount = ceil(actionCount / columnCount)
```

Delegate height:

```text
(root.height - totalVerticalSpacing) / rowCount
```

Do not leave:

```text
height = (root.height - 8) / 2
```

hardcoded.

---

# 48. Keyboard navigation must also become dynamic

Current logic hardcodes `5`.

Replace with:

```text
columnCount
```

for:

```text
Left
Right
Up
Down
```

and correctly clamp incomplete final rows.

Tests must include:

```text
last action in an incomplete row
```

so Down/Right do not move to an invalid index.

---

# 49. Taskbar / Dockbar HakuMenu App Menu behavior

This matrix is mandatory.

| Source | Taskbar Mode | Dockbar active | Result |
|---|---:|---:|---|
| Top edge hover | OFF | OFF | `topFlare` |
| Top edge hover | OFF | ON | `topFlare` |
| Top edge hover | ON | n/a | nothing |
| Dockbar App Menu | OFF | ON | `dockFloating` |
| Taskbar App Menu | ON | false | `bottomFlare` |
| IPC/default | OFF | any | `topFlare` |
| IPC/default | ON | false | `bottomFlare` |

There must be no other automatic presentation mapping.

---

# 50. Important interaction rule

TopBar mode with Dockbar ON simultaneously supports:

```text
hover screen top
→ topFlare
```

and:

```text
click Dockbar Applications icon
→ dockFloating
```

This is intentional.

Do not make one presentation disable the existence of the other.

Only one can be `UiState.activePanel` at a time.

Opening one should close/replace the currently active HakuMenu cleanly.

---

# 51. RoundedScreen

Taskbar Mode:

```text
bottom rounded frame terminates above Taskbar
```

TopBar Mode:

```text
frame returns to physical bottom
```

Dockbar must NOT affect the primary frame geometry merely because it exists.

Its optional exclusive zone is separate from the permanent screen frame.

Audit current use of:

```text
ChromeLayout.unifiedBottomBar
```

and replace with:

```text
ChromeLayout.taskbarMode
```

where the meaning is really Taskbar topology.

---

# 52. Notification / Navigation / OSD geometry

These already became edge-aware in the previous refactor.

Do not undo that work.

Simply redefine:

```text
bottomAttached
```

as:

```text
Taskbar Mode
```

instead of:

```text
Dock full style
```

Therefore:

## Taskbar Mode

```text
Notification Center upward
Popup bottom stack
Navigation from bottom
OSD above Taskbar
Tooltip upward
```

## TopBar Mode

regardless of Dockbar:

```text
Notification Center downward
Popup top stack
Navigation from top
OSD below TopBar
Tooltip downward
```

Dockbar has no effect on status-surface attachment.

---

# 53. Transient cleanup on Taskbar topology switch

Current `UiState` already closes transient surfaces when unified-bottom state changes.

Retarget this to:

```text
ChromeLayout.taskbarModeChanged
```

Close:

```text
Tooltip
Tray menu
Notification Center
HakuMenu
Navigation
```

before/while transferring chrome ownership.

A Dockbar ON/OFF toggle alone should NOT close unrelated TopBar status surfaces unless necessary.

---

# 54. Do not tie edge HakuMenu to Dockbar lifetime

This is a regression trap.

Wrong:

```text
if Dockbar enabled
    create HakuMenu trigger
```

Correct:

```text
if TopBar Mode
    create top-edge trigger
```

Even this state must work:

```text
Taskbar OFF
Dockbar OFF
```

with:

```text
TopBar
+
top-edge HakuMenu
```

---

# 55. Tests — canonical topology matrix

Create/update a harness covering:

## A

```text
Taskbar OFF
Dockbar OFF
```

Expect:

```text
TopBar visible
Taskbar absent
Dockbar absent
top edge HakuMenu trigger active
top reservation present
bottom Taskbar reservation absent
```

## B

```text
Taskbar OFF
Dockbar ON
```

Expect:

```text
TopBar visible
Dockbar active
Taskbar absent
top edge HakuMenu trigger active
```

## C

```text
Taskbar ON
Dockbar preference OFF
```

Expect:

```text
TopBar absent
Taskbar visible
Dockbar absent
top edge HakuMenu trigger absent
bottom exclusive zone present
```

## D

```text
Taskbar ON
dockbar_manual_state = ON
```

Expect:

```text
TopBar absent
Taskbar visible
Dockbar effective false
dockbar preference remains ON
top edge trigger absent
```

Then Taskbar OFF:

```text
TopBar returns
Dockbar automatically returns
top edge trigger returns
```

---

# 56. HakuMenu tests

Add explicit tests for:

```text
TopBar + Dockbar OFF
hover top edge
→ topFlare
```

```text
TopBar + Dockbar ON
hover top edge
→ topFlare
```

```text
TopBar + Dockbar ON
click Dockbar App Menu
→ dockFloating
```

```text
Taskbar Mode
hover top edge
→ nothing
```

```text
Taskbar Mode
click Taskbar App Menu
→ bottomFlare
```

```text
Taskbar Mode
IPC openDefault
→ bottomFlare
```

```text
TopBar Mode
IPC openDefault
→ topFlare
```

---

# 57. Quick Actions tests

Backend status must include independently:

```text
taskbar
dockbar
```

Test:

```text
toggle taskbar
→ only taskbar state changes
```

```text
toggle dockbar
→ only dockbar state changes
```

While Taskbar ON:

```text
Dockbar effective unavailable
```

After Taskbar OFF:

```text
stored Dockbar preference becomes effective again
```

Also test Sidebar keyboard navigation with 11 actions.

---

# 58. ThemeList tests

Verify:

```text
Taskbar Mode row exists
Dockbar row exists
```

Their toggles must invoke different managers.

Taskbar ON:

```text
Dockbar row cannot imply it is an active visible feature
```

Taskbar OFF:

```text
Dockbar row becomes usable
```

Search filtering must find both independently:

```text
"task"
"dock"
```

---

# 59. Settings migration tests

v5:

```json
"dock": {
  "...": "...",
  "style": "bar"
}
```

→ v6 without `style`.

Verify all other values survive exactly:

```text
visibilityMode
exclusiveSpace
iconSize
hoverLift
hoverScale
showTrash
showDevices
```

Also test v1/v2/v3/v4 migrations directly to final v6.

Do not create migration chains that require first persisting v5.

---

# 60. Runtime reservation tests

Use a maximized client.

## TopBar + Dockbar OFF

```text
one top exclusive zone
no permanent bottom Taskbar zone
```

## TopBar + Dockbar ON

```text
top zone
+
Dockbar reservation only according to Dockbar preference
```

## Taskbar Mode

```text
no top zone
exactly one fixed bottom Taskbar zone
```

Never:

```text
top + Taskbar simultaneously
```

Never:

```text
two Taskbar bottom zones
```

---

# 61. Multi-monitor

States are global:

```text
Taskbar Mode
Dockbar requested
```

but surfaces remain per-output.

Verify two monitors:

```text
Taskbar ON
→ Taskbar on each expected output
→ TopBar removed consistently

Taskbar OFF + Dockbar ON
→ TopBar + Dockbar on each expected output
```

HakuMenu must open on the monitor that owns the trigger/app icon.

---

# 62. Existing WIP protection

The current working tree contains the previous unified-bottom implementation and many uncommitted changes.

Do NOT:

```text
git reset
git checkout .
git restore .
```

Do not reimplement the previous work from HEAD.

Treat the working tree as the current baseline.

Before editing:

```bash
git status --short
git diff --check
git diff
```

Inspect each touched file's current diff first.

---

# 63. Implementation order

Codex should execute in this order.

```text
T0  Freeze/audit current working tree

T1  Add Dockbar persisted state + controller

T2  Replace ChromeLayout topology
    Taskbar Mode / TopBar Mode / Dockbar effective

T3  Remove dock.style from runtime logic
    + settings schema migration

T4  Split Taskbar owner from Dockbar owner
    while sharing app logic

T5  Fix ScreenGeometry / reservation semantics

T6  Refactor UiState HakuMenu source resolver

T7  Restore HakuMenuTopFlare + top edge hover

T8  Connect:
    Taskbar App Menu → bottomFlare
    Dockbar App Menu → dockFloating

T9  Update Theme HakuMenu actions

T10 Update Sidebar Quick Actions
    + dynamic grid/navigation

T11 Audit Notification / Navigation / Tooltip / OSD
    against new Taskbar Mode semantic

T12 Update tests/docs/runtime matrix
```

Do not begin with ThemeList or Sidebar UI.

Canonical topology first.

---

# 64. Recommended commit sequence

```text
1. feat(chrome): add independent Dockbar state
2. refactor(chrome): separate Taskbar Mode from Dockbar state
3. refactor(settings): remove Dock full-bar style
4. refactor(appbar): split Taskbar and Dockbar owners
5. refactor(geometry): separate taskbar and dockbar reservations
6. refactor(hakumenu): resolve presentation by activation source
7. feat(hakumenu): restore top-edge flare in TopBar mode
8. feat(hakumenu): bind taskbar and dockbar app-menu presentations
9. feat(theme): expose separate Taskbar and Dockbar actions
10. feat(sidebar): expose separate Taskbar and Dockbar quick actions
11. test(hikai): cover independent chrome topology matrix
12. docs(hikai): document Taskbar Mode and Dockbar contracts
```

---

# 65. Search audit before final

Run:

```bash
rg -n "dockStyle|dock\\.style|fullBarRequested" \
    src/home/.config/quickshell/hakuspace \
    src/core scripts
```

Active runtime code should have no old style-based topology.

Audit:

```bash
rg -n "unifiedBottomBar" \
    src/home/.config/quickshell/hakuspace \
    scripts
```

Prefer no active use after migration.

Audit:

```bash
rg -n "hakuMenuPresentation" \
    src/home/.config/quickshell/hakuspace
```

There must not be one global presentation controlling every caller.

Audit:

```bash
rg -n "taskbar_manual_state|dockbar_manual_state" \
    src scripts
```

Each usage must represent the correct feature.

---

# 66. Regression traps

## Trap 1

Do not rename Dock full-bar into Taskbar while still retaining:

```text
dock.style
```

That only changes labels, not architecture.

---

## Trap 2

Do not make:

```text
Taskbar OFF
```

mean:

```text
all bottom shell functionality OFF
```

Taskbar OFF means:

```text
return to TopBar shell topology
```

---

## Trap 3

Do not make top edge HakuMenu conditional on Dockbar.

It belongs to TopBar Mode.

---

## Trap 4

Do not make Dockbar App Menu choose the current default presentation.

It must explicitly request:

```text
dockFloating
```

---

## Trap 5

Do not make default IPC HakuMenu float merely because Dockbar exists.

Default in TopBar mode is:

```text
topFlare
```

---

## Trap 6

Do not turn Taskbar's exclusive zone into a preference.

It is fixed.

---

## Trap 7

Do not automatically destroy the saved Dockbar preference when entering Taskbar Mode.

Suppress effective rendering only.

---

## Trap 8

Do not copy the current 500-line DockBar implementation into Taskbar.

Extract shared app content/controller.

---

## Trap 9

Adding Dockbar to Sidebar creates 11 Quick Actions.

Do not leave:

```text
5-column / 2-row
```

keyboard and sizing constants untouched.

---

# 67. Definition of DONE

```text
[ ] Taskbar and Dockbar have independent persisted states

[ ] Taskbar Mode is always full-width
[ ] Taskbar Mode is always visible
[ ] Taskbar Mode always reserves its full height
[ ] Taskbar Mode removes TopBar
[ ] Taskbar Mode removes top-edge HakuMenu trigger
[ ] Taskbar App Menu opens bottomFlare

[ ] Taskbar OFF always restores TopBar mode
[ ] TopBar mode works with Dockbar OFF
[ ] TopBar mode works with Dockbar ON
[ ] top-edge hover HakuMenu works with Dockbar OFF
[ ] top-edge hover HakuMenu works with Dockbar ON
[ ] top-edge hover opens topFlare

[ ] Dockbar only renders in TopBar mode
[ ] Dockbar keeps autohide/always preference
[ ] Dockbar keeps optional exclusive-space preference
[ ] Dockbar App Menu opens dockFloating
[ ] Dockbar preference survives entering/leaving Taskbar Mode

[ ] dock.style is removed
[ ] Full bar is no longer described as a Dock style

[ ] HakuMenu default in TopBar mode is topFlare
[ ] HakuMenu default in Taskbar mode is bottomFlare
[ ] dockFloating is only reachable from an active Dockbar source

[ ] Theme HakuMenu has separate Taskbar Mode and Dockbar entries
[ ] Sidebar Quick Actions has separate Taskbar and Dockbar actions
[ ] Sidebar grid and keyboard navigation handle the new action count

[ ] Notification geometry follows Taskbar vs TopBar topology
[ ] Navigation geometry follows Taskbar vs TopBar topology
[ ] Tooltip follows Taskbar vs TopBar topology
[ ] OSD follows Taskbar vs TopBar topology

[ ] no duplicate top/bottom exclusive zones
[ ] multi-monitor works
[ ] live Taskbar toggle works without Quickshell reload
[ ] live Dockbar toggle works without Quickshell reload

[ ] git diff --check passes
[ ] QML syntax passes
[ ] settings migration tests pass
[ ] Quick Actions tests pass
[ ] HakuMenu tests pass
[ ] Dockbar tests pass
[ ] Taskbar topology tests pass
[ ] precommit passes
```

---

# 68. Final architecture rule

After this refactor:

```text
Taskbar
```

means:

```text
a shell mode with full-width bottom status/app chrome
```

while:

```text
Dockbar
```

means:

```text
an optional compact application dock inside TopBar mode
```

They may reuse the same:

```text
DockApps
TaskbarPins
DockItem
icon settings
hover rendering
```

but they must never again share:

```text
enable state
topology meaning
exclusive policy
HakuMenu presentation policy
```

And HakuMenu presentation must be selected by:

```text
activation source + active shell topology
```

not by one global "Dock style".
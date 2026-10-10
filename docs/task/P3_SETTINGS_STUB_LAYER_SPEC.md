# P3 Settings Stub Layer — Implementation Spec

> Scope: **T1 only — build the Settings layer/surface as a visual stub, then STOP for visual review.**
>
> Do **not** implement real Settings functionality in this task.

## 0. Reviewed baseline

Reviewed repository: `hakuspace.zip`

```text
branch: quickshell
HEAD: d63e2a7e feat(sidebar): add SidebarSurface component for enhanced sidebar interaction
tracking: origin/quickshell
working tree: clean
```

Baseline validation before this task:

```text
git diff --check: PASS
qml_syntax_check.py: PASS
scripts/precommit_check.sh: PASS
```

Sidebar is already committed and working from the same `NavigationPanel` surface. Do not refactor its pointer-union logic while implementing Settings.

Canonical P3 references already in the repo:

```text
docs/task/mockups/setting.png
docs/task/HAKUSPACE_QUICKSHELL_PLAN.md        P3.4
docs/task/P3_DETAILED_ATOMIC_COMMIT_PLAN.md  Settings / T1
```

The existing P3 contract is intentionally narrow:

```text
centered inner Settings surface
stable/equal radius family
"Setting" header/control
"still working rn..." stub text
no real Settings implementation
```

---

# 1. Goal of this batch

Implement enough of Settings to answer one visual question:

> **Does the large centered Settings background/layer have the right silhouette, scale, radius and base surface style?**

The human will decide the next visual/content direction only after seeing this layer at runtime.

This is **not** the task for settings categories, theme editor, monitor settings, daemon settings, persistence, sliders, toggles, search, navigation tree, or settings data models.

After the stub is visible and the runtime matrix passes, **STOP**.

---

# 2. Architectural decision

## 2.1 Settings must be its own large-panel ownership state

Do **not** render the Settings body inside `NavigationPanel` while leaving:

```text
UiState.activePanel === "navigation"
```

Create explicit Settings ownership instead:

```text
UiState.activePanel === "settings"
settingsScreenName === <owning output>
```

Reason:

- `NavigationPanel` currently keeps Navigation visual ownership alive through `navigationVisualScreenName`;
- TopBar hides the real Logo and shifts the non-Logo left modules while that visual ownership exists;
- `setting.png` depicts a standalone centered inner layer, not a radial Navigation state;
- future real Settings should not be semantically coupled to Navigation lifetime.

Navigation is the **entry point**. Settings is the **destination surface**.

## 2.2 New surface topology

Preferred topology:

```text
SettingsPanel.qml
└─ one fullscreen transparent PanelWindow
   ├─ outside-dismiss input layer
   └─ centered rounded Settings surface
      ├─ small "Setting" header/control
      └─ "still working rn..."
```

Use one Settings `PanelWindow` for T1. Do not create a split Top/Overlay architecture, Flare host, or extra visual window for this stub.

## 2.3 Layer-shell contract

Settings window:

```text
WlrLayer.Overlay
ExclusionMode.Ignore
exclusiveZone: 0
transparent window background
fullscreen anchors on its owning screen
```

Recommended keyboard focus while open:

```text
WlrKeyboardFocus.Exclusive
```

This is a modal large surface and must receive deterministic `Escape` handling.

## 2.4 Do NOT use Flare for Settings T1

Do not use:

```text
FlarePanelWindow
FlareHost
FlareSurface ears/feet
TopBar attachment
RoundedScreen edge attachment
```

The mockup shows the Settings body detached from the screen edges and centered inside the RoundedScreen frame.

`FlarePanelWindow` is also structurally wrong for this task because it is an anchored top flare primitive with compact-width assumptions.

---

# 3. UiState contract

Add only the minimal explicit Settings state required by this surface.

Conceptually:

```text
property string settingsScreenName: ""

openSettings(screenName)
closeSettings()
closeSettingsIfScreen(screenName)
```

Required ownership behavior:

```text
open Settings
→ settingsScreenName = target output
→ activePanel = "settings"

close Settings
→ activePanel = ""
→ settingsScreenName = ""
```

`onActivePanelChanged` must clear `settingsScreenName` whenever the active large surface is no longer Settings.

Do not create a Settings service/model yet.

Do not add persistence yet.

Do not overload the old generic `toggle(panel)` helper for monitor-owned Settings state.

---

# 4. Navigation → Settings activation

The Settings sector already exists in Navigation:

```text
key: "settings"
```

and `UiState` already knows the historical handoff name:

```text
handoff-settings
```

T1 must finish the destination side of that contract without changing Sidebar semantics.

## Required activation semantics

Settings opens on **activation**, not merely pointer hover.

Required:

```text
hover Settings sector
→ select/highlight Settings only
→ do NOT open the large Settings layer

click Settings sector
→ open Settings on the same monitor

keyboard-select Settings + Enter/Return
→ open Settings on the same monitor
```

Sidebar remains the special immediate-hover handoff surface.

Do not make Settings behave like Sidebar hover expansion.

If the implementation passes through `handoff-settings` internally before transferring ownership to `activePanel="settings"`, that transition must be deterministic and must not use an arbitrary millisecond delay.

Do not add a timer just to make the ownership transfer work.

## Navigation close behavior

Changing ownership to `settings` may use the existing Navigation close lifecycle.

Do not force-clear `navigationVisualScreenName` in a way that snaps the Logo/TopBar transition. Let the existing Navigation close/visual-finish contract complete normally.

A bespoke polished Navigation→Settings morph is **out of scope for T1**. Correct ownership and no stale input are more important than transition polish in this pass.

---

# 5. Settings stub visual

Reference: `docs/task/mockups/setting.png`.

The Paint reference is approximately:

```text
inner surface width  ≈ 76% of output width
inner surface height ≈ 60% of output height
centered horizontally and vertically
```

Treat these as responsive proportions, not fixed 1152×648 pixel coordinates.

## 5.1 Outer Settings body

Use a single large rounded body centered in the output.

Initial style must deliberately stay neutral so the human can judge the base layer before more styling is invented.

Start with existing tokens only:

```text
color: Theme.surface
radius: Theme.radius
border: existing Theme.border / Theme.borderWidth contract only
```

No new Settings-only palette in T1.

Do not add:

```text
blur
acrylic/glass
wallpaper blur
custom gradient
new scrim/dimming layer
shadow system
glow
Flare ears
ornamental border
```

The desktop outside the body should remain visually unchanged/transparent in this first pass.

This is intentional: the point of T1 is to inspect the plain Hikai surface silhouette first.

## 5.2 Radius consistency

The body and header/control must come from the existing Hikai radius family.

Prefer:

```text
Theme.radius
Theme.radiusSm only where a smaller nested control genuinely needs it
```

Do not invent a one-off 27/31/37 px Settings radius just to trace the Paint line literally.

## 5.3 Header/control

Near the upper-left inside the Settings body, add the mockup header/control:

```text
Setting
```

Keep it a simple rounded control-like rectangle for now.

It is a **visual stub**, not a clickable category system.

Suggested first-pass styling using existing tokens:

```text
background: Theme.hoverMuted (or the nearest already-used neutral nested-surface token)
text: Theme.fg
radius: same radius family as the body
padding/offset: derived from Theme.pad / Theme.gap
```

Do not add more tabs/categories.

## 5.4 Stub copy

Render only the approved user-facing stub copy:

```text
still working rn...
```

Use a normal Hikai text token such as `Theme.fgDim`/`Theme.fg` and place it clearly inside the body, approximately centered.

The Vietnamese explanatory note drawn in the Paint mockup is an annotation, **not UI copy**. Do not render it.

---

# 6. Input and close behavior

While Settings is open, use a fullscreen input mask so outside click can dismiss the modal surface deterministically.

Required ordering:

```text
fullscreen outside-dismiss MouseArea
→ clicking outside body closes Settings

body MouseArea / pointer absorber above it
→ clicking inside body does NOT close Settings
```

Keyboard:

```text
Escape → close Settings
```

No other keyboard shortcuts in T1.

Do not add close buttons unless later requested; the current mockup does not specify one.

---

# 7. Monitor ownership

Settings must open on the screen that owned the Navigation activation.

Required:

```text
Navigation on monitor A → activate Settings → Settings on A
Navigation on monitor B → activate Settings → Settings on B
```

Do not default Settings to `Quickshell.screens[0]`.

Mount Settings per screen in `shell.qml` using the same `Variants { model: Quickshell.screens }` pattern already used by other monitor-owned surfaces.

Only the owner screen instance is visible/interactive.

---

# 8. Files expected to change

Keep the diff small.

Expected core files:

```text
src/home/.config/quickshell/hakuspace/services/UiState.qml
src/home/.config/quickshell/hakuspace/components/NavigationPanel.qml
src/home/.config/quickshell/hakuspace/components/SettingsPanel.qml   NEW
src/home/.config/quickshell/hakuspace/shell.qml
```

Do not create a large `components/settings/` hierarchy yet. T1 does not have enough real Settings content to justify it.

Do not modify `SidebarSurface.qml` unless a genuine regression caused by Settings is proven.

Do not refactor HakuMenu, Wallpaper, Tray, Notification, RoundedScreen, Theme, or Flare in this task.

---

# 9. Explicit non-goals

T1 must NOT implement any of the following:

```text
theme editor
wallpaper settings
monitor/display settings
workspace settings
WM settings
Hyprland/Niri/Mango configuration
notification settings
audio/brightness settings
network/bluetooth settings
daemon/service settings
JSON settings schema
persistence framework
search
sidebar/category navigation
real Setting actions
apply/save/reset buttons
settings IPC
new theme tokens solely for Settings
```

Do not fill empty space because it looks unfinished. Empty space is intentional in this stub.

---

# 10. Runtime acceptance matrix

Run this matrix on the real deployed shell after static checks.

## T1-A — closed baseline

```text
cold reload
→ no Settings layer visible
→ no invisible Settings input blocker
→ normal desktop interaction works
```

## T1-B — hover does not auto-open

```text
open Navigation
→ move pointer onto Settings sector
→ sector highlights/selects
→ large Settings body does NOT open from hover alone
```

## T1-C — click activation

```text
open Navigation
→ click Settings sector
→ Settings opens on same output
→ Navigation relinquishes ownership cleanly
→ centered body visible
```

## T1-D — keyboard activation

```text
open Navigation
→ keyboard-select Settings
→ Enter/Return
→ Settings opens on same output
```

## T1-E — visual stub

Verify:

```text
large inner body is centered
body is roughly 76% output width × 60% output height
body uses Theme.surface
radius visually belongs to existing Hikai family
"Setting" header/control appears near upper-left inside body
"still working rn..." appears inside body
no extra Settings UI exists
no Flare/TopBar attachment exists
outside area is not newly dimmed/blurred
```

## T1-F — close paths

```text
Settings open → Escape → closes
Settings open → click outside body → closes
Settings open → click inside body → stays open
```

After close:

```text
no stale mask
no stale keyboard focus
TopBar/Logo returns to normal
Navigation can open again
```

## T1-G — rapid lifecycle

At least 10 repetitions:

```text
Navigation → Settings → close → Navigation → Settings → close
```

Pass only if:

```text
no duplicate surface
no stale invisible blocker
no stuck Logo proxy
no permanently shifted TopBar left modules
no crash/QML error storm
```

## T1-H — ownership switching

From Settings, verify another large surface can subsequently open normally, e.g. HakuMenu or Wallpaper.

Pass only if `UiState.activePanel` still behaves as one-large-surface ownership authority.

## T1-I — multi-monitor

If a second monitor is available:

```text
open Settings from Navigation on A → body on A only
close
open Settings from Navigation on B → body on B only
```

No stale Settings body/input on the previous output.

## T1-J — fullscreen sanity

With a fullscreen client:

```text
activate Settings
→ Settings remains visible/usable as an Overlay
→ Escape/outside dismiss remains deterministic
```

---

# 11. Static gates

Before runtime report:

```bash
git diff --check
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

All must PASS.

Also grep the diff for accidental scope growth. There should be no new Settings persistence/service/data framework in T1.

---

# 12. Visual review gate — STOP HERE

After the runtime matrix passes, **do not continue styling or implementing Settings content**.

The next decision belongs to the human after seeing the actual layer.

Specifically, do not pre-emptively decide:

```text
whether the body should become lighter/darker
whether it needs a visible outline
whether a scrim is desirable
whether blur/glass should exist
whether dimensions should change
whether the header becomes tabs/sidebar/breadcrumb
what real Settings sections exist
```

Provide one clean runtime screenshot of Settings open if the environment can capture it.

The screenshot is for reviewing:

```text
silhouette
panel scale
vertical position
radius
plain Theme.surface appearance
header proportion
```

Only after visual approval should a follow-up spec change the style or add real content.

---

# 13. Commit contract

One accepted task = one commit.

Preferred commit:

```text
p3(settings): add hikai settings stub
```

Do not combine unrelated cleanup/refactors in this commit.

---

# 14. Gemini final report template

Return exactly enough evidence to review the implementation.

```markdown
# P3 Settings Stub T1 Report

## 1. Baseline
- starting HEAD:
- branch:
- starting git status:

## 2. Implementation
- files changed:
- UiState Settings ownership added:
- Navigation activation path:
- layer-shell configuration:
- Settings geometry formula:
- base background/radius tokens:
- outside-click/Escape behavior:
- monitor ownership:

## 3. Explicitly NOT implemented
- real settings controls/data/persistence:
- blur/gradient/scrim/new palette:
- Flare attachment:

## 4. Runtime matrix
- T1-A closed baseline: PASS/FAIL
- T1-B hover does not auto-open: PASS/FAIL
- T1-C click activation: PASS/FAIL
- T1-D keyboard activation: PASS/FAIL
- T1-E visual stub: PASS/FAIL
- T1-F close paths: PASS/FAIL
- T1-G rapid lifecycle: PASS/FAIL
- T1-H ownership switching: PASS/FAIL
- T1-I multi-monitor: PASS/FAIL/NOT AVAILABLE
- T1-J fullscreen sanity: PASS/FAIL/NOT TESTED

## 5. Visual evidence
- screenshot path / note:
- tested output logical size + scale:
- actual Settings body size at runtime:

## 6. Static gates
- git diff --check:
- qml_syntax_check.py:
- precommit_check.sh:

## 7. Git
- final git status --short:
- commit hash:
- commit subject:

## 8. Deviations / observations
- none, or list exact deviations
```

---

# 15. Review priority

For this pass, judge in this order:

```text
1. no ownership/input regression
2. correct same-monitor Settings activation
3. centered large-surface silhouette
4. correct plain Hikai background/radius
5. header + stub copy
6. transition polish (non-blocking for T1 unless visibly broken)
```

Do not turn T1 into a complete Settings implementation.

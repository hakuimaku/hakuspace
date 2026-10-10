# P3 Settings — Background Style T2 Spec

> Scope: **T2 visual refinement only — backdrop + body separation, then STOP for another visual review.**
>
> Do **not** implement real Settings controls, categories, data, persistence, animations, or navigation in this task.

## 0. Baseline / housekeeping

Target baseline commit:

```text
11bfdb75 p3(settings): add hikai settings stub
```

Before editing, verify:

```text
git status --short
git diff --check
```

The reviewed zip contains one post-commit whitespace-only change in:

```text
src/home/.config/quickshell/hakuspace/components/SettingsPanel.qml
```

It is only an extra blank line at EOF. Remove/revert that stray change first so the style work starts from the committed T1 baseline.

Do not mix unrelated cleanup into T2.

---

# 1. Visual decision from T1

Keep these T1 choices unchanged:

```text
body width  = 76% of output
body height = 60% of output
body        = centered
body color  = Theme.surface
header      = Theme.hoverMuted
stub copy   = centered
```

The T1 screenshot confirms the **silhouette and proportions are good enough**. Do not resize the panel in T2.

The main issue visible in the screenshot is not geometry. It is separation:

- on a bright client/background, the black Settings body is extremely high-contrast against the untouched desktop;
- on a dark client/background, the same black body can visually disappear into the content behind it;
- because Settings already captures fullscreen input, the current visual does not clearly communicate that the layer is modal.

T2 should solve only that.

---

# 2. Add a restrained modal backdrop

Add one fullscreen visual backdrop behind `settingsBody` while Settings is open.

Requirements:

- derive from the existing `Theme.scrim` / black theme language;
- use low opacity only;
- recommended starting opacity: **0.22**;
- no blur;
- no wallpaper sampling;
- no gradient;
- no acrylic/glass;
- no new Settings-only color token.

The backdrop is visual only. Existing outside-click behavior must remain the close mechanism.

Layer order should remain conceptually:

```text
fullscreen Settings PanelWindow
  ├─ dim backdrop
  ├─ outside-dismiss input area
  └─ centered settingsBody
```

`settingsBody` must remain fully opaque `Theme.surface`; do not dim the body itself.

### Why 0.22 first

The goal is to soften a bright white/client background without turning the whole screen into an almost-black modal sheet. This is a visual-review value, not a permanent design constant. Do not tune it through a large range in code.

---

# 3. Add subtle body separation for dark backgrounds

The body currently uses the normal theme border contract, whose default is effectively invisible.

For T2, add a **very subtle 1 px visual outline** around the Settings body so the black body still reads against a dark client/wallpaper.

Constraints:

- derive the outline from an existing foreground token such as `Theme.fg`;
- keep opacity around **0.10–0.12**;
- do not change the global `Theme.border` policy;
- do not introduce a new global palette token solely for Settings;
- do not turn the outline into an accent-colored frame;
- preserve the same radius as the body.

Prefer a local visual outline layer if that avoids changing the general border semantics used elsewhere in HakuSpace.

---

# 4. Radius / geometry decision

**Do not change radius in T2.**

The screenshot shows that the existing radius is acceptable enough to isolate the backdrop question. Changing radius, backdrop, outline, and geometry together would make the next review ambiguous.

Likewise, keep the current header/control size and position for now.

If the panel still feels too rectangular after backdrop/outline are visible, radius can be reviewed in a later isolated pass.

---

# 5. Do not add motion yet

Opening/closing animation is out of scope for T2.

Do not add:

```text
fade
scale
morph
spring
slide
Navigation -> Settings animation redesign
```

First establish the static visual hierarchy.

---

# 6. Input / ownership must remain unchanged

Do not change the T1 ownership model:

```text
UiState.activePanel === "settings"
UiState.settingsScreenName === owning screen
```

Do not change:

- Navigation activation semantics;
- `Escape` close;
- outside click close;
- inside click absorption;
- fullscreen input mask while open;
- per-screen `Variants` mounting;
- `WlrLayer.Overlay`;
- keyboard focus behavior.

T2 is styling only.

---

# 7. Explicitly out of scope

Do not implement any of the following:

```text
real Settings categories
sidebar/tree navigation
search
theme editor
wallpaper settings
monitor/display settings
WM settings
notification settings
audio/brightness controls
network/bluetooth controls
service/daemon settings
persistence/schema
IPC
new theme palette
blur/glass
drop shadow system
Settings open/close animation
```

Do not modify Sidebar, Notification, Wallpaper, HakuMenu, or WM backends unless a real regression caused by T2 is demonstrated.

---

# 8. Runtime acceptance matrix

## T2-A — bright background

Open/maximize a bright client similar to the T1 screenshot, then open Settings.

PASS when:

- background is visibly but gently dimmed;
- Settings body remains solid black;
- text/header contrast is unchanged;
- body still feels detached from the underlying client;
- outside-click closes normally.

## T2-B — dark background

Use a dark client/wallpaper and open Settings.

PASS when:

- body edge remains detectable because of the subtle outline;
- outline is not visually dominant;
- no bright white/accent frame appears.

## T2-C — modal semantics

While open:

- click inside body -> stays open;
- click dimmed area -> closes;
- Escape -> closes.

After closing:

- backdrop disappears completely;
- no invisible input blocker remains.

## T2-D — rapid lifecycle

Repeat at least 10 times:

```text
Navigation -> Settings -> outside close
Navigation -> Settings -> Escape close
```

PASS when there is no stale backdrop, stale input mask, or stuck ownership.

## T2-E — regression sanity

Verify after closing Settings:

```text
Navigation opens normally
Sidebar handoff still works
HakuMenu can open
Wallpaper can open
```

No need to re-run unrelated deep subsystem matrices.

---

# 9. Static gates

Run:

```text
git diff --check
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

All must pass.

---

# 10. Visual evidence required

Provide **two screenshots** at the same logical resolution if possible:

1. Settings over a bright background/client.
2. Settings over a dark background/client.

Report:

```text
output logical size
scale
body actual size
backdrop opacity used
outline opacity used
```

Do not make further aesthetic changes after capturing these images.

---

# 11. Commit boundary

One commit only:

```text
p3(settings): refine stub backdrop separation
```

Expected product-code scope should remain essentially:

```text
src/home/.config/quickshell/hakuspace/components/SettingsPanel.qml
```

Only touch another product file if technically required and explain why in the report.

---

# 12. STOP gate

After T2 passes, **STOP**.

Do not proceed to Settings controls or another visual pass automatically.

The next decision must be made from the two runtime screenshots:

```text
A. keep this background style
B. adjust backdrop strength
C. revisit body radius
D. revisit header treatment
E. only then start real Settings information architecture
```

---

# 13. Report template

```markdown
# P3 Settings Background T2 Report

## 1. Baseline
- starting HEAD:
- branch:
- starting git status:
- stray EOF whitespace removed/reverted: YES/NO

## 2. Changes
- files changed:
- backdrop token/source:
- backdrop opacity:
- body outline token/source:
- outline opacity:
- geometry changed: MUST BE NO
- radius changed: MUST BE NO
- input/ownership behavior changed: MUST BE NO

## 3. Runtime matrix
- T2-A bright background:
- T2-B dark background:
- T2-C modal semantics:
- T2-D rapid lifecycle:
- T2-E regression sanity:

## 4. Screenshots
- bright screenshot path:
- dark screenshot path:
- output logical size + scale:
- actual Settings body size:

## 5. Static gates
- git diff --check:
- qml syntax:
- precommit:

## 6. Git
- final git status --short:
- commit hash:
- commit subject:

## 7. Deviations / observations
- ...

STOP HERE.
```

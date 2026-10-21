# HakuSpace Settings — Ink Terminal Redesign Plan

Status: **READY FOR CODEX**  
Scope: **Settings layer only**  
Reference concept: **02_ink_terminal.html**  
Target: HakuSpace / Quickshell QML

---

## 0. Goal

Redesign the existing HakuSpace Settings UI to follow the **Ink Terminal** concept while preserving all current runtime behavior, persistence, validation, backend contracts, and Settings open/close lifecycle.

This is a **UI/chrome/layout refactor**, not a settings backend rewrite.

The result should feel like a polished terminal/control-center:

- near-black "ink" surface;
- thin accent-colored borders and separators;
- compact top navigation;
- contextual left sidebar;
- card-based settings sections;
- strong monospace/terminal identity;
- subtle grid/scanline texture, but never enough to hurt readability;
- footer status/action bar;
- fast, restrained hover/focus/page transitions;
- dynamic HakuSpace accent and existing Theme bindings, not hard-coded red.

The HTML concept is a visual reference, **not a second source of truth for settings values or behavior**.

---

## 1. Hard constraints / non-goals

### MUST preserve

1. `SettingsStore`, `ShellSettingsStore`, `ConfigEditorStore`, `InfoStore` semantics.
2. Existing `UiState` Settings ownership / active-panel behavior.
3. Current screen ownership and multi-monitor behavior of `SettingsPanel.qml`.
4. Existing modal input behavior:
   - outside click closes Settings;
   - `Escape` closes or cancels the active confirmation first;
   - keyboard focus stays correct.
5. Existing open/close animation and Settings panel surface lifecycle unless a change is strictly internal to the panel content.
6. General settings validation / editable-key rules.
7. Shell live preview, `Reload`, `Reset`, `Discard`, `Apply`, migration behavior, and invalid-value rejection.
8. Config draft/save/reload/switch/VS Code confirmation flow.
9. Info refresh behavior.
10. Existing accessibility / keyboard activation for controls.

### MUST NOT

- rewrite settings stores just to fit the new UI;
- change configuration file formats;
- rename persisted keys;
- change `setting.sh` or `hikai-shell.json` semantics;
- remove existing validation;
- convert Settings into a different window/layer architecture;
- touch wallpaper, desktop, TopBar, Dock, HakuMenu, Notification Center, etc. except where compilation requires an import adjustment;
- hard-code the reference accent `#ff5d52` as the production accent;
- duplicate Settings state inside UI components;
- add a second dirty-state model;
- introduce a JS settings model when existing QML stores already provide the data.

If visual fidelity conflicts with runtime behavior, **runtime behavior wins**.

---

## 2. Existing implementation to work from

Primary files:

```text
src/home/.config/quickshell/hakuspace/components/SettingsPanel.qml
src/home/.config/quickshell/hakuspace/components/settings/GeneralSettingsPage.qml
src/home/.config/quickshell/hakuspace/components/settings/ShellSettingsPage.qml
src/home/.config/quickshell/hakuspace/components/settings/ConfigEditorPage.qml
src/home/.config/quickshell/hakuspace/components/settings/InfoPage.qml
src/home/.config/quickshell/hakuspace/components/settings/SettingsActionButton.qml
src/home/.config/quickshell/hakuspace/components/settings/SettingsSegmentedToggle.qml
src/home/.config/quickshell/hakuspace/components/settings/SettingsSlider.qml
src/home/.config/quickshell/hakuspace/components/settings/SettingsTooltip.qml
src/home/.config/quickshell/hakuspace/services/SettingsStore.qml
src/home/.config/quickshell/hakuspace/services/ShellSettingsStore.qml
src/home/.config/quickshell/hakuspace/services/ConfigEditorStore.qml
src/home/.config/quickshell/hakuspace/services/InfoStore.qml
```

Existing regression coverage to preserve:

```text
scripts/hikai_settings_harness.qml
scripts/test_hikai_settings_ctl.py
scripts/qml_syntax_check.py
scripts/precommit_check.sh
```

Before coding, inspect these files and document the current dirty/apply/reload/confirmation contracts. Do not infer them from the HTML mock.

---

## 3. Production interpretation of the Ink Terminal concept

The HTML mock duplicates `General / Shell / Config / Info` in both the top tabs and sidebar. **Do not copy that duplication literally.**

Use this hierarchy instead:

### Top bar = primary domains

```text
General | Shell | Config | Info
```

This remains the authoritative page switcher.

### Left sidebar = context navigation inside the selected domain

#### General

```text
General
Wallpaper
Screen Recording
Haku Widget
Exit
```

Generate these from `SettingsStore.catalog` group names where practical; do not create a second catalog of settings values.

#### Shell

```text
Appearance
Rounded Screen
Surface
App Bar
Dockbar
Top Bar
```

Use the sections already represented by `ShellSettingsPage.qml`.

#### Config

Sidebar becomes the real file browser:

```text
wm
  hyprland-custom.lua
  mango-custom.conf
  niri-custom.kdl
config
  ...
```

Reuse `ConfigTreeModel.js` and `ConfigEditorStore.files`. Do not maintain a second tree.

#### Info

```text
HakuSpace
User & Session
Linux
Hardware
Graphics
Storage
```

Only show entries that have data. Section names should follow the current `InfoPage` model/rows.

### Sidebar behavior

- clicking a contextual section scrolls that section into view;
- as the user scrolls, the active sidebar item should track the visible section where practical;
- Config sidebar selection continues to mean file selection, not scroll navigation;
- keyboard focus and `Tab` traversal must remain usable;
- sidebar must scroll independently if it exceeds available height.

Do not make scroll synchronization a blocker for Batch 1. It may be added after the static layout is stable.

---

## 4. Window / chrome visual spec

### Overall panel

Target desktop size:

```text
preferred width: 1160–1180 px
preferred height: 720–760 px
minimum screen margin: 32 px
```

Keep responsive clamping to the current monitor. Never overflow small screens.

Production colors must derive from existing `Theme` values:

```text
panel / shell        -> Theme.surface or a very small derived darker blend
card                 -> derived from Theme.surface / Theme.hoverMuted
accent               -> Theme.accent
text                 -> Theme.fg
secondary text       -> Theme.fgDim
muted / key text     -> Theme.fgMuted
border               -> Theme.border, optionally mixed with Theme.accent
focus ring           -> Theme.accent
```

No production component should depend on the HTML's literal red.

### Ink treatment

Add only subtle terminal texture:

- low-opacity grid or scanline overlay;
- opacity should be extremely low;
- texture must be `visible: false` or naturally disappear when reduced visual complexity is needed on very small surfaces;
- must not animate continuously;
- must not interfere with text contrast or input hit testing.

Prefer pure QML Shapes/Rectangles. Do not add external image assets just for the texture.

### Border / radius

Ink Terminal should be sharper than the current pill-heavy Settings UI:

- main panel radius: moderate, roughly `Theme.radius` / `Theme.largeRadius` range;
- cards: small-to-medium radius;
- fields/buttons: modest radius, not full pills except true segmented toggles/chips;
- 1 px borders are a major part of the design language;
- selected sidebar item uses a thin accent edge/rail rather than a large accent-filled pill.

### Typography

Use `Theme.fontFamily` and existing font sizing as the source of truth.

Terminal identity should come from layout, case, key labels, spacing and separators—not from assuming a specific font exists.

Setting keys such as `WELCOME_MSG` or `dock.iconSize` should remain visually secondary and compact.

---

## 5. Target panel structure

Inside the existing `SettingsPanel.qml` body, converge toward:

```text
┌──────────────────────────────────────────────────────────────┐
│ H  Settings      General Shell Config Info        source/meta│
├───────────────┬──────────────────────────────────────────────┤
│ contextual    │ page title                         search     │
│ sidebar       │ subtitle                                      │
│               │                                              │
│ section       │ ─ GENERAL ─────────────────────────────────  │
│ section       │ ┌──────────────────────────────────────────┐ │
│ section       │ │ setting metadata       control           │ │
│ ...           │ │ setting metadata       control           │ │
│               │ └──────────────────────────────────────────┘ │
│               │                                              │
├───────────────┴──────────────────────────────────────────────┤
│ status / dirty indicator            Reload ... Apply/Save    │
└──────────────────────────────────────────────────────────────┘
```

The outer Settings launch morph / positioning may remain exactly as today. Replace the **expanded content/chrome**, not the proven window ownership mechanics.

---

## 6. New reusable QML primitives

Create only the primitives that actually reduce duplication. Suggested names:

```text
components/settings/SettingsTopBar.qml
components/settings/SettingsSidebar.qml
components/settings/SettingsSectionCard.qml
components/settings/SettingsSearchField.qml
components/settings/SettingsFooter.qml
```

Optional only if needed:

```text
components/settings/SettingsField.qml
components/settings/SettingsSectionHeader.qml
```

Do **not** turn this into a generic UI framework.

Keep and restyle existing controls where possible:

```text
SettingsActionButton.qml
SettingsSegmentedToggle.qml
SettingsSlider.qml
SettingsTooltip.qml
```

Their existing event and accessibility behavior should remain intact.

---

## 7. Footer architecture

The HTML mock has one persistent footer. Production should also look like one persistent footer, but it must delegate to the currently selected domain's real semantics.

### General

Status source:

```text
SettingsStore.error
SettingsStore.statusMessage
SettingsStore.loading
SettingsStore.dirty
```

Actions:

```text
Reload
Apply
```

During confirmation:

```text
Keep
Discard
```

Preserve current behavior exactly.

### Shell

Status source:

```text
ShellSettingsStore.error
ShellSettingsStore.statusMessage
ShellSettingsStore.loading
ShellSettingsStore.saving
ShellSettingsStore.dirty
ShellSettingsStore.migrationPending
```

Actions:

```text
Reload
Reset
Discard
Apply
```

Preserve current enable/disable rules and validation checks exactly.

### Config

Status and action labels stay driven by the current `ConfigEditorPage` confirmation state:

```text
Reload / Save
Cancel / Discard & Switch / Save & Switch
Keep Editing / Discard & Reload
Cancel / Open Anyway
```

Do not simplify these flows just to match the mock.

### Info

No persistence actions.

Footer may show:

```text
System information · local snapshot
Refresh
```

or keep Refresh in the page header if that produces cleaner code. Either is acceptable.

### Implementation rule

Prefer exposing page-level properties/signals such as:

```text
footerStatus
footerActions
activateFooterAction(label)
```

or an equivalent small interface.

Do not make `SettingsPanel.qml` directly manipulate every store field if that would duplicate page logic. Existing page logic remains authoritative.

---

## 8. Page-specific redesign

## 8.1 General

### Layout

- page header: `General` + short description + search field;
- grouped section headers in accent terminal style;
- each catalog group becomes a bordered card;
- each setting row becomes a two-column layout:
  - left: label, key, hint/validation;
  - right: control;
- row separators are thin and muted;
- responsive fallback stacks metadata over control below a width threshold.

### Search

Add a UI-only filter for:

- label;
- key;
- group;
- hint.

Search **must not alter** `SettingsStore.catalog` or values. It only controls visibility.

When a search hides all rows in a group, hide that group card/header.

### Controls

Preserve existing behaviors for:

- bool segmented toggle;
- enum mode selection;
- integer/text/path/required input;
- list chips + add/remove;
- validation message;
- disabled/uneditable state.

Do not convert path/text fields to fake mock values.

---

## 8.2 Shell

### Layout

Match the Ink Terminal card hierarchy:

```text
Appearance
Rounded Screen
Surface
App Bar
Dockbar
Top Bar
```

Use the existing live-bound controls. The redesign must not add staging between the control and `ShellSettingsStore`; live preview remains immediate.

### Sliders

Slider rows should show:

```text
label / key
track                         numeric value badge
```

Value badge updates live.

Preserve ranges, steps and validation currently implemented in QML/store.

### Surface tone

Render `Ink / Dark / Soft` as a compact segmented control consistent with concept 02.

### TopBar modules

Use a clean row per module with the existing enabled state. Avoid huge accent pills.

---

## 8.3 Config

This is the page that should most closely resemble the HTML mock.

### Layout

```text
left sidebar/file tree | editor
```

The global contextual sidebar can directly become the Config browser; avoid nesting a second redundant file sidebar if possible.

Target behavior:

- groups `wm` and `config` remain clearly separated;
- active file gets a thin accent rail + subtle surface highlight;
- editor path appears in a compact editor toolbar;
- `Open in VS Code` remains available with existing warning semantics;
- code editor fills remaining space;
- footer owns draft status and Save/Reload confirmation actions.

Preserve:

- pending file selection;
- dirty draft handling;
- disk revision conflict protections;
- save-and-switch;
- discard-and-switch;
- reload confirmation;
- VS Code saved-version warning;
- `Escape` cancellation behavior.

Do not replace `PlainTextEditor`.

---

## 8.4 Info

Render Info as terminal-like info cards, normally two columns when enough width exists and one column on narrow screens.

Each card:

```text
accent section title
key                value
key                value
...
```

Reuse existing InfoStore data and row generators. Do not hard-code system data from the HTML mock.

Values that elide should keep tooltips.

---

## 9. Motion / interaction spec

Ink Terminal motion should be restrained.

### Preserve outer lifecycle

Keep the existing Settings opening sequence unless there is a proven bug:

```text
launch/attach -> center -> expand
```

and the existing close behavior.

### Internal transitions

Allowed:

- tab/page switch: opacity + 4–8 px vertical translation, ~140–200 ms;
- sidebar hover: subtle background + 1–2 px horizontal movement at most;
- card hover: border accent increase, optional 1 px lift;
- focus: accent border/ring;
- dirty indicator: small accent dot/glow;
- toast/status feedback: short fade/translate.

Avoid:

- continuous glowing/pulsing animations;
- animated scanlines;
- large scaling on every row;
- motion that changes layout while typing;
- long animations over 250 ms for normal controls.

Use existing `HAnimation` durations/curves where appropriate.

---

## 10. Keyboard and accessibility requirements

Must pass:

- `Tab` traverses top tabs, sidebar, main controls, footer actions logically;
- `Enter` / `Space` activates buttons/toggles where currently supported;
- `Escape`:
  1. cancels active page confirmation;
  2. otherwise triggers Settings close flow;
- focus indicator remains visible against black surfaces;
- search field is keyboard reachable;
- disabled controls do not accept focus where current behavior already prevents it;
- Config editor keyboard behavior is not hijacked by global shortcuts.

Do not regress existing `Accessible.*` declarations.

---

## 11. Responsive behavior

Required targets:

### Normal desktop

```text
>= ~1050 px available panel width
sidebar 210–240 px
main content uses remainder
2-column metadata/control rows
Info 2-column cards
```

### Medium

```text
~760–1050 px
sidebar 180–210 px
main rows may stack if needed
Info can reduce to 1 column
```

### Small

When the monitor cannot reasonably fit a fixed sidebar:

- reduce sidebar width first;
- if still too narrow, allow sidebar to collapse into a compact contextual strip/dropdown;
- do not simply clip controls;
- preserve minimum 32 px screen margin where physically possible.

No page should require a 1180 px monitor to be usable.

---

## 12. Implementation batches

## Batch S0 — Baseline / contracts

Before modifying UI:

1. Run current Settings harness/tests.
2. Record current `git status --short`.
3. Read the four pages and stores.
4. Write a short baseline note into the final report:
   - dirty semantics;
   - reload semantics;
   - apply/save semantics;
   - close confirmation semantics;
   - Config confirmation cases.

**No code changes yet.**

Acceptance:

```text
baseline tests PASS
behavioral contracts understood
```

---

## Batch S1 — Ink chrome + layout skeleton

Implement:

- new panel interior layout;
- top bar;
- primary tabs;
- contextual sidebar shell;
- main viewport;
- persistent footer shell;
- Ink surface/borders/grid texture;
- responsive sizing.

At this stage, pages may still render mostly their current internal layout.

Do not change store logic.

Acceptance:

- Settings opens/closes exactly as before;
- all four tabs reachable;
- panel never exceeds screen;
- outside click / Escape still work;
- no syntax/runtime errors.

---

## Batch S2 — General page

Implement card grouping, two-column rows, search, section navigation, terminal keys/hints, validation styling.

Acceptance:

- every existing catalog item still appears when search is empty;
- every editable control writes to the same store key as before;
- all current field types work;
- validation behavior unchanged;
- Reload/Apply confirmation semantics unchanged.

---

## Batch S3 — Shell page

Implement Ink cards/rows/sliders/segmented controls and contextual sidebar anchors.

Acceptance:

- live preview still immediate;
- `Reset`, `Discard`, `Apply`, `Reload` semantics unchanged;
- migration state unchanged;
- Dockbar controls remain editable according to current rules;
- current `hikai_settings_harness.qml` still passes.

---

## Batch S4 — Config page

Integrate existing file tree into the Ink sidebar/editor split and move visual status/actions into the common footer without changing the action state machine.

Acceptance:

- file tree lists the same files;
- dirty switch prompts remain correct;
- Save & Switch / Discard & Switch pass;
- reload confirmation passes;
- VS Code warning passes;
- editor receives full keyboard input;
- no draft loss on accidental navigation.

---

## Batch S5 — Info + polish

Implement Info cards, section sidebar, refresh affordance, tooltips, final spacing/motion/focus polish.

Acceptance:

- no hard-coded machine information;
- all currently available InfoStore groups remain visible;
- refresh works;
- long values elide/tooltip safely.

---

## Batch S6 — Runtime hardening / cleanup

1. Run complete Settings tests.
2. Run syntax/precommit checks.
3. Test physical Settings interaction on at least the currently active compositor.
4. Verify no debug logging was left behind.
5. Verify no duplicate/dead old footer code remains after the common footer cutover.
6. Remove obsolete layout-only code only after behavior is proven.
7. Produce final report.

---

## 13. Required regression matrix

Run at minimum:

### Panel lifecycle

```text
open Settings
switch General -> Shell -> Config -> Info -> General
Escape close
outside-click close
reopen on same monitor
reopen after changing monitor/focus if multi-monitor is available
```

### General

```text
bool edit
text/path edit
integer edit
enum edit
list add
list remove
invalid value / validation display
Reload clean state
Reload dirty -> Keep
Reload dirty -> Discard
Apply valid changes
close dirty -> Keep
close dirty -> Discard
```

### Search

```text
search by label
search by key
search by group
clear search -> all rows restored
no-result state does not alter values
```

### Shell

```text
base radius live preview
rounded screen radius
border thickness
surface Ink/Dark/Soft
App Bar toggles
Dock icon size
hover lift
hover scale
Dockbar visibility/exclusive space
TopBar module toggle
Reset
Discard
Apply
Reload
invalid edit rejected
```

### Config

```text
select clean file
edit draft
switch file -> Cancel
switch file -> Discard & Switch
switch file -> Save & Switch
Reload dirty -> Keep Editing
Reload dirty -> Discard & Reload
Open in VS Code while clean
Open in VS Code while dirty -> Cancel
Open in VS Code while dirty -> Open Anyway
Save
Escape from confirmation
Escape from page/settings
```

### Info

```text
load
refresh
scroll
long-value tooltip
missing optional section does not leave broken layout
```

### Responsive

```text
1920x1080-ish
1366x768-ish
small constrained harness/window size
```

---

## 14. Required automated checks

Use the repo's actual invocation conventions, but the final run must include the equivalents of:

```bash
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
python3 scripts/test_hikai_settings_ctl.py
scripts/precommit_check.sh
```

Also run the existing QML Settings harness using the repo's documented Quickshell test command/environment.

If the harness breaks because it locates controls structurally, first determine whether the harness is asserting a real behavior or relying on obsolete layout structure. Update tests only when the production behavior remains equivalent and document the reason.

Never weaken a behavioral assertion just to make the redesign pass.

---

## 15. Visual acceptance criteria

The redesign is not done until these are true:

1. The Settings window is visibly recognizable as **Ink Terminal**, not the previous UI with darker colors.
2. Main hierarchy is immediately readable:
   - top domains;
   - left context;
   - main settings cards;
   - persistent footer.
3. Accent is used sparingly:
   - selected tab;
   - focus;
   - section title/rail;
   - primary action;
   - dirty/error indicators.
4. Settings rows have consistent alignment across General and Shell.
5. The Config page visually belongs to the same design system as General/Shell.
6. No giant filled accent pills for every heading.
7. No excessive empty space like the current sparse layout.
8. Long settings pages feel dense but not cramped.
9. The panel remains readable with different dynamic accent colors.
10. The result still feels like HakuSpace, not a generic GNOME/KDE settings clone.

---

## 16. Files expected to change

Likely:

```text
components/SettingsPanel.qml
components/settings/GeneralSettingsPage.qml
components/settings/ShellSettingsPage.qml
components/settings/ConfigEditorPage.qml
components/settings/InfoPage.qml
components/settings/SettingsActionButton.qml
components/settings/SettingsSegmentedToggle.qml
components/settings/SettingsSlider.qml
components/settings/SettingsTooltip.qml
```

Likely new:

```text
components/settings/SettingsTopBar.qml
components/settings/SettingsSidebar.qml
components/settings/SettingsSectionCard.qml
components/settings/SettingsSearchField.qml
components/settings/SettingsFooter.qml
```

Tests/harness may change only if required for the new hierarchy while preserving behavioral assertions.

Stores should normally remain unchanged:

```text
services/SettingsStore.qml
services/ShellSettingsStore.qml
services/ConfigEditorStore.qml
services/InfoStore.qml
```

Any store change must be called out explicitly in the report with a concrete reason.

---

## 17. Final report required from Codex

Create:

```text
docs/task/SETTINGS_INK_TERMINAL_REDESIGN_REPORT.md
```

Report must contain:

```text
Status: DONE / PARTIAL / BLOCKED

1. Summary
2. Files changed
3. UI architecture
4. Behavior intentionally preserved
5. Any behavior changed and why
6. General regression results
7. Shell regression results
8. Config regression results
9. Info regression results
10. Responsive/runtime observations
11. Automated test commands + exact PASS/FAIL
12. Known limitations / follow-ups
13. git diff --check result
14. git status --short
```

Include screenshots only if Codex/runtime tooling can produce them reliably; screenshots are useful evidence but not a substitute for runtime behavior tests.

---

## 18. Stop conditions

Stop and report instead of improvising if:

- a visual change appears to require changing persisted settings format;
- Config draft safety cannot be preserved with the proposed footer refactor;
- Settings panel focus/input ownership regresses;
- the redesign requires touching unrelated desktop layers;
- a store contract is unclear and cannot be verified from current code/tests;
- a test reveals an existing unrelated bug outside Settings.

Do not hide regressions with timers, forced delays, or disabled assertions.

---

## 19. Recommended execution order for Codex

```text
S0 Baseline
  ↓
S1 Ink chrome/layout skeleton
  ↓
S2 General
  ↓
S3 Shell
  ↓
S4 Config
  ↓
S5 Info + polish
  ↓
S6 runtime hardening + report
```

Commit/checkpoint after each batch if the working workflow permits it. Do not attempt the entire visual rewrite as one giant unverified diff.

---

## One-line design rule

> **Keep every existing Settings contract, replace the sparse presentation with a dense Ink Terminal control-center, and let HakuSpace's dynamic Theme—not the HTML mock's hard-coded colors—own the final look.**

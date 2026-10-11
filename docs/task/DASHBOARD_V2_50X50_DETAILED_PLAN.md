# HakuSpace Dashboard V2 — 50% × 50% Detailed Implementation Plan

Status: **PLAN ONLY — no implementation yet**  
Basis: uploaded `dashboard-monitor.png` + current `hakuspace.zip` Quickshell code.  
Target: evolve the existing P3 Dashboard without rewriting Navigation, Flare, Avatar persistence, Media, or SysStats architecture unnecessarily.

## 0. Design intent locked from the new sketch

The new Dashboard keeps the existing top-left attached HakuSpace/Flare identity but changes the visual contract:

- final Dashboard envelope becomes **50% output width × 50% output height**;
- keep the large intentionally empty area — do not stretch cards to fill the whole 50×50 shell;
- Avatar remains the visual origin and gains a hover enlargement effect;
- profile/name treatment lives below the Avatar as shown in the sketch;
- upper card cluster remains compact:
  - Clock;
  - MPRIS/Media;
  - Calendar widget;
  - Monitor card;
- MPRIS card gets a subtle **Cava audio waveform behind the media content** while music is playing;
- Calendar day numbers get a hover reaction;
- Monitor card changes from the current 2×2 ROM/RAM/CPU/GPU grid to:
  - two circular gauges at the top;
  - left/right control to switch the two circles between the System view and GPU view;
  - storage rows underneath stay fixed when switching gauge pages;
  - root `/` storage is always shown;
  - additional mounted disks/mountpoints are shown below it;
- Dashboard elements should expose useful hover tooltips.

### GPU-page assumption

The sketch says the arrows switch the **two circular gauges** to a GPU tab but does not name the second GPU metric. The recommended contract is:

1. GPU utilization;
2. VRAM usage percentage when reliably available, otherwise `N/A` with a neutral gauge.

Do not fake VRAM or show `0%` when the backend cannot obtain it reliably.

---

## 1. Current-code findings that affect the implementation

### Geometry is duplicated today

`DashboardSurface.qml` currently owns the 45% × 45% visual envelope, while `NavigationPanel.qml` separately hardcodes 45% again for the Dashboard safe-zone mask. Changing only one will create a pointer/mask mismatch.

### Monitor backend is not sufficient for the new card

Current `SysStats.qml` + `sysstats_snapshot.sh --extended` provide:

- CPU;
- RAM;
- root `/` used percentage;
- one GPU utilization percentage.

They do **not** provide:

- mounted-disk list;
- per-mount usage;
- VRAM usage.

### Cava can be reused, but its public data shape should improve

Current `Cava.qml` already runs one Cava process while media is playing, but exposes the visualization primarily as the glyph string `bars`. The Dashboard should not launch another Cava process. Instead expose normalized numeric levels from the existing singleton while preserving `bars` for the TopBar.

### Current global tooltip path cannot simply be reused inside Dashboard

`TooltipManager.qml` intentionally suppresses TopBar tooltips whenever `UiState.activePanel !== ""`. Dashboard lives inside the active Navigation panel, so placing ordinary `HTooltip` objects inside Dashboard would not be sufficient. Dashboard needs a panel-local tooltip host or an explicitly scoped extension of the tooltip system.

### Calendar day cells currently have no hover target

The calendar navigation controls already have hover states, but the 42 day cells are currently passive visual items. Day-cell hover must be added without changing Calendar geometry.

### Avatar behavior is already valuable and must remain intact

Current Avatar contract must survive:

- left click → return to radial Navigation;
- right click → change avatar;
- file chooser cancel → Dashboard stays open;
- selected avatar persists through existing `Avatar` service.

Hover enlargement should be a visual transform only; do not resize the layout slot or change the pointer contract.

---

# 2. Implementation batches

## DV2.0 — Freeze the new Dashboard contract in docs before code

### Files

- `docs/task/HAKUSPACE_QUICKSHELL_PLAN.md`
- `docs/task/QUICKSHELL_STYLE.md`
- add `docs/task/DASHBOARD_V2_50X50_PLAN.md` (this plan or a condensed canonical copy)

### Changes

Replace the old Dashboard-specific 45×45 / monitor-2×2 statements with the new V2 contract, while keeping historical P3 completion notes clearly marked as superseded by V2.

Lock these invariants:

- envelope = 50% × 50%;
- 20px shell inset retained unless runtime evidence proves it must change;
- existing 200px pointer safe-zone semantics retained;
- Flare attachment and Navigation↔Dashboard reversible morph retained;
- sparse/empty area is intentional;
- Dynamic Widget Host remains; Calendar remains its default widget;
- no extra Cava process;
- no per-row storage polling processes;
- unsupported GPU/VRAM data renders `N/A`, never fake values.

### Acceptance

There is one unambiguous Dashboard V2 contract and no active doc still claiming that the final Dashboard is 45×45 or that Monitor must remain the 2×2 ROM/RAM/CPU/GPU grid.

### Suggested commit

`docs(dashboard): lock 50x50 v2 interaction and monitor contract`

---

## DV2.1 — Geometry foundation: 45×45 → 50×50 without regressions

### Primary files

- `components/NavigationPanel.qml`
- `components/dashboard/DashboardSurface.qml`

### Architecture change

Remove duplicated percentage constants.

Recommended ownership in `NavigationPanel.qml`:

- `dashboardWidthRatio: 0.50`
- `dashboardHeightRatio: 0.50`
- `dashboardVisualWidth = round(screenWidth * dashboardWidthRatio)`
- `dashboardVisualHeight = round(screenHeight * dashboardHeightRatio)`
- `dashboardSafeWidth = dashboardVisualWidth + dashboardSafeMargin`
- `dashboardSafeHeight = dashboardVisualHeight + dashboardSafeMargin`

Pass the resolved final dimensions into `DashboardSurface` instead of having `DashboardSurface` independently multiply by `0.50` again.

### Preserve

- `dashboardMorphProgress` reversible morph;
- Flare top/left seam;
- current close behavior outside the safe zone;
- pass-through beyond safe zone;
- input mask union semantics;
- Avatar origin morph.

### New compact content geometry

Do **not** let the four cards stretch across the whole 50%-width shell.

Recommended shell layout:

- shell inset: `20px`;
- Avatar/profile rail width: current Navigation/avatar diameter;
- gap from profile rail to card cluster: `12–16px`;
- compact card cluster width: responsive but capped, approximately `560–620px` on large outputs;
- two equal card columns inside that cluster;
- row 1: Clock | Media;
- row 2: Calendar host | Monitor;
- leave remaining right/bottom shell region intentionally empty.

This matches the sketch much better than expanding cards to fill the new 50% envelope.

### Responsive checks

At minimum verify:

- 1920×1080 → visual envelope 960×540;
- 2560×1440 → 1280×720;
- 1366×768 → 683×384;
- one ultrawide output;
- HiDPI/logical scaling if available.

### Acceptance

- final visual envelope is exactly 50% × 50% in logical output geometry;
- pointer safe zone starts after the new 50×50 edge, not the old 45×45 edge;
- moving out by >200px still closes;
- area beyond safe zone remains pass-through;
- no mask holes around Flare ear/foot;
- Navigation↔Dashboard morph remains reversible mid-animation.

### Suggested commit

`feat(dashboard): expand shell to canonical 50x50 geometry`

---

## DV2.2 — Profile rail + Avatar hover polish

### Files

- `components/dashboard/DashboardAvatar.qml`
- `components/dashboard/DashboardSurface.qml`
- optional new `components/dashboard/DashboardProfileRail.qml`
- optional new `services/UserIdentity.qml`
- `services/qmldir` if a singleton is added

### Avatar hover

Use a visual `Scale` transform, not dynamic width/height.

Recommended behavior:

- hover scale ~`1.06–1.10`;
- accent ring becomes slightly stronger;
- motion uses shared `HAnimation.buttonHoverDuration` / hover curve;
- hitbox remains at the original diameter to avoid pointer oscillation when the visual grows;
- growth must not overlap/capture neighboring card hitboxes unexpectedly.

### Name/profile text

The sketch includes a name under the Avatar and a vertical Hikai identity treatment.

Recommended implementation:

- one-shot username/display-name provider, **no polling**;
- fallback to account username if no friendly display name is available;
- keep avatar persistence inside existing `Avatar.qml`; do not fold Avatar storage into the new identity provider;
- profile text remains decorative/passive unless a future explicit action is added.

### Acceptance

- all existing left/right-click Avatar behavior passes unchanged;
- hover enlargement is smooth and does not move surrounding layout;
- changing avatar still updates in place;
- profile text handles long names with bounded width/elide;
- no extra recurring process exists just to obtain username.

### Suggested commit

`feat(dashboard): add profile rail and avatar hover motion`

---

## DV2.3 — MPRIS card with Cava waveform background

### Files

- `services/Cava.qml`
- `components/dashboard/DashboardMediaCard.qml`
- optionally new `components/dashboard/DashboardCavaWave.qml`

### Service change

Keep the current single Cava process and compatibility string, but expose numeric levels too.

Recommended public properties:

- `levels` / normalized values in range `0.0…1.0`;
- keep `bars` so `CavaGroup.qml` requires no visual rewrite;
- clear levels on process stop/media stop just as `bars` is cleared.

Do not spawn a Dashboard-specific Cava process.

### Media-card composition

Layer order:

1. card base;
2. low-opacity Cava waveform;
3. optional subtle scrim/gradient if required for readability;
4. artwork + metadata + controls;
5. hover/focus effects.

Waveform behavior:

- visible only while useful audio data is present;
- never shifts card layout;
- clipped to card radius;
- calm animation; no aggressive flashing;
- text/control contrast must remain readable over high peaks;
- idle/no-media state remains visually clean.

### Acceptance

- TopBar Cava still works;
- only one Cava process exists;
- Dashboard waveform reacts while music plays;
- play/pause/previous/next behavior unchanged;
- missing artwork and long titles still do not resize the card;
- stopping media clears/stops the waveform cleanly.

### Suggested commit

`feat(dashboard): render shared cava waveform behind mpris card`

---

## DV2.4 — Calendar day hover interaction

### Files

- preferably `components/top/CalendarGrid.qml` if the behavior is useful everywhere;
- otherwise add a Dashboard-only flag so TopBar calendar behavior does not change unexpectedly.

### Recommended API

Add a property such as:

- `dayHoverEnabled: false` by default;

Dashboard enables it.

### Day behavior

For valid day cells only:

- hover background/marker appears;
- subtle scale or lift is allowed;
- today keeps the strongest visual priority;
- blank leading/trailing cells do nothing;
- hover must not change grid sizing;
- month navigation remains unchanged.

Potential priority:

1. today;
2. hovered valid day;
3. normal day;
4. blank cell.

### Acceptance

- no calendar reflow on hover;
- 42-cell geometry remains stable;
- current-day marker still reads clearly;
- changing months does not leave stale hovered state;
- keyboard/focus behavior is not regressed.

### Suggested commit

`feat(dashboard): add calendar day hover feedback`

---

## DV2.5 — Monitor backend V2: mounted storage + GPU memory

Do backend/data model before redrawing the Monitor card.

### Files

- `src/core/backend/system/sysstats_snapshot.sh`
- `services/SysStats.qml`

### Keep existing guarantees

- one `SysStats` timer;
- 2000ms cadence unless there is evidence to change it;
- subscriber reference counting;
- no independent process per metric/card/row;
- CPU delta state resets when subscribers drop to zero.

### New data contract

Add a structured mount list, with root `/` first.

Each mount record should contain enough for UI/tooltips:

- target/mount point;
- source device if available;
- filesystem type;
- used percentage;
- optionally used/total bytes if obtainable without extra per-row subprocesses.

Filter out pseudo/temporary filesystems. The UI is for mounted storage devices, not `/proc`, `/sys`, `tmpfs`, `overlay`, etc.

Recommended inclusion policy:

- always include `/`;
- include other real block-device-backed mounts (`/dev/...`) such as separate `/home`, data drives, removable drives;
- dedupe by mount target;
- sort root first, then stable lexical target order.

### Transport format

Prefer one JSON object/array line from the snapshot helper for mount data rather than inventing delimiter parsing that breaks on spaces in mount names. `SysStats.qml` can parse that line with `JSON.parse`.

### GPU memory

Add:

- `gpuMemoryPercent`;
- `hasGpuMemory`.

Use reliable sources only:

- NVIDIA: derive from `nvidia-smi` in the same GPU probe call when possible;
- AMD/discrete DRM: use readable VRAM used/total sysfs files when available;
- unsupported/integrated cases: `N/A`.

Do not add a second GPU polling process if the information can be collected in the existing extended snapshot.

### Acceptance

Backend probes cover:

- root-only machine;
- root + separate `/home`;
- additional mounted data drive;
- removable drive if available;
- mount target containing spaces if practical;
- unsupported GPU;
- supported GPU util but unavailable VRAM;
- supported GPU util + VRAM.

### Suggested commit

`feat(sysstats): expose mounted storage and gpu memory metrics`

---

## DV2.6 — Monitor card V2 UI

### Files

- `components/dashboard/DashboardMonitorCard.qml`
- optional new components:
  - `DashboardMetricGauge.qml`
  - `DashboardStorageRow.qml`

### Card state

Local presentation state only:

- page `system` (default);
- page `gpu`.

Do not put this transient tab state into `UiState` unless a real cross-component requirement appears.

### Gauge page contract

#### System page

- Gauge 1: CPU %;
- Gauge 2: RAM %.

#### GPU page

- Gauge 1: GPU utilization %;
- Gauge 2: VRAM % or `N/A` neutral state.

### Page switching

- left/right arrow buttons as drawn in the sketch;
- arrows only replace/morph the **two circular gauges**;
- storage section below does not move or switch;
- use a short fade/slide or crossfade with shared HAnimation timings;
- keyboard-accessible if the card can receive focus.

### Storage section

Below the gauges:

- first row: `/`;
- subsequent rows: additional mounts;
- compact progress track + percent;
- show a bounded viewport if there are more mounts than fit;
- no card growth when drives are mounted/unmounted;
- mounting/unmounting updates the list on the next normal SysStats sample.

### Gauge visual rules

- clamp values 0–100;
- unsupported metric = neutral ring + `N/A`;
- no fake zero;
- animations react to value changes but do not continuously spin/pulse;
- numeric value remains legible inside/near each circle.

### Acceptance

- System↔GPU page switches only the gauge area;
- storage rows remain stable through page switch;
- live CPU/RAM changes animate correctly;
- unsupported GPU/VRAM is honest and visually neutral;
- mount add/remove does not resize the outer card;
- `SysStats.acquireExtended()` is still active only while Dashboard is active.

### Suggested commit

`feat(dashboard): redesign monitor with gauge pages and mount storage`

---

## DV2.7 — Dashboard-local tooltip system

### Goal

Provide real hover help without weakening the existing rule that TopBar tooltips disappear when an active panel opens.

### Recommended architecture

Create a Dashboard-local tooltip host instead of changing global TopBar tooltip gating in the first implementation.

Possible files:

- `components/dashboard/DashboardTooltipLayer.qml`
- `components/dashboard/DashboardTooltipTarget.qml` or a lightweight reusable helper

The layer should:

- own one tooltip at a time;
- use ~350–450ms show delay;
- clamp the bubble to Dashboard/screen bounds;
- prefer placement beside/below target and flip when near an edge;
- hide on target exit, Dashboard close, or page/morph close;
- avoid capturing pointer input;
- match Theme colors/radius/motion.

### Tooltip coverage

Useful targets, not noisy blanket coverage:

- Avatar: left click Back / right click Change avatar;
- Clock/date card: current date/time context if desired;
- media artwork/title: full title/artist when elided;
- previous/play/next controls;
- Calendar month controls/reset;
- Monitor System/GPU arrows;
- CPU/RAM/GPU/VRAM gauges with full metric names and unsupported reason;
- storage rows with source, mount point, filesystem and percent/size where available.

Calendar day cells need hover visuals, but do not require a tooltip on every date unless it proves useful in runtime.

### Acceptance

- tooltips work while `UiState.activePanel === "navigation"`;
- existing TopBar tooltip policy is unchanged;
- no tooltip survives Dashboard close;
- tooltips do not trigger Dashboard safe-zone close;
- no pointer interception/flicker when moving between target and tooltip visual.

### Suggested commit

`feat(dashboard): add scoped hover tooltips`

---

## DV2.8 — Integration polish, motion, and regression pass

### Files

Mostly Dashboard components; touch shared services only for confirmed issues.

### Motion policy

Use existing shared HAnimation timings/curves.

Recommended hierarchy:

- shell morph: existing `dashboardMorphProgress`;
- card reveal: existing delayed reveal, retuned only if required;
- Avatar hover: button-hover timing;
- Calendar hover: fast hover timing;
- monitor page switch: normal timing;
- Cava waveform: value interpolation only, no independent decorative animation;
- tooltip: short delayed fade/translate.

### Interaction conflicts to check

- Avatar grow vs safe zone/pointer ownership;
- Monitor ListView/wheel vs Navigation pointer evaluator;
- FileDialog returning focus to Dashboard;
- tooltips near shell edge;
- media control hover while Cava moves behind it;
- mount list updating while pointer is over a disappearing drive row;
- Dashboard closing mid-tooltip or mid-monitor-page transition;
- reversible Dashboard→Navigation morph while content animations are active.

### Suggested commit

`fix(dashboard): harden v2 motion focus and pointer integration`

---

## DV2.9 — Verification matrix + final docs

### Static checks

Run the project's normal checks:

```text
git diff --check
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

Plus shell validation for the changed backend helper.

### Runtime matrix

#### Geometry / shell

- open Dashboard from Navigation;
- close by Avatar left click;
- close by Escape;
- close by leaving 200px safe boundary;
- reopen during close morph;
- pointer pass-through outside safe zone;
- 1920×1080;
- 2560×1440;
- 1366×768;
- ultrawide;
- multi-monitor opening on each monitor.

#### Avatar/profile

- no avatar;
- valid avatar;
- hover grow;
- right-click chooser cancel;
- replace avatar;
- long username;
- reload/restart persistence.

#### Media/Cava

- no MPRIS player;
- paused player;
- playing audio;
- long title/artist;
- artwork present/absent;
- previous/play/next capability absent;
- Cava unavailable/fails;
- confirm exactly one Cava process.

#### Calendar

- hover valid dates;
- today hover;
- previous/next month;
- reset month;
- month with 28/29/30/31 days;
- hover state resets after month switch.

#### Monitor

- CPU/RAM live updates;
- System↔GPU page switch;
- unsupported GPU;
- GPU util only;
- GPU + VRAM;
- root only;
- multiple real mounts;
- mount/unmount while Dashboard is open;
- mount list overflow/scroll;
- unsupported values stay `N/A`.

#### Tooltip

- every declared target;
- fast pointer movement across targets;
- Dashboard closes while tooltip timer is pending;
- tooltip near right/bottom edge;
- tooltip never leaks into TopBar state.

#### Reload / WM smoke

Dashboard itself is WM-independent, but physical smoke should still be done on the supported Hikai sessions:

- Hyprland;
- Niri;
- MangoWM.

No WM backend refactor is part of this Dashboard work.

### Final report should record

- exact 50×50 measurements by tested output;
- SysStats process/timer behavior;
- Cava process count;
- supported GPU/VRAM backend evidence;
- mount filtering behavior;
- screenshots of System and GPU monitor pages;
- remaining known limitations.

### Suggested commit

`docs(dashboard): verify and finalize 50x50 v2`

---

# 3. Recommended execution order

```text
DV2.0  Contract/docs lock
  ↓
DV2.1  50×50 geometry + compact cluster
  ↓
DV2.2  Profile rail + Avatar hover
  ↓
DV2.3  Shared Cava numeric levels + MPRIS background
  ↓
DV2.4  Calendar hover
  ↓
DV2.5  SysStats backend: mounts + VRAM
  ↓
DV2.6  Monitor V2 UI
  ↓
DV2.7  Dashboard-local tooltips
  ↓
DV2.8  Integration hardening
  ↓
DV2.9  Runtime matrix + final docs
```

Do not give DV2.1–DV2.9 to an implementation agent as one giant task. Each batch should end with static checks and a short focused runtime probe before the next batch begins.

---

# 4. Scope boundaries / things not to rewrite

This Dashboard V2 should **not** trigger unrelated architecture churn.

Keep unless a test fails:

- Navigation state machine and `dashboardMorphProgress` model;
- Flare primitives;
- RoundedScreen integration;
- Avatar persistence backend;
- Media player selection semantics;
- TopBar Cava presentation;
- WM backends (Hyprland/Niri/MangoWM);
- notification system;
- Sidebar/HakuMenu/Wallpaper panels.

Avoid:

- a new system-monitor daemon;
- one `df` process per storage row;
- a second Cava process;
- fake GPU/VRAM values;
- filling the intentionally empty 50×50 space with unrelated widgets;
- resizing layout slots on hover;
- global tooltip rewrites before a Dashboard-local solution is proven.

---

# 5. Definition of DONE

Dashboard V2 is done only when all of the following are true:

1. shell is 50% × 50% on tested outputs;
2. safe-zone/mask logic follows the 50×50 geometry;
3. card cluster remains compact and sparse as in the sketch;
4. Avatar hover enlargement works without breaking click semantics;
5. profile/name treatment is present and bounded;
6. MPRIS displays the shared Cava waveform with no duplicate process;
7. Calendar day hover works without reflow;
8. Monitor defaults to CPU/RAM circular gauges;
9. arrows switch only gauge region to GPU/VRAM;
10. root and mounted storage rows remain visible/fixed across gauge page changes;
11. unsupported GPU/VRAM is `N/A`, not fake 0%;
12. useful Dashboard hover tooltips work while Navigation panel is active;
13. Dashboard close/reopen/morph/focus behavior has no regression;
14. static checks pass;
15. physical smoke passes on Hyprland, Niri, and MangoWM;
16. docs/style contract are updated to V2.

# HakuSpace Dashboard V2 — MPRIS / Monitor / Profile Rail Polish Plan

Status: **PLAN ONLY — do not implement unrelated redesigns**

Basis: current `hakuspace.zip` at commits `16bf5afb`, `77cbeeaf`, `dfcd0619` plus the supplied runtime screenshot.

## 0. Goal / visual contract

Keep the current Dashboard 50% × 50% shell and current 20px card layout. This batch is a **proportion and density polish**, not another Dashboard redesign.

Required outcomes:

1. MPRIS card must look visually balanced: larger album art, better placement of metadata, larger/better-positioned Prev/Play/Next controls.
2. Dashboard MPRIS must visibly render Cava in its background whenever media is playing, regardless of whether the TopBar center is currently in media mode.
3. Monitor card must use its available area better: larger gauges, larger metric text, larger navigation controls, and more legible storage rows/progress bars.
4. `--- The Hikaide ---` profile rail must be vertically centered in the available rail below the Avatar.
5. Preserve current behavior: 50×50 geometry, Calendar, media actions, System↔GPU switching, gauge/storage click toggles, tooltips, Avatar actions, and SysStats architecture.

## 1. Current-code findings

### MPRIS is undersized inside a ~row-1-height card

`DashboardMediaCard.qml` currently caps artwork at `76px`, uses `28×28` Previous/Next buttons, a `32×28` Play button, and vertically centers a compact metadata/control `Column`. This leaves noticeable unused vertical and horizontal visual mass in the card.

### Dashboard Cava component exists but the service policy prevents it from running reliably

`DashboardMediaCard.qml` already contains `DashboardCavaWave`, and `DashboardCavaWave.qml` reads `Cava.levels`.

The problem is `Cava.qml`:

```qml
readonly property bool shouldRun: Media.playing && CenterState.baseMode === "media" && available
```

Therefore Dashboard Cava disappears/never starts if the TopBar center is not in media mode. **Do not create a second Cava process.** Fix demand/lifecycle in the shared Cava singleton.

### Monitor hardcodes compact dimensions

`DashboardMonitorCard.qml` currently uses:

- `headerArea.height: 32`;
- `gaugeArea.height: 80`;
- two gauges at `diameter: 70`;
- `24×24` page arrows;
- storage rows at `28px` high with a `5px` progress track.

The row-2 card is much taller than this fixed gauge cluster, so the visual content feels small even though the card itself is large.

### Profile rail has no explicit usable height

`DashboardProfileRail.qml` is an `Item` with width only; its `Column` is anchored to the top. `DashboardSurface.qml` positions the rail below the Avatar but does not give it the remaining body height. The rotated Hikaide subtitle therefore cannot be truly vertically centered in its rail.

---

# 2. Atomic implementation batches

## DPOL.1 — Fix shared Cava demand before touching MPRIS visuals

### Files

- `services/Cava.qml`
- `components/dashboard/DashboardMediaCard.qml`
- `components/dashboard/DashboardSurface.qml`

### Required architecture

Keep exactly **one** `Process { command: ["cava", ...] }` in `Cava.qml`.

Add explicit Dashboard demand tracking to the singleton, following the same lifecycle discipline already used by `SysStats`.

Recommended minimal API:

```qml
property int _dashboardSubscribers: 0
readonly property bool dashboardRequested: _dashboardSubscribers > 0

function acquireDashboard() { ... }
function releaseDashboard() { ... }
```

Update policy to the equivalent of:

```qml
readonly property bool shouldRun:
    Media.playing
    && available
    && (CenterState.baseMode === "media" || dashboardRequested)
```

Do not remove existing TopBar behavior. Dashboard demand is an **OR**, not a replacement.

### Dashboard subscription lifecycle

Add `property bool active` to `DashboardMediaCard` and acquire/release Cava only on active transitions.

`DashboardSurface.qml` should pass Dashboard state to the Media card, e.g. `active: root.expanded` (or an equivalent lifecycle flag that is true while Dashboard is being used).

Requirements:

- no duplicate acquire on repeated bindings;
- release on deactivation;
- release on component destruction;
- no negative subscriber count;
- when both TopBar and Dashboard need Cava, the same process serves both.

### Acceptance

1. Play media, open Dashboard, then switch TopBar center away from media → Dashboard waveform keeps moving.
2. Switch TopBar back to media → TopBar Cava still works.
3. Close Dashboard while TopBar does not need Cava → Cava process stops according to existing policy.
4. No second Cava process is introduced.
5. Existing `bars`, `levels`, `audioVisible`, silence detection, and TopBar behavior do not regress.

### Suggested commit

`fix(cava): keep shared visualizer active for dashboard media`

---

## DPOL.2 — Rebalance the MPRIS card

### Primary file

- `components/dashboard/DashboardMediaCard.qml`
- minor visual tuning in `components/dashboard/DashboardCavaWave.qml` only if required

### Layout change

Do not keep the current “small Row + vertically centered compact Column” proportions.

Use a fixed artwork slot on the left and a right-side content area that fills the card height.

Recommended responsive dimensions:

```text
outer padding:       10–12px
art size:            clamp to roughly 80–88px at the current row-1 height
art/content gap:     10–12px
Prev / Next:         32×32px
Play / Pause:        38×38px
control spacing:     8–10px
```

Do not blindly hardcode `88`; derive it from card height so 1366×768 remains safe. A suitable contract is effectively:

```text
artSize = card height - vertical padding * 2
          capped around 88px
          with a sensible lower bound around 76–80px
```

### Placement

Recommended composition:

```text
┌─────────────────────────────────────────┐
│  ┌──────────┐  Title                    │
│  │          │  Artist / album           │
│  │ artwork  │                            │
│  │          │       ◀    ●    ▶         │
│  └──────────┘                            │
└─────────────────────────────────────────┘
```

- artwork vertically centered in the card;
- metadata belongs in the upper half of the right content area;
- control row belongs in the lower half, not immediately glued under the artist text;
- center the control group in the right content area rather than left-aligning it against the artwork edge;
- Play/Pause is the dominant control: larger filled/hover-muted circular button;
- Previous/Next remain slightly smaller and visually lighter;
- title and artist must still elide instead of pushing controls/artwork.

### Typography

Increase hierarchy slightly, without making MPRIS louder than the Clock card:

- title: around `Theme.fontSize + 1` / bold;
- artist: current or +1 logical px;
- control glyphs: about 17px for Prev/Next and 18–20px for Play/Pause.

Use responsive calculations/shared Theme values where possible.

### Empty/missing-art states

Preserve:

- `No media` / `Idle` behavior;
- placeholder music glyph;
- `canGoPrevious`, `canTogglePlaying`, `canGoNext` gating;
- existing media tooltips.

Disabled controls must not leave awkward layout holes. Keep slots stable and visually de-emphasize/disable unavailable actions rather than allowing the entire group to jump.

### Cava visual treatment

The waveform must be visible as a **background texture**, not as foreground controls.

Keep it behind all MPRIS content. Recommended:

- cover most/all card width;
- bars originate from card bottom;
- waveform opacity roughly `0.16–0.24` while active;
- preserve current accent-derived gradient;
- do not reduce title/control contrast;
- fade smoothly to zero when levels disappear;
- no extra Process or polling.

If the current 12 bars look too blocky after they begin working, adjust bar spacing/width only. Do not synthesize fake audio data.

### Acceptance

- current screenshot resolution: artwork and controls visually occupy the card instead of appearing undersized;
- long track + artist names do not overlap buttons;
- no-art track remains balanced;
- Previous/Play/Next retain correct actions and hover tooltips;
- Cava is visibly moving behind the card when media is playing even if TopBar center is clock/date/etc.;
- waveform does not obscure artwork/text/control legibility.

### Suggested commit

`feat(dashboard): rebalance mpris artwork controls and cava background`

---

## DPOL.3 — Scale Monitor content to the card instead of fixed 70px gauges

### Files

- `components/dashboard/DashboardMonitorCard.qml`
- `components/dashboard/DashboardMetricGauge.qml`
- `components/dashboard/DashboardStorageRow.qml`

### Principle

The card should remain the same size. Increase **content density and visual scale inside it**.

Do not rewrite Monitor semantics:

```text
System page: CPU + RAM
GPU page:    GPU + VRAM
storage:     persistent below gauges
```

Page switching must still replace only the two circular gauges.

### Responsive gauge sizing

Replace the fixed `diameter: 70` and `gaugeArea.height: 80` with a card-derived size.

Target at the supplied screenshot/card size:

```text
gauge diameter:      ~86–92px
gauge stroke:        ~6–7px
value text:          ~16–18px when showing %
metric label:        ~10–11px
page arrows:         ~28–30px square
gauge area height:   ~100–110px
```

Set a maximum so large displays do not produce giant circles; set a lower bound so 1366×768 remains legible.

A good sizing constraint must consider **both** card width and card height, so two gauges + arrows + gaps always fit.

### Gauge group placement

- center the two gauges as one visual group;
- keep left/right page arrows vertically centered against the gauge group;
- increase gap between the two gauges slightly if width permits;
- do not push the group so low that the storage area gets squeezed.

### Header

Use the existing header but make it proportionate to the enlarged content:

- title `Monitor` may grow ~1px;
- System/GPU pill ~22–24px high;
- keep pill right aligned;
- no new labels or redundant section headers.

### Storage section

The current rows are too visually thin relative to the card.

Target:

```text
row height:          ~30–34px
label/value font:    ~11–12px at current resolution
progress track:      ~6–7px
row spacing:         ~2–4px
```

Let the progress track consume the extra horizontal room. Keep value text right-aligned and preserve `% ↔ used` click behavior.

If there are more mounts than fit, `ListView` remains scrollable. Do not shrink every row simply to avoid scrolling.

### DashboardMetricGauge

Scale typography from `diameter` but keep alternate strings safe:

- `%` can be large;
- CPU GHz / RAM GB / VRAM GB / backend string must shrink only as needed;
- `N/A` stays centered;
- click toggle and tooltip behavior remain unchanged.

Do not fake missing GPU/VRAM data.

### Acceptance

- CPU/RAM circles are visibly larger and make better use of the upper half of Monitor;
- `%`, CPU/RAM labels, arrows, and storage values are readable at normal viewing distance;
- System↔GPU crossfade remains smooth;
- `% ↔ alternate metric` gauge click still works;
- storage `% ↔ used` click still works;
- 3 storage rows fit comfortably at the supplied screenshot size;
- additional rows scroll instead of causing clipping/overlap;
- GPU/VRAM unavailable states still render safely.

### Suggested commit

`feat(dashboard): scale monitor gauges and storage rows responsively`

---

## DPOL.4 — Vertically center the profile rail / Hikaide subtitle

### Files

- `components/dashboard/DashboardSurface.qml`
- `components/dashboard/DashboardProfileRail.qml`

### Fix the geometry contract first

Give `DashboardProfileRail` an explicit height equal to the usable remaining rail below the Avatar.

Conceptually:

```text
railTop    = avatarY + avatarDiameter + profileGap
railBottom = finalBodyBottom - bottomPadding
railHeight = max(0, railBottom - railTop)
```

Pass/set that height on `DashboardProfileRail`.

### Internal alignment

Do not anchor the content `Column` to `parent.top` anymore.

Vertically center the profile content inside the available rail:

- display name stays horizontally centered;
- rotated `--- The Hikaide ---` remains below the name in logical order;
- the combined name + vertical subtitle block is centered vertically in the remaining rail;
- long display names remain elided;
- the rotated subtitle must not overflow the Dashboard bottom or collide with Avatar.

The important visual acceptance is that the vertical Hikaide text no longer looks attached to the top of the leftover space.

### Suggested commit

`fix(dashboard): vertically center profile rail below avatar`

---

## DPOL.5 — Final runtime matrix and cleanup

### Static checks

Run:

```bash
git diff --check
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
./scripts/precommit_check.sh
```

No debug logs, temporary probes, screenshots, or backup files in the final diff.

### Runtime matrix

#### MPRIS / Cava

- media playing + TopBar center media;
- media playing + TopBar center changed away from media while Dashboard remains open;
- pause/resume;
- next/previous;
- player with no artwork;
- long title + long artist;
- close/reopen Dashboard while music remains playing;
- Quickshell reload while player is already playing;
- confirm one shared Cava process, not one per UI consumer.

#### Monitor

- System page CPU/RAM;
- GPU page GPU/VRAM;
- rapidly switch System↔GPU several times;
- click each gauge `% ↔ detail`;
- click each storage row `% ↔ used`;
- 1 mount / 3 mounts / more mounts than fit;
- no supported GPU / no VRAM metric;
- reopen Dashboard and verify SysStats subscription lifecycle.

#### Profile rail

- normal username;
- long display name;
- hover Avatar while checking no collision;
- verify Hikaide block remains vertically centered after Dashboard morph completes.

#### Responsive smoke

At minimum:

- current 1664×936 environment/screenshot geometry;
- 1920×1080;
- 1366×768 or another small logical output;
- one HiDPI/logical-scale setup if available.

### Cross-WM scope

Only perform physical smoke on Hyprland / Niri / MangoWM if available. **Do not modify WM workspace backends** for this Dashboard polish unless an independently reproducible WM regression is discovered.

### Final report

Add a short report containing:

- before/after screenshots;
- exact files changed;
- Cava lifecycle evidence;
- static-test output;
- runtime matrix result;
- any remaining limitation.

---

# 3. Explicit non-goals

Do **not** in this batch:

- change Dashboard 50% × 50% envelope;
- change the two-column Clock/MPRIS + Calendar/Monitor layout;
- redesign Calendar;
- add seek/progress/volume controls to MPRIS;
- add another Cava process;
- change the MPRIS backend/player selection policy;
- change SysStats polling architecture;
- add new GPU metrics beyond the current contract;
- rewrite Navigation/Flare;
- refactor Hyprland/Niri/MangoWM workspace code;
- introduce unrelated style-system abstractions.

# 4. Recommended execution order

```text
DPOL.1 shared Cava demand/lifecycle
    ↓
DPOL.2 MPRIS visual rebalance
    ↓
DPOL.3 Monitor responsive scaling
    ↓
DPOL.4 Profile rail vertical centering
    ↓
DPOL.5 runtime matrix + final report
```

Do not combine all changes into one large commit. If DPOL.1 fails, stop before visual polish because the missing Dashboard waveform is a lifecycle issue, not a drawing issue.

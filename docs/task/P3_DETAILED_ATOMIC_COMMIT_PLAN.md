# HakuSpace P3 — Detailed Atomic Commit Execution Plan V2
## Based on the 2026-10-08 Dashboard / Navigation / Sidebar / Settings / HakuMenu / Wallpaper mockups

> Rule: **one accepted part = one commit**.
>
> This file is intentionally execution-oriented. Product/style semantics live in:
>
> - `QUICKSHELL_STYLE_P3_MOCKUP_LOCKED.md`
> - `HAKUSPACE_QUICKSHELL_PLAN_P3_MOCKUP_LOCKED.md`

---

# 0. Mandatory loop

For every numbered task:

```text
1. reset/confirm last accepted commit
2. implement only the named task
3. run static checks
4. run the focused runtime probe
5. capture one useful screenshot where visual
6. review
7. commit
8. confirm working tree state
9. continue
```

Never carry an unaccepted visual experiment into the next task.

Recommended report:

```text
Task:
Base commit:
Files changed:
Diff stat:
Static:
Runtime:
Screenshot:
Known limitations:
Ready to commit:
```

After approval:

```text
Committed:
Working tree:
Next task:
```

---

# 1. Static gate

Before every product commit:

```bash
git diff --check
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

Run `qmllint` where supported.

---

# 2. Ordered commit list

### Rebase status against current Hikai implementation (Final tag: `p3-v2-final` / commit `426e5a39`)

> [!NOTE]
> Historical rebase snapshot at `64418615` successfully progressed through all milestones and is now fully certified at tag `p3-v2-final` (`426e5a39`).

| Item | Scope | Status | Notes / Commit reference |
|---|---|---|---|
| **A1** | Superseded experiments removal | **DONE** | Abandoned center-collar and old dual-front removed |
| **A2** | RoundedScreen chassis | **DONE** | Locked in `AppState.qml` (`t=4, r=20, c=#000000`), decoupled from classic conf (`64418615`) |
| **A3** | Shared frame bounds | **DONE** | Per-output frame metrics exposed in `FlareEdges.qml` / `AppState.qml` |
| **A4** | Standardize frame attachment | **DONE** | Bounded frame attachment helper standardized via `FlareEdges.qml` |
| **N1–N3** | Navigation radial controller | **DONE** | 3-region radial controller, equal 120° sectors (`7604c1f0`) |
| **D1–D7** | Dashboard mockup integration | **DONE** | 45% shell, avatar, clock, MPRIS, 45x45 layout, calendar, monitor info (`03b8453a`) |
| **S1–S3** | Sidebar left panel & actions | **DONE** | Audited and accepted in `P3_SIDEBAR_FINAL_REPORT.md` (2026-10-11) |
| **T1–T2** | Settings stub surface | **DONE** | Centered stub panel with T2 backdrop separation (`11bfdb75`, `08dfef20`) |
| **H1–H4** | HakuMenu shell & motion | **DONE** | Audited and accepted in `P3_HAKUMENU_FINAL_REPORT.md` (2026-10-11) |
| **G1–G3** | HakuMenu General | **DONE** | Audited and accepted in `P3_HAKUMENU_FINAL_REPORT.md` (2026-10-11) |
| **R1–R3** | HakuMenu Drun | **DONE** | Audited and accepted in `P3_HAKUMENU_FINAL_REPORT.md` (2026-10-11) |
| **C0–C15** | Core script frontend/backend split | **DONE** | Clean frontend/backend split (`ea0f5288`), no direct Rofi in backend |
| **M1** | HakuMenu Theme tab shell | **DONE** | Theme state region & tab shell stub; audited in `P3_HAKUMENU_FINAL_REPORT.md` |
| **M2** | Live palette switcher | **DEFERRED (P4.1)** | Real theme engine implementation deferred to P4.1 by design |
| **W1–W11** | Wallpaper carousel | **DONE** | Standalone carousel, native scan model, apply static/lively (`cccf6b21`, `1c4d2b1f`) |
| **P1–P6** | Frame attachment polish | **DONE / VERIFIED** | Tooltip, Tray, Popup, Center, OSD consume `FlareEdges`; frame attachment verified |
| **P7** | TopBar & calendar polish | **DONE** | Recorder isolated to recorder group (`8f21ac42`); Calendar accent fill & black text (`604638ea`) |
| **P3.11** | Remaining native migration | **DONE (classified)** | Power & Clipboard moved to P4; Drun/Wallpaper/Recorder native P3 DONE; Classic tooling retained where planned |
| **P3.12** | Multi-WM runtime matrix | **DONE / VERIFIED** | Hyprland, Niri, MangoWM, scale verification verified |
| **P3.13** | Cleanup and tag | **DONE** | Final tag `p3-v2-final` created (`426e5a39`) |

---

## Foundation

### A1 — DONE
Remove abandoned center-collar and old Wallpaper dual-front remnants.

Commit:

```text
p3(baseline): remove superseded visual experiments
```

### A2 — DONE
Lock continuous RoundedScreen chassis with single Quickshell source of truth.

- `AppState.qml` defines canonical `roundedScreenThickness: 4`, `roundedScreenRadius: 20`, `roundedScreenColor: "#000000"`.
- `RoundedScreen.qml` consumes these directly with three clear sections: A (visual drawing), B (input/click-through), C (edge/layout reservations).
- Decoupled completely from classic `rounded-screen.conf`, `rounded_screen_state`, and manager toggle.

Commit:

```text
refactor(frame): establish single source of truth for rounded screen chassis (64418615)
```

### A3 — DONE
Expose shared per-output frame bounds.

Commit:

```text
p3(geometry): expose shared frame bounds
```

### A4 — DONE
Add/reuse bounded frame attachment helper.

Commit:

```text
p3(geometry): standardize frame attachment
```

---

## Navigation

### N1 — DONE
Explicit per-screen Navigation lifecycle/state and Logo trigger.

Commit:

```text
p3(navigation): add explicit navigation state model
```

### N2 — DONE
Three-region radial visual from `navigation.png`.

Commit:

```text
p3(navigation): implement three-region radial visual
```

Gate:
- one screenshot;
- verify Dashboard/Sidebar/Settings labels/regions;
- no HakuMenu state mixed in.

---

## Dashboard

### D1 — DONE
Dashboard shell + reserved blank area only.

Commit:

```text
p3(dashboard): add mockup-locked dashboard shell (902c2045, 7067c902)
```

### D2 — DONE
Avatar visual + persistent selection.

Commit:

```text
p3(dashboard): add persistent dashboard avatar (e8c0be66, b7a2fe4c)
```

### D3 — DONE
Clock card.

Commit:

```text
p3(dashboard): add clock card (082da9d6)
```

### D4 — DONE
MPRIS controls + thumbnail card.

Commit:

```text
p3(dashboard): add mpris control card (860402f5)
```

### D5 — DONE
Calendar + month controls (45x45 layout and widget host).

Commit:

```text
p3(dashboard): add flare inset and navigation morph (11a9cae4, d2533818, ffbb1bbd)
```

### D6 — DONE
ROM/RAM/CPU/GPU monitor card + Calendar widget.

Commit:

```text
p3(dashboard): add calendar widget to host (a5ca3dbc)
```

### D7 — DONE
Dashboard layout/radius/spacing integration & monitor information card.

Commit:

```text
p3(dashboard): finalize dashboard integration (de134efd, 03b8453a)
```

Gate:
- compare only against `dashboard.png`;
- do not add extra widgets.

---

## Sidebar

### S1 — DONE
Pointer-state union / anti-flicker hover handoff.

Commit:

```text
p3(sidebar): add stable hover handoff (d63e2a7e, 4430691f)
```

### S2 — DONE
Rounded left Sidebar + circular dots + plus (`SidebarPanel.qml`, `SidebarSurface.qml`).

Commit:

```text
p3(sidebar): implement mockup visual (d63e2a7e)
```

### S3 — DONE
Action tiles and status strip stubs; dot/plus actions remain explicit stubs.

Commit:

```text
p3(sidebar): wire specified sidebar actions (stubs in place)
```

Unknown actions are not blockers; left as explicit stubs. Audited and verified in `P3_SIDEBAR_FINAL_REPORT.md`.

---

## Settings

### T1 — DONE
Settings stub surface exactly as current P3 scope.

Commit:

```text
p3(settings): add hikai settings stub (11bfdb75)
```

### T2 — DONE
Settings stub backdrop separation and refinement.

Commit:

```text
p3(settings): refine stub backdrop separation (08dfef20)
```

Gate:
- centered;
- radius consistency;
- `still working rn...`;
- no real settings implementation.

---

## HakuMenu shell

### H1 — DONE
Center-triggered lifecycle + focus/input cleanup.

Commit:

```text
p3(hakumenu): add center-triggered lifecycle (c6eb5358, 77aaca4c)
```

### H2 — DONE
Physical centering + equal-radius geometry & safe pointer-union auto close.

Commit:

```text
p3(hakumenu): lock centered equal-radius geometry (3e1b8048)
```

Gate:
- physical center X and height remain stable;
- General uses approved compact width while Drun/Theme use standard width;
- tab-to-tab width changes morph with dedicated resize curve;
- HakuMenu uses synchronized split layers: Top = visual-only Flare/background, Overlay = rounded body/content/input/focus.
- Fullscreen clients may cover the Top visual shell, but Overlay content remains visible and usable without geometry drift.
- Pointer-union auto-close works safely across TopBar/HakuMenu/outside with grace timer.

### H3 — DONE
General/Drun/Theme tab shell.

Commit:

```text
p3(hakumenu): add general drun theme tabs (06cf370e)
```

Gate:
- state area hidden except Theme;
- no TopBar-center silhouette redesign.

### H4 — DONE
Shared Hikai interactive-motion foundation and first migration.

Commits:

```text
p3(motion): add shared button morph primitives (fc4fc702)
p3(motion): migrate hakumenu tray and notifications (fc4fc702)
```

Gate:
- `ButtonMotion`, `MorphButton`, `MorphIconButton`, `SelectionPill` exist as reusable primitives;
- HakuMenu tabs use one moving selection pill;
- HakuMenu General/Drun rows and search focus have no instant interactive colour jumps;
- Tray rows/Back and Notification action buttons use the same motion profile;
- hover/press motion does not alter layout size;
- ordinary buttons do not reuse HakuMenu's bouncy open curve.

---

## HakuMenu General

### G1 — DONE
Audit `hm_general.sh` output.

Commit:

```text
p3(hakumenu): stabilize hm_general data contract
```

### G2 — DONE
General parser/model.

Commit:

```text
p3(hakumenu): add general data model
```

### G3 — DONE
General list rendering.

Commit:

```text
p3(hakumenu): render general list
```

---

## HakuMenu Drun

### R1 — DONE
Application model/search source (`DesktopEntries`).

Commit:

```text
p3(hakumenu): add drun application model
```

### R2 — DONE
Keyboard/pointer launch interaction.

Commit:

```text
p3(hakumenu): add drun interaction
```

### R3 — DONE
Route Hikai launcher facade/IPC to Drun tab.

Commit:

```text
p3(launcher): route hikai launcher to hakumenu drun
```

Classic must remain unchanged.

---

## Core script frontend/backend split — DONE

This refactor separates backend/domain commands from Classic presentation facades so Hikai does not depend on Classic Rofi scripts as its domain API.

Detailed execution spec:

```text
docs/task/P3_CORE_SCRIPT_FRONTEND_BACKEND_SPLIT_PLAN.md
```

Architecture rule:

```text
backend/domain = headless explicit commands
Classic frontend = Rofi / haku_pick presentation
facade = stable public command basename
```

Atomic commits:

```text
C0  plan/inventory — DONE
C1  core-script guardrails — DONE
C2  taskbar split — DONE
C3  waybar split — DONE
C4  theme mutation split — DONE
C5  rofi-theme split — DONE
C6  niri-animation split — DONE
C7  wallpaper split — DONE
C8  power split — DONE
C9  session-exit split — DONE
C10 recorder split — DONE
C11 clipboard split — DONE
C12 shell-switcher split — DONE
C13 shortcut split — DONE
C14 source-tree taxonomy/README — DONE
C15 final direct-Rofi audit — DONE (ea0f5288)
```

Gate:
- `theme_ctl.sh` is headless and explicit;
- wallpaper model/action contract is available independently of Rofi before W1;
- Classic public command behavior remains unchanged;
- no direct picker invocation exists in `src/core/backend/`;
- flattened `~/.local/bin` deployment has no basename collision/regression.

---

## HakuMenu Theme

### M1 — DONE
Theme-only right state region and tab shell stub.

Commit:

```text
p3(hakumenu): add theme state-region layout
```

### M2 — PLANNED
Theme live palette switcher / engine integration.

Commit:

```text
p3(hakumenu): mark theme tab as stub
```

Theme engine implementation is deferred by design (stub shell retained).

---

## Wallpaper carousel — DONE

Detailed audit and verification report: [`docs/task/P3_WALLPAPER_FINAL_REPORT.md`](file:///home/hakuimaku/hakuspace/docs/task/P3_WALLPAPER_FINAL_REPORT.md)

### W1 — DONE
Audit existing wallpaper model/action path.

Result:
- `wallpaper_ctl.sh` already exposes the QML-facing model/action contract required by W2–W5: structured static/lively lists, current/status, explicit apply, lively stop, and thumbnail preparation.
- JSON records already provide `id`, `kind`, `path`, `label`, `thumbnail`, and `selected`; no Rofi parsing is needed in Hikai.
- W1 normalization: static discovery now matches extensions case-insensitively and includes `.webp`, keeping the carousel model consistent with the existing random-wallpaper/static apply path.
- No carousel QML is added in W1.

Commit only for the discovery normalization above.

### W2 — DONE
Fixed physical center selection slot.

Result:
- HakuMenu Theme now hosts a native wallpaper carousel surface backed directly by `wallpaper_ctl.sh` JSON output.
- W2 renders only one stable 16:9 center slot; its geometry is derived from the available region, not thumbnail dimensions, so loading/aspect-ratio changes cannot move the physical center.
- The current wallpaper is preferred; if no record is marked selected, the first discovered item is used as the non-interactive W2 fallback.
- Static and lively records share the same center presentation. Navigation, side stacks, and apply actions remain intentionally deferred to W3–W5.
- The Theme wallpaper region is transparent so the deprecated large generic panel background does not return.

Commit:

```text
p3(wallpaper): add fixed center selection slot
```

### W3 — DONE
Stacked/overlapping left-right items. No big panel background.

Result:
- The W2 physical center slot remains fixed and keeps the selected/current record in front.
- Up to three neighboring wallpapers are rendered on each side as progressively smaller, dimmer overlapping layers behind the center card.
- Side-card geometry is derived only from the fixed center slot and neighbor depth, never from thumbnail dimensions, so asynchronous image loading cannot shift the carousel silhouette.
- W3 remains presentation-only: no click, arrow, wheel, or apply behavior is introduced; `selectedIndex` still resolves from the backend-selected record (or the first item fallback) until W4 owns navigation state.
- No generic wallpaper panel/background was added.

Commit:

```text
p3(wallpaper): add stacked side carousel
```

### W3.5 — Native Hikai entrypoints + standalone wallpaper debug layer

- `wallpaper_select.sh` now routes no-argument Hikai use to Quickshell IPC while Classic keeps the Rofi frontend.
- `hakumenu.sh` now routes Hikai to the native HakuMenu IPC while Classic keeps Rofi.
- Wallpaper carousel is detached from HakuMenu and hosted by a centered standalone `WallpaperPanel` overlay for W4/W5 debugging.
- No navigation/apply semantics are added here; W4/W5 remain responsible for those behaviors.

### W4 — DONE
Arrow + wheel navigation, one `selectedIndex`.

Result:
- `WallpaperCarousel` now owns exactly one mutable `selectedIndex`; backend `selected` only seeds that index after refresh.
- Left/Right keys move the standalone Hikai wallpaper panel selection without applying wallpaper.
- Mouse/touchpad wheel over the carousel moves the same `selectedIndex`.
- Navigation is clamped at the first/last model item; side-card placement continues to derive from offsets around `selectedIndex`.
- W4 does not execute wallpaper mutation; Enter/apply remains W5.

Commit:

```text
p3(wallpaper): add carousel navigation
```

### W5 — DONE
Enter applies selected item.

Result:
- Enter/Return applies exactly the record currently at the fixed center slot; no side-card label or backend-selected flag is reparsed for dispatch.
- Static records call `wallpaper_ctl.sh apply-static <path>` and lively records call `wallpaper_ctl.sh apply-lively <path>`.
- Apply is guarded while a previous mutation is still running, preventing repeated Enter presses from spawning concurrent wallpaper mutations.
- Successful apply closes the standalone wallpaper layer; reopening refreshes the model so backend `selected` reseeds the carousel from the newly active wallpaper.
- Failed apply leaves the layer open and reports the backend error to the Quickshell log.

Commit:

```text
p3(wallpaper): apply selected item on enter
```

### W6 — DONE
Thumbnail/performance hardening.

Implementation notes:
- Enter/Return closes the standalone wallpaper layer immediately after the apply process is accepted; wallpaper/accent mutation continues asynchronously in the existing `Process`.
- The carousel instantiates image content only for the center slot plus the bounded three-card stack on each side (maximum seven decoded previews).
- `Image.sourceSize` is capped near the rendered card dimensions so full-resolution static wallpapers are not decoded at native resolution just to draw small previews.
- Preview loading remains asynchronous and card geometry is stable while a source is pending; the existing card surface acts as the placeholder.
- Reopening during an in-flight successful apply refreshes the model when the backend finishes so `selected` state catches up safely.

Commit:

```text
p3(wallpaper): harden carousel thumbnail loading
```

### W7 — DONE
Persistent model/delegate cache to remove navigation thumbnail jank.

Result:
- `WallpaperCarousel` no longer rotates wallpaper records through seven shared visual slots. Each model record owns a stable delegate identity, so changing `selectedIndex` changes slot geometry/state rather than replacing every visible `Image.source`.
- The visible deck remains bounded to center + three cards per side. A two-record prefetch margin is kept on each side, so at most eleven previews are active and normally only one new edge preview starts loading per navigation step.
- Preview `sourceSize` is fixed from the physical center slot rather than each delegate's changing side scale; navigation therefore does not request a new decode size for the same wallpaper as it moves between deck positions.
- The static/lively model cache survives standalone panel close/reopen for the lifetime of the Quickshell component; reopening does not automatically rerun both backend list commands or rebuild the thumbnail set.
- Successful apply no longer refreshes the model immediately. The UI already owns the chosen `selectedIndex`, so the cached delegates stay intact while the backend mutation completes asynchronously.
- W7 intentionally does not add animation or change the current card styling. Static/Lively mode separation remains W8.

### W8 — DONE
Static/Lively split + floating morph switch.

Result:
- Static and Lively are now separate presentation modes backed by their already cached backend lists; the active carousel never concatenates the two kinds.
- Each kind remembers its own selected index. Switching Static → Lively → Static restores the previous position instead of resetting navigation.
- Both delegate sets stay alive after first visit, preserving W7 thumbnail identity/cache across repeated mode switches. No backend list query is triggered by changing kind.
- A two-slot floating switch is centered above the hero wallpaper. One shared accent `SelectionPill` morphs between Static and Lively; the buttons only change presentation mode and never apply wallpaper.
- Initial mode follows the backend-selected wallpaper when one exists; otherwise Static is preferred when available.
- W8 intentionally does not add carousel motion/opening animation or change wallpaper-card styling.

#### W8 interaction polish — DONE

- `Ctrl+Left` switches directly to Static and `Ctrl+Right` switches directly to Lively; plain Left/Right keep navigating wallpapers inside the active kind.
- Each half of the floating switch owns its lane, and the pointer handler now lives inside the same visual item that expands. The interactive region therefore scales/grows with the painted button instead of remaining lane-sized while the button extends beyond it.
- The selected button uses a fixed `8px` corner radius and intentionally grows beyond the black floating shell on every side while morphing between modes; its overflow area remains interactive.
- Hover scales the complete button visual and label together, and the transformed visual itself is the hit target. Moving into the expanded edge no longer drops hover or produces a visible-but-dead click zone.

### W9 — DONE
Navigation motion + opening fade/reel + directional motion trail + final shadow-only card style.

Result:
- Stable W7 delegates now animate between deck targets (`x/y/width/height/opacity`) instead of teleporting when `selectedIndex` changes. The center slot remains physically fixed.
- Opening runs as an explicit fade + horizontal rear-card reel phase. Rear cards first share one scrolling row, then settle into their stacked deck geometry so the opening reads as a reel rather than a simple offset/fade.
- During navigation/opening, two low-opacity cached-image trails follow the movement direction to create a lightweight motion-blur impression without introducing a live blur shader. One transparent outer slot per side stays alive so navigation can animate incoming/outgoing cards instead of popping at the visible edge.
- Wallpaper cards have **no border and no rounding**. Depth now uses one compact shadow per card; the earlier large stepped shadow stack was removed after runtime review because it read as visible layers rather than a natural shadow.
- Pointer/keyboard navigation and apply are gated until the opening reel reaches `ready`; Escape remains available at the panel level.
- Runtime tune W9.1 strengthened the reel topology and reduced the shadow footprint after video review.
- W9.2 changed the hero timing after runtime review: the center wallpaper now begins opening together with the rear reel instead of waiting for the reel to settle.
- W9.3 replaced the compact hard shadow with one soft blurred `MultiEffect` shadow per card while retaining square cards with no border/rounding.

### W10 — DONE
Circular center reveal for the selected hero wallpaper.

Result:
- The center wallpaper is revealed through a true alpha mask whose opaque circle expands from the physical center until its diameter covers the card corners.
- The reveal begins at the same time as W9's opening fade/reel, honoring the W9.2 runtime decision that the hero must not wait behind the rear-card animation.
- The card geometry never grows: only the circular mask diameter changes, so the physical center slot remains fixed throughout the opening.
- The expensive mask effect only exists visually during opening. After reveal completion the original cached card surface is shown directly again.
- The center shadow is withheld while the mask is partial so no rectangular shadow/source leaks outside the circular reveal; it returns when the hero is fully exposed.
- Navigation/apply semantics are unchanged and remain gated by the W9 opening state until the complete opening sequence reaches `ready`.

### W11 — DONE
Interaction/performance hardening + animated close lifecycle.

Result:
- Closing is no longer an instant `PanelWindow` teardown. `UiState.closeWallpaper()` now requests a close while the wallpaper surface remains owned by the same screen; `WallpaperPanel` finalizes state only after the carousel signals that its exit sequence finished.
- Exit phase 1 gathers both side stacks toward the fixed physical center slot. W11.1 replaces the vortex with a centered zoom-out + fade: the gathered carousel scales down as one surface while opacity falls to zero, with no rotation/orbit.
- Escape, IPC close/toggle and successful Enter apply all use the same animated close path. Enter still starts wallpaper apply asynchronously before the close animation, so backend mutation is never placed on the animation critical path.
- A second toggle during close cancels the teardown and restores the already-warm carousel instead of destroying/recreating the surface mid-animation. Screen destruction still uses a force-close path so stale `UiState` ownership cannot survive monitor removal.
- Navigation now has a small 55 ms retarget guard. Rapid key-repeat/touchpad bursts therefore retarget the existing stable delegates without producing an unbounded transition queue or backend/model reload.
- Static/Lively models, W7 stable delegates/prefetch and W10 hero-mask steady-state optimization remain unchanged.

Wallpaper UX sequence W1-W11 is certified DONE in `P3_WALLPAPER_FINAL_REPORT.md`. Multi-WM runtime matrix verification is scheduled for R6.

Gate:
- compare against `wallpaper-change.png`;
- old dual-front Flare design must not return.

---

## Existing shell polish — DONE

Surfaces consume shared `FlareEdges` / `AppState` frame metrics; audited and verified in R4:
- TooltipLayer: `maxTooltipWidth` bounds against `FlareEdges.thickness * 2`, anchored at `FlareEdges.topOriginY`.
- TrayMenuPanel (`FlarePanelWindow`): anchored to `FlareEdges.topOriginY` with `FlareEdges.thickness` bounds.
- NotificationPopup: dual layer (Top layer `FlareSurface` + Overlay content layer) attached to `FlareEdges.topOriginY` and `FlareEdges.getBounds`.
- NotificationCenterPanel: anchored to `FlareEdges.topOriginY` with `FlareEdges.thickness` bounds and `Theme.hugRadius` flare.
- NotificationCenterContent: roomier header spacing, taller body, solid `Theme.accent` fill on Clear button.
- LevelOsdOverlay: anchored to `FlareEdges.topOriginY`, span constrained by `FlareEdges.thickness` and `Theme.largeRadius + 8`.
- LevelOsdContent: fixed symmetric side slots (`Theme.fontSize * 3.7`) ensure optical/physical center stability across `0%`, `9%`, `10%`, `99%`, and `100%`.

### P1 — DONE
Tooltip → RoundedScreen attachment (consumes `FlareEdges`). Audited and verified in `TooltipLayer.qml`.

### P2 — DONE
Tray → RoundedScreen attachment (consumes `FlareEdges`). Audited and verified in `TrayMenuPanel.qml` and `FlarePanelWindow.qml`.

### P3 — DONE
Notification popup → RoundedScreen attachment (consumes `FlareEdges`). Audited and verified in `NotificationPopup.qml`.

### P4 — DONE
Notification Center attachment (consumes `FlareEdges`). Audited and verified in `NotificationCenterPanel.qml`.

### P5 — DONE
Notification Center spacing / taller body / Clear accent treatment. Audited and verified in `NotificationCenterContent.qml`.

### P6 — DONE
OSD attachment (consumes `FlareEdges`). Audited and verified in `LevelOsdOverlay.qml`.

### P7 — DONE (Refinement & layout)
Compact OSD + stable percentage slot + physical centering; plus accepted TopBar/Calendar refinements:
- Recording state isolated to recorder group only (`8f21ac42`).
- Calendar current-day marker given breathing room with solid accent fill and black text (`604638ea`).

Commits:

```text
refactor(topbar): keep recording state in recorder group only (8f21ac42)
fix(calendar): add breathing room to current-day marker (604638ea)
p3(osd): stabilize compact centered layout
```

---

## Remaining migration — DONE (classified)

The broad `src/core` frontend/backend separation (C0–C15) is complete. The remaining migration audit (R5) classified each candidate surface:
- **Power (`shutdown.sh`):** Move to P4 (backend `power_ctl.sh` headless; no P3 mockup exists).
- **Clipboard (`clipboard_menu.sh`):** Move to P4 (backend `clipboard_ctl.sh` headless; native UI in P4).
- **Launcher/Menu facades:**
  - `hakumenu.sh` / Drun: native P3 implementation (DONE).
  - `wallpaper_select.sh` / Wallpaper: native P3 implementation (DONE).
  - `record.sh`: native P3 implementation (DONE).
  - `change_theme.sh`: Move to P4.
  - `exit.sh`: Move to P4.
  - `rofi_theme_switcher.sh`, `taskbar_manager.sh`, `waybar_manager.sh`: Intentionally keep Classic-only.

---

## Runtime matrix verification — DONE

Runtime matrix verified across supported environments:
- **Compositors:** Hyprland, Niri, MangoWM backends operational with independent event models and safe Labwc fallback in `services/WM/WM.qml`.
- **Classic regression:** All public facades maintain backward compatibility with Classic Rofi frontends while routing Hikai to Quickshell native IPC.
- **Scale:** 1.0x and fractional display scaling adapt smoothly via logical coordinate models and `FlareEdges` frame metrics.

---

## Final cleanup and canonical docs — DONE

- Temporary diagnostics audited: zero temporary hooks or extraneous logs in `src/`.
- Precommit checks and QML syntax verification passing 100%.
- Canonical documentation updated and aligned to current implementation.
- Milestone tagged: `p3-v2-final`.

# 3. Visual review gates

Use only one of:

```text
PASS
METRIC_TUNE_ONLY
TOPOLOGY_WRONG
FUNCTIONAL_FAIL
```

Rules:

### PASS
Commit immediately.

### METRIC_TUNE_ONLY
- freeze topology;
- tune at most 3 metrics in the next pass;
- no unrelated files.

### TOPOLOGY_WRONG
- stop;
- compare to the specific mockup;
- revise the local component plan before editing again.

### FUNCTIONAL_FAIL
- reproduce;
- fix behaviour before visual polish.

If two consecutive `METRIC_TUNE_ONLY` rounds fail to converge, stop tuning and revise the geometry model. Do not burn tokens indefinitely.

---

# 4. Mockup-specific gates

## Navigation
Source:

```text
navigation.png
```

Pass if:
- reads as one radial controller;
- three regions are legible;
- not a rectangular menu.

## Dashboard
Source:

```text
dashboard.png
```

Pass if:
- avatar occupies Navigation origin while Dashboard active;
- Clock / MPRIS / Calendar / ROM-RAM-CPU-GPU cluster exists;
- unused Dashboard area remains intentionally empty.

## Sidebar
Source:

```text
sidebar.png
```

Pass if:
- Sidebar appears immediately from Sidebar hover;
- pointer can reach the Sidebar without flicker-collapse;
- controls are circles;
- body is left-attached, not a generic drawer.

## Settings
Source:

```text
setting.png
```

Pass if:
- centered inner panel;
- equal radius feel;
- only stub content.

## HakuMenu
Source:

```text
hakumenu.png
```

Pass if:
- physically centered;
- three tabs;
- equal radius family;
- main list region;
- state region only in Theme;
- no horizontal jump when changing tab.

## Wallpaper
Source:

```text
wallpaper-change.png
```

Pass if:
- no large panel background;
- selected item stays at fixed center;
- side list reads as stacked/overlapping;
- arrows/wheel move selection;
- Enter applies.

---

# 5. Full runtime gates after major checkpoints

After Navigation + Dashboard + Sidebar + Settings:

```text
tag p3-v2-navigation-pass
```

After HakuMenu:

```text
tag p3-v2-hakumenu-pass
```

After Wallpaper:

```text
tag p3-v2-wallpaper-pass
```

After shell polish:

```text
tag p3-v2-shell-polish-pass
```

Before final:

```text
Hyprland
Niri
MangoWM
Classic regression
1.0x
fractional scale
reload/restart
```

Then:

```text
tag p3-v2-final
```

---

# 6. Stop conditions

Stop and report before more experimentation if:

- a component starts diverging from its assigned mockup;
- more than 3 visual metrics are repeatedly tuned;
- accepted foundation code must be rewritten;
- a diff touches unrelated surface families;
- a new abstraction affects multiple accepted components;
- user-visible behaviour must be invented because the mockup is silent;
- Classic semantics would change;
- a WM-specific workaround is about to enter shared UI code.

Fallback to the last accepted commit is preferred over accumulating speculative fixes.


### W9.2 — Center joins opening reel fade

Runtime feedback removed the delayed center-card appearance from W9.1. The selected center wallpaper now participates in the panel fade immediately while the rear reel is scrolling/settling. No extra hold/reveal delay remains in W9; W10 remains reserved for the later circular-mask reveal treatment.

### W9.3 — Soft blurred card shadow

Runtime feedback confirmed the compact W9.1 shadow footprint was preferable, but the flat Rectangle still read as a hard offset block. W9.3 replaces that block with one `QtQuick.Effects.MultiEffect` shadow per card. Cards remain square with no border or rounding; only a modest soft blur/vertical offset is used, with the center card slightly stronger than side cards. Motion trails remain the lightweight cached-image approximation from W9 and are intentionally unchanged.

### W11.2 — center click apply + rapid-navigation performance

- Center wallpaper now has the same apply action as Enter/Return; accepted apply requests close through the existing animated close lifecycle.
- Navigation transition shortened to 190 ms and input coalescing widened to 85 ms.
- Geometry/opacity Behaviors are active only for the bounded prefetch window instead of every wallpaper delegate in the active model.
- During rapid navigation, side-card blurred shadows are suspended and only the two nearest side cards draw a single motion trail; the richer two-trail presentation remains for the one-shot opening reel.
- Backend/model/cache contracts are unchanged.

### N3 — DONE / runtime accepted 2026-10-10
Final Navigation integration and morph polish.

Accepted contract:
- one three-sector radial controller at the physical top-left; Dashboard / Sidebar / Settings map to explicit `handoff-*` states;
- selected sector uses `Theme.accent`; hovered non-selected sector uses neutral gray, expands to 1.2x, and its icon expands to 1.4x;
- sectors are rounded annular wedges with icons, dark separators, and no bright white outline;
- a tight persistent Flare backing hugs the controller and aligns its right/bottom contour with shared `RoundedScreen` / `FlareEdges` geometry;
- Navigation lives on `WlrLayer.Overlay` with `ExclusionMode.Ignore` and `exclusiveZone: 0`, so TopBar exclusive geometry cannot displace it;
- Logo morphs into the Navigation hub on open. On close, sectors collapse into the hub first, then the Logo returns to its stable circular TopBar footprint while the Flare retracts into the RoundedScreen seam;
- TopBar Logo layout stays fixed and is visually hidden while the Navigation proxy owns the morph; Workspaces, WindowTitle, and future non-Logo left modules slide right to clear the radial surface;
- keyboard selection, Enter activation, Escape close, Logo toggle, per-screen ownership, rapid reopen, and Sidebar handoff were runtime-verified;
- temporary `notify-send` activation probes were removed during final cleanup.

P3 milestone is certified **DONE** and tagged `p3-v2-final`. Next milestone: **P4 — Selected Classic Parity & Additional Native Surfaces** (starting with P4.0 Scope lock & P4.1 HakuMenu Theme M2 live integration).

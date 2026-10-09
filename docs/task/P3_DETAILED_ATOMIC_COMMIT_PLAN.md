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

## Foundation

### A1
Remove abandoned center-collar and old Wallpaper dual-front remnants.

Commit:

```text
p3(baseline): remove superseded visual experiments
```

### A2
Lock continuous RoundedScreen.

Commit:

```text
p3(frame): lock RoundedScreen chassis
```

### A3
Expose shared per-output frame bounds.

Commit:

```text
p3(geometry): expose shared frame bounds
```

### A4
Add/reuse bounded frame attachment helper.

Commit:

```text
p3(geometry): standardize frame attachment
```

---

## Navigation

### N1
Navigation lifecycle/state only. No final radial styling yet.

Commit:

```text
p3(navigation): add explicit navigation state model
```

### N2
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

### D1
Dashboard shell + reserved blank area only.

Commit:

```text
p3(dashboard): add mockup-locked dashboard shell
```

### D2
Avatar visual + persistent selection.

Commit:

```text
p3(dashboard): add persistent dashboard avatar
```

### D3
Clock card.

Commit:

```text
p3(dashboard): add clock card
```

### D4
MPRIS controls + thumbnail card.

Commit:

```text
p3(dashboard): add mpris control card
```

### D5
Calendar + month controls.

Commit:

```text
p3(dashboard): add calendar card
```

### D6
ROM/RAM/CPU/GPU monitor card.

Commit:

```text
p3(dashboard): add monitor information card
```

### D7
Dashboard layout/radius/spacing integration.

Commit:

```text
p3(dashboard): finalize mockup layout
```

Gate:
- compare only against `dashboard.png`;
- do not add extra widgets.

---

## Sidebar

### S1
Pointer-state union / anti-flicker hover handoff.

Commit:

```text
p3(sidebar): add stable hover handoff
```

### S2
Rounded left Sidebar + circular dots + plus.

Commit:

```text
p3(sidebar): implement mockup visual
```

### S3
Only if specified actions exist: wire them.

Commit:

```text
p3(sidebar): wire specified sidebar actions
```

Unknown actions are not blockers; leave them explicit stubs.

---

## Settings

### T1
Settings stub surface exactly as current P3 scope.

Commit:

```text
p3(settings): add hikai settings stub
```

Gate:
- centered;
- radius consistency;
- `still working rn...`;
- no real settings implementation.

---

## HakuMenu shell

### H1
Center-triggered lifecycle + focus/input cleanup.

Commit:

```text
p3(hakumenu): add center-triggered lifecycle
```

### H2
Physical centering + equal-radius geometry.

Commit:

```text
p3(hakumenu): lock centered equal-radius geometry
```

Gate:
- physical center X and height remain stable;
- General may use the approved 95%-of-standard width while Drun/Theme use standard width;
- tab-to-tab width changes morph with the dedicated resize curve, not the shell-open bounce.
- HakuMenu uses synchronized split layers: Top = visual-only Flare/background, Overlay = rounded body/content/input/focus.
- Fullscreen clients may cover the Top visual shell, but Overlay content remains visible and usable without geometry drift.

### H3
General/Drun/Theme tab shell.

Commit:

```text
p3(hakumenu): add general drun theme tabs
```

Gate:
- state area hidden except Theme;
- no TopBar-center silhouette redesign.

### H4
Shared Hikai interactive-motion foundation and first migration.

Commits:

```text
p3(motion): add shared button morph primitives
p3(motion): migrate hakumenu tray and notifications
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

### G1
Audit `hm_general.sh` output.

If no code change: report only.

If contract hardening is needed:

```text
p3(hakumenu): stabilize hm_general data contract
```

### G2
General parser/model.

Commit:

```text
p3(hakumenu): add general data model
```

### G3
General list rendering.

Commit:

```text
p3(hakumenu): render general list
```

---

## HakuMenu Drun

### R1
Application model/search source.

Commit:

```text
p3(hakumenu): add drun application model
```

### R2
Keyboard/pointer launch interaction.

Commit:

```text
p3(hakumenu): add drun interaction
```

### R3
Route Hikai launcher facade/IPC to Drun tab.

Commit:

```text
p3(launcher): route hikai launcher to hakumenu drun
```

Classic must remain unchanged.

---

## Core script frontend/backend split

This refactor is inserted before real HakuMenu Theme / Wallpaper action wiring so Hikai does not depend on Classic Rofi scripts as its domain API.

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

Run C0–C7 from the dedicated plan before wiring Theme or Wallpaper UI to script actions. C8–C15 may follow immediately or after the next UI milestone, but no new Hikai feature may introduce a dependency on a direct-Rofi backend script.

Atomic commits:

```text
C0  plan/inventory
C1  core-script guardrails
C2  taskbar split
C3  waybar split
C4  theme mutation split
C5  rofi-theme split
C6  niri-animation split
C7  wallpaper split
C8  power split
C9  session-exit split
C10 recorder split
C11 clipboard split
C12 shell-switcher split
C13 shortcut split
C14 source-tree taxonomy/README
C15 final direct-Rofi audit — DONE (C9 destructive exit remains NEEDS VERIFY)
```

Gate before returning to HakuMenu Theme:

- `theme_ctl.sh` is headless and explicit;
- wallpaper model/action contract is available independently of Rofi before W1;
- Classic public command behavior remains unchanged;
- no direct picker invocation exists in `src/core/backend/`;
- flattened `~/.local/bin` deployment has no basename collision/regression.

---

## HakuMenu Theme

### M1
Theme-only right state region.

Commit:

```text
p3(hakumenu): add theme state-region layout
```

### M2
Theme stub content/status.

Commit:

```text
p3(hakumenu): mark theme tab as stub
```

No theme engine implementation.

---

## Wallpaper carousel

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

Wallpaper UX sequence W1-W11 is functionally complete. Final runtime gate remains the user-visible close-motion check plus the existing multi-WM/reload checkpoint before the P3 wallpaper tag.

Gate:
- compare against `wallpaper-change.png`;
- old dual-front Flare design must not return.

---

## Existing shell polish

### P1
Tooltip → RoundedScreen attachment.

```text
p3(anchor): attach tooltips to rounded frame
```

### P2
Tray → RoundedScreen attachment.

```text
p3(anchor): attach tray menu to rounded frame
```

### P3
Notification popup → RoundedScreen attachment.

```text
p3(anchor): attach notification popup to rounded frame
```

### P4
Notification Center attachment.

```text
p3(anchor): attach notification center to rounded frame
```

### P5
Notification Center spacing / taller body / Clear accent treatment.

```text
p3(notifications): polish center spacing and clear action
```

### P6
OSD attachment.

```text
p3(anchor): attach level osd to rounded frame
```

### P7
Compact OSD + stable percentage slot + physical centering. Icon, track and percentage must be optically centered as one group inside the capsule.

```text
p3(osd): stabilize compact centered layout
```

---

## Remaining migration

The broad `src/core` frontend/backend separation is now specified in:

```text
docs/task/P3_CORE_SCRIPT_FRONTEND_BACKEND_SPLIT_PLAN.md
```

Any remaining Hikai direct-Rofi caller migration after C0–C15 still follows the original rule: one feature/caller family per commit, never one giant migration batch.

---

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

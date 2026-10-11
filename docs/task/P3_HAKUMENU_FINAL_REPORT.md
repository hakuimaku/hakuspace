# P3 HakuMenu — Final Report

Status: **DONE / audited and accepted — 2026-10-11**

## Final visual/interaction contract

- **Source / Reference:** `hakumenu.png`.
- **Trigger & Placement:**
  - Anchored at the physical top-center of each output.
  - Physical center X is invariant: `outputWidth / 2` across all modes and animations.
  - Activated by hovering/clicking TopBar center trigger or via IPC / keyboard shortcut (`Super+R`).
- **Layer architecture:**
  - **Top layer (`WlrLayer.Top`):** Dedicated visual-only Flare shell. Owns concave ears and background silhouette; empty input mask and no keyboard focus.
  - **Overlay layer (`WlrLayer.Overlay`):** Interactive content shell. Owns rounded body, search input, list views, and keyboard focus. Fully functional over fullscreen clients.
- **Segmented tab controller:**
  - Three tabs: **General**, **Drun**, and **Theme**, driven by `Motion.SelectionPill` and `Motion.MorphButton`.
  - Arrow keys (Left / Right) cycle tabs; Tab switching morphs width smoothly without re-triggering open bounce.
  - **General tab:** Compact width (38% output width). Action list populated from headless `hm_general.sh` data contract. Keyboard navigation, activation, and clean dismiss.
  - **Drun tab:** Standard width (40% output width). Direct Quickshell `DesktopEntries` integration, real-time query filtering, Up / Down arrow selection, Enter / click application launching. Hikai launcher facade (`Super+R`) routes here.
  - **Theme tab:** Standard width with state region (42% output width). Layout stub matching mockup with dedicated right-hand state region. Full theme engine deferred by design.
- **Lifecycle & Pointer auto-close:**
  - Unified safe envelope (`insideSafeUnion`) encompasses trigger, flare, body, and margin.
  - `closeGraceTimer` (`HAnimation.fast`, ~120 ms) prevents boundary stutter and accidental closing when crossing seams.
  - Pointer leaving the union envelope starts the grace timer; re-entering cancels dismissal.
  - Outside click dismisses immediately; Escape key closes from any focused element and releases focus.
  - Quickshell destruction handler cleans up active screen ownership.

## Static validation

```text
QML syntax: PASS
git diff --check: PASS
Flare geometry tests: PASS
precommit_check.sh: PASS
core-script boundary checks: PASS
```

## Milestone status

P3.5 (HakuMenu shell), P3.6 (General), P3.7 (Drun), and P3.8 (Theme stub) are marked **DONE**. Real theme engine integration (M2) remains PLANNED for future milestones.

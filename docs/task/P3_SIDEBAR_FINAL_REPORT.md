# P3 Sidebar — Final Report

Status: **DONE / audited and accepted — 2026-10-11**

## Final visual/interaction contract

- **Source / Reference:** `sidebar.png`.
- **Origin / Expansion:** Left-edge elongated rounded lobe reached from Navigation radial controller (`handoff-sidebar`, sector 90° → 210°).
- **Hover handoff:** Pointer entering the Navigation Sidebar sector immediately expands the Sidebar surface via an invisible interaction bridge (`bridgeHit`), eliminating flicker.
- **Pointer-state union:** Sidebar remains open while pointer is within `sector ∪ bridge ∪ body ∪ ear` (`insideRegionB`), reinforced by a 100 logical px lateral safe zone (`insideSidebarSafeZone`).
- **Return / Dismissal:**
  - Returning upward into Navigation Region A cleanly retracts the Sidebar while leaving Navigation open.
  - Moving laterally beyond the safe zone (`x > sidebarSafeWidth`) or below the safe height (`y > sidebarSafeHeight`) closes both Navigation and Sidebar reliably.
  - Escape closes Navigation and Sidebar immediately, releasing input focus.
- **Visual geometry:**
  - Attached flush to the physical left edge / RoundedScreen border.
  - Bottom flare foot connects smoothly into RoundedScreen border via `FlareEdges.thickness`.
  - Top flare ear wraps seamlessly into the circular navigation shell.
  - Morph animation uses `HAnimation.normal` (200 ms) with `HAnimation.shellCurve` on expand, and `HAnimation.fast` / cubic easing on retract.
- **Controls & Actions:**
  - Contains two circular option dots and one circular plus (`+`) control matching `sidebar.png`.
  - Option controls feature clean neutral idle and subtle hover states.
  - Controls remain explicit stubs in accordance with the specification; no unrequested actions or speculative semantics are invented.
- **Layer & Compositor integration:**
  - Operates on `WlrLayer.Overlay` with `ExclusionMode.Ignore` and `exclusiveZone: 0`.
  - Input pass-through is preserved outside active surface and safe-zone boundaries.
  - Independent per-screen lifecycle and instance ownership.
  - TopBar hide/show and Quickshell reload cause no seam artifacts or orphaned state.

## Static validation

```text
QML syntax: PASS
git diff --check: PASS
Flare geometry tests: PASS
precommit_check.sh: PASS
core-script boundary checks: PASS
```

## Milestone status

P3.3 (Sidebar S1–S3) is marked **DONE**.

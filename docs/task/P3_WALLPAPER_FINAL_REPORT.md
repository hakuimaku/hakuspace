# P3 Wallpaper Carousel — Final Report

Status: **DONE / audited and accepted — 2026-10-11**

## Final visual/interaction contract

- **Source / Reference:** `wallpaper-change.png`.
- **Surface & Layer Architecture:**
  - Standalone full-screen Overlay (`WlrLayer.Overlay`, `WlrKeyboardFocus.Exclusive`) hosted in `WallpaperPanel.qml`.
  - No generic background panel or intrusive scrim; clean transparent backdrop.
  - Transparent pass-through input mask; pointer input restricted strictly to `carouselHost` and the floating `modeSwitchHitRegion`.
  - Fixed physical center slot (16:9 aspect ratio) with dimensions derived strictly from container bounds, ensuring geometry is immune to thumbnail aspect ratios or asynchronous load delays.
- **Deck Structure & Card Presentation:**
  - Up to 3 overlapping cards per side (`sideDepth = 3`) with progressive geometric scaling and horizontal offset.
  - Clean rectangular cards with no border or corner radius, matching the approved mockup.
  - Soft blurred shadow per card using `MultiEffect` (`#ff000000`, 0.30 opacity at center, blurred footprint), replacing harsh block shadows.
  - Bottom metadata badge on the center card displaying wallpaper label and mode icon (`󰋩` for static, `󰕧` for lively).
- **Opening & Hero Reveal Sequences:**
  - Two-stage parallel opening animation:
    1. Surface fade-in accompanied by horizontal rear-card reel sweep settling into stacked deck positions.
    2. Circular center reveal: center hero card revealed via true alpha mask (`MultiEffect` mask with expanding circular geometry from physical center).
  - Center shadow suppressed until circular mask covers card corners, preventing premature rectangular shadow artifacts.
- **Model & Delegate Caching (W7 Architecture):**
  - Persistent delegate identity per record; navigation updates slot properties (`x`, `y`, `width`, `height`, `opacity`) instead of mutating `Image.source`.
  - Bounded prefetch window: active previews restricted to center + `prefetchDepth = 5` (maximum 11 active decoded thumbnails).
  - Capped thumbnail decode: `sourceSize` fixed to rendered slot dimensions with `decodeOverscan = 1.12`, avoiding memory bloat or OOM on high-resolution image sets.
  - Model cache persists across panel open/close/reopen cycles; no redundant backend list operations.
- **Static vs Lively Mode Separation (W8):**
  - Distinct presentation modes backed by separate backend lists (`list-static`, `list-lively`).
  - Independent position tracking: switching modes preserves the respective `selectedIndex`.
  - Centered floating mode switch with accent-highlighted `SelectionPill` and smooth hover scale.
  - Dedicated shortcuts: `Ctrl+Left` selects Static, `Ctrl+Right` selects Lively; plain `Left`/`Right` navigates wallpapers within current mode.
- **Navigation, Apply & Animated Lifecycle (W4, W5, W9, W11):**
  - Navigation: Keyboard arrow keys (`Left`/`Right`), pointer wheel (`WheelHandler`), or direct pointer click on cards.
  - Input coalescing & throttle guard: 85 ms interval guard prevents scene-graph flooding during rapid key repeat or wheel bursts; directional trails restricted to near cards during motion.
  - Apply: `Enter`/`Return` or clicking physical center card dispatches `wallpaper_ctl.sh apply-static` / `apply-lively` asynchronously.
  - Animated close: Immediate trigger upon apply acceptance, Escape key, or outside dismissal:
    1. Phase 1: side decks collapse toward the fixed center slot (250 ms `InOutCubic`).
    2. Phase 2: gathered deck scales down and fades out towards center (340 ms `InCubic` / `InQuad`).
  - Second toggle / cancel support: reopening or toggling during close animation cancels teardown smoothly via `cancelCloseAnimation` and restores warmed state without recreation jank.
  - Destruction safety: `Component.onDestruction: UiState.forceCloseWallpaperIfScreen(modelData.name)`.
- **Classic Compatibility:**
  - `wallpaper_select.sh` maintains dual routing: Classic invokes `wallpaper_rofi.sh`, Hikai routes to native Quickshell IPC (`haku_qs_ipc wallpaper toggleDefault`).
  - Headless backend `wallpaper_ctl.sh` serves both environments cleanly without Rofi dependencies.

## Verification matrix (W1–W11)

| Check | Milestone | Description | Result |
| :--- | :--- | :--- | :--- |
| **W1** | Contract audit | Structured JSON model (`wallpaper_ctl.sh`), case-insensitive discovery, `.webp` support | **PASS** |
| **W2** | Center slot | Fixed physical 16:9 center slot derived from screen metrics; no generic background panel | **PASS** |
| **W3** | Stacked deck | Overlapping side stacks (depth 3), stable silhouette during async loading | **PASS** |
| **W3.5** | Standalone host | Detached standalone `WallpaperPanel.qml` overlay; facade routing via `wallpaper_select.sh` | **PASS** |
| **W4** | Navigation | Keyboard `Left`/`Right`, mouse wheel, single `selectedIndex` | **PASS** |
| **W5** | Apply action | `Enter`/click apply via headless `wallpaper_ctl.sh`; guarded against concurrent dispatch | **PASS** |
| **W6** | Loading hardening | Bounded prefetch window, asynchronous decode, non-blocking background apply | **PASS** |
| **W7** | Delegate caching | Stable delegates by record index; no thumbnail rebuild on navigation step | **PASS** |
| **W8** | Mode split | Static/Lively split, floating switcher, `Ctrl+Left`/`Ctrl+Right` shortcuts | **PASS** |
| **W9** | Motion & reel | Reel opening sequence, directional motion trails, soft blurred shadows, rectangular styling | **PASS** |
| **W10** | Hero reveal | Center-out circular alpha mask reveal on opening; steady-state shader bypass | **PASS** |
| **W11** | Animated close | Centered gather + zoom-out exit, second-toggle interrupt safety, 85 ms throttle guard | **PASS** |

## Static validation

```text
QML syntax check: PASS
git diff --check: PASS
precommit_check.sh: PASS
Core-script boundary check: PASS
```

## Milestone status

Milestone **P3.9 (Wallpaper carousel)** and all verification items **W1–W11** are certified **DONE**.

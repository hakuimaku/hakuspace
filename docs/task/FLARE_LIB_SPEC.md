# Flare Library Specification

Shared edge-hugging effect for tooltip and panel surfaces.

Current status: L1 and L2 are implemented. L3 remains **IMPLEMENTED / VERIFY** for tooltip lifecycle, edge geometry at different radius/thickness and scale, and multi-monitor behavior. L4 is **PLANNED**; `FlareWindow.qml`, `FlareDemo.qml`, and `docs/flare.md` do not exist yet.

## 1. Purpose

The flare algorithm is currently embedded in `TooltipLayer.qml`: span
resolution, edge snapping, hugging factors, ears, feet, and retargeted
animation. Extract it into a reusable library so the existing tooltip and
future panels can share exactly the same effect:

- expand toward the Topbar when an anchor is close to an edge;
- hug the Rounded Screen safe area;
- morph continuously when the anchor or content changes;
- keep content, geometry, and motion independent.

Potential consumers include menus, wallpaper pickers, launchers, power menus,
and the notification center.

### 1.1 Scope

This phase defines and implements:

1. the pure geometry module;
2. the visual surface;
3. the motion controller;
4. the content crossfade/unload layer;
5. the `FlareHost` facade;
6. the Rounded Screen edge provider;
7. the tooltip migration and geometry tests.

### 1.2 Non-goals

This library does not own:

- tooltip timing, hover handling, or text;
- panel-specific state machines;
- window creation, resizing, or positioning;
- content layout or line breaking;
- the future full-screen panel window (`FlareWindow`, planned for M4).

The library must not contain tooltip-specific names or logic such as
`TooltipManager`, `hover`, or `text`.

## 2. Design constraints

1. **Single responsibility.** Math, visual rendering, motion, and content
   loading are separate layers.
2. **No window dependency.** Components are ordinary QML `Item`s and can be
   placed in any suitable window. The library must not use `PopupWindow` or
   resize a window at runtime.
3. **Canonical coordinates.** Geometry uses:
   - `u`: along the attached edge;
   - `v`: away from the attached edge.

   V1 maps `u = x`, `v = y` and supports `attach: Top`. Other attachments are
   visual transforms only; the math does not change.
4. **Token-driven dimensions.** Radii, dimensions, and animation curves come
   from `Theme.flare*`, `Theme.barColor`, and `HAnimation`. Do not add
   library-local magic constants.
5. **Safe failure.** Pure functions accept malformed input without throwing;
   they return finite, safe values.
6. **Testability.** Geometry tests must run without Wayland.

## 3. Architecture

```text
                    +----------------+
 anchor/content --->|   FlareHost    |<--- bounds
                    +-------+--------+
                            |
          +-----------------+-----------------+
          v                 v                 v
   +-------------+   +-------------+   +-------------+
   | FlareContent|   | FlareMorph  |   | FlareSurface|
   | load/crossfade   | target/motion | draw shape  |
   +-------------+   +-------------+   +-------------+
                            |
                    +-------v--------+
                    | FlareGeometry  |
                    | pure functions |
                    +----------------+

 FlareEdges supplies safe bounds from AppState and Rounded Screen state.
```

### 3.1 Files

```text
components/flare/
  FlareGeometry.js       Pure geometry functions (.pragma library)
  FlareSurface.qml       Body, ears, and feet; no state or animation
  FlareMorph.qml         Target calculation and motion controller
  FlareContent.qml       Ping-pong content loaders and crossfade
  FlareHost.qml          Public facade assembling the layers
  qmldir                 Type declarations, when required

services/
  FlareEdges.qml         Singleton providing safe horizontal bounds

scripts/
  test_flare_geometry.js Geometry tests runnable with node

docs/
  flare.md               Public API and panel usage documentation
```

## 4. Public API

`FlareHost` is the only component consumers should need.

```qml
FlareHost {
    anchorItem: <Item>          // Item the surface attaches below/near
    shown: <bool>               // Consumer-owned show/hide intent
    content: <Component>        // Content component
    contentProps: ({ ... })     // Properties assigned to the content item
    contentKey: <var>           // Reload/crossfade identity
    maxWidth: 360
    attach: FlareHost.Top        // V1: Top only

    // Optional override; otherwise supplied by FlareEdges.
    bounds: ({ start: ..., end: ... })

    // Outputs:
    // start, end, height, hugging
    // signal settled()
}
```

`FlareHost` must only assemble `FlareContent`, `FlareMorph`, and
`FlareSurface`. It must not contain timers, hover handling, or consumer state.

## 5. Geometry contract

`FlareGeometry.js` receives all inputs explicitly and reads no global state.

### 5.1 `resolveSpan`

```js
resolveSpan({
    anchorStart, anchorEnd,
    contentW, padX, minW, maxW,
    bounds: { start, end },
    snap
}) -> { start, end }
```

Algorithm:

1. Center a width of `clamp(contentW + padX, minW, maxW)` on the anchor.
2. If `start < bounds.start + snap`, set `start = bounds.start` and keep
   `end` unchanged. This expands toward the edge without shifting content.
3. If `end > bounds.end - snap`, set `end = bounds.end` and keep `start`
   unchanged.
4. Ensure the span is at least the requested width where the bounds allow it.
5. Clamp the final span to `bounds.start <= start` and `end <= bounds.end`,
   including when `maxW` is wider than the screen.

### 5.2 `hugFactors`

```js
hugFactors(start, end, { bounds, rf }) -> { kS, kE }
```

```text
kS = clamp((start - bounds.start) / rf, 0, 1)
kE = clamp((bounds.end - end) / rf, 0, 1)
```

When `rf <= 0`, return finite safe factors and never divide by zero.

### 5.3 `pieces`

```js
pieces({ start, end, height, kS, kE }, { r, rf })
```

Returns the four piece transforms and the two body corner radii:

| Piece | Position | Scale |
| --- | --- | --- |
| Start ear | `u = start - r` | `kS * min(1, v / r)` |
| End ear | `u = end` | `kE * min(1, v / r)` |
| Start foot | `u = start`, `v = height` | `(1 - kS) * min(1, v / rf)` |
| End foot | `u = end - rf`, `v = height` | `(1 - kE) * min(1, v / rf)` |

The ear origin is the connecting corner. The start ear's trailing edge must
remain at `start`; it must not overlap the body.

```text
radiusStart = r * kS
radiusEnd   = r * kE
```

### 5.4 Motion helpers

```js
durations(movingTowardStart, D, trailFactor)
    -> { startMs, endMs }

needsRetarget(previous, next, eps)
    -> boolean
```

The leading edge uses `D`; the trailing edge uses `D * trailFactor`.
`needsRetarget` returns true only when a target difference is greater than
`eps`.

## 6. Layer contracts

### 6.1 `FlareSurface.qml`

Responsibilities:

- draw one body `Rectangle`;
- draw four fixed `Shape`s using `CurveRenderer`;
- translate and scale pieces from `FlareGeometry.pieces`;
- expose `default property alias content: body.data`;
- keep the body clipped to its content;
- use `Theme.barColor` by default.

Inputs are `start`, `end`, `height`, `bounds`, `r`, `rf`, and `color`.

The body rounds its bottom corners using
`bottomLeftRadius` and `bottomRightRadius` (verify Qt >= 6.7).
`CurveRenderer` support must be verified for Qt >= 6.6.

This file must contain no `Behavior`, `Animation`, `Timer`, or state logic.
It must not use `Canvas` or regenerate paths while the surface moves.

### 6.2 `FlareMorph.qml`

Inputs:

- `anchorItem`;
- natural `contentSize`;
- `shown`;
- `bounds`;
- `minW`, `maxW`, `padX`, `padY`, and `snap`.

Outputs:

- animated `start`, `end`, and `height`;
- `hugging`;
- `settled()` signal.

Behavior:

1. Compute targets with `FlareGeometry.resolveSpan`.
2. Recompute when the anchor, content size, or anchor position/width changes.
3. Use `Connections` only while `shown`; batch updates with `Qt.callLater`.
4. Prefer final anchor dimensions such as `implicitWidth` over an animating
   `width` when available.
5. On initial show, set `start` and `end` directly and animate only `height`
   from zero.
6. On hide, animate `height` to zero before emitting `settled()`.
7. While an animation is running, update its target instead of creating
   overlapping animations.
8. Restart only when `needsRetarget` is true and at least about 60 ms have
   elapsed since the previous restart. The default spatial epsilon is 2 px.
9. Use `HAnimation.spatialCurve` for span movement and
   `HAnimation.moduleCurve` for height.
10. Auto-hide when `anchorItem` is destroyed or not visible.

### 6.3 `FlareContent.qml`

Responsibilities:

- manage two ping-pong loaders, A and B;
- accept `content`, `contentProps`, and `contentKey`;
- crossfade only when `contentKey` changes;
- update `contentProps` in place when the key is unchanged;
- measure natural dimensions once per content change and expose
  `naturalWidth` and `naturalHeight`;
- unload the hidden loader after a crossfade or `settled()`;
- unload both loaders after they have been hidden for about 2 seconds.

`maxWidth` is passed through `contentProps.maxWidth`. The content component,
not the library, decides line breaks.

### 6.4 `FlareEdges.qml`

This singleton is the only layer that knows about Rounded Screen margins.

```text
rounded = AppState.roundedScreenState
          && AppState.roundedScreenThickness > 0
t       = rounded ? AppState.roundedScreenThickness : 0
bounds  = { start: t, end: windowWidth - t }
```

Future top/bottom margins may be added here when panels attach to other edges.

## 7. Tooltip integration

After migration, `TooltipLayer.qml` is a thin composition layer:

```qml
TooltipLayer {
    FlareHost {
        anchorItem: TooltipManager.current
                    ? TooltipManager.current.target : null
        shown: TooltipManager.shown
               && TooltipManager.activeBar === <bar of this layer>
        content: TooltipManager.current
                 ? (TooltipManager.current.component || textComp) : null
        contentProps: ({
            text: ...,
            maxWidth: 360,
            props: ...
        })
        contentKey: TooltipManager.current
                    ? TooltipManager.current.target : null
        maxWidth: 360
    }
}
```

`TooltipManager` keeps only its time/state machine (`show`, `hide`, `warm`,
and `activeBar`). It must not calculate geometry.

Acceptance checks:

```sh
grep -rnE "kL|kR|bottomLeftRadius|snap|ear|foot" components/ services/
```

Matches for flare implementation are allowed only under
`components/flare/`. Tooltip rendering must remain visually equivalent to the
approved version, including edge hugging, while fixing the known left-ear,
foot-position, and width-limit issues.

## 8. Future panel support

Menus and other panels use the same `FlareHost` with a different
`anchorItem`, `content`, `contentKey`, and `maxWidth`. A panel owns one
content `Component` and one `FlareHost`; it does not draw its own background,
round its own corners, or implement edge hugging.

Large panels will eventually use `FlareWindow.qml` (M4):

- fixed-size transparent `PanelWindow` covering the workspace below the bar;
- `exclusionMode: Ignore`;
- input mask limited to the flare body;
- no runtime window resizing.

Because the bar and panel may be separate windows, verify the seam at the
Topbar edge with `Theme.barColor` and `barH` at 1.25x and 1.5x scale.

For `attach: Left`, `Right`, or `Bottom`, transform the visual item containing
the body and pieces. Keep content untransformed and leave
`FlareGeometry.js` unchanged.

## 9. Verification

### 9.1 Geometry tests

`scripts/test_flare_geometry.js` runs with `node`. Since `.pragma library` is
not valid Node syntax, the test must strip that line and load the module with
`new Function`.

If Node is unavailable, use `qmltestrunner6` with a `TestCase` importing
`FlareGeometry.js` and record that tool in the report.

Required cases:

- left and right snapping expands while retaining the opposite edge;
- `maxW` larger than the screen is clamped safely;
- `kS` and `kE` at `0`, `0.25`, `0.5`, and `1`;
- left/right symmetry;
- ears and feet at `k = 0`, `0.5`, and `1`;
- the start ear's connecting edge remains at `start`;
- `null`, `NaN`, and other malformed inputs;
- `rf = 0`, with no division by zero.

Record the real command and output in the implementation report.

### 9.2 Dev demo

Add `components/flare/dev/FlareDemo.qml`, loaded only when
`HAKU_FLARE_DEMO=1` through `LazyLoader` and `Quickshell.env`.

The demo must:

- attach to the Logo;
- toggle from a click;
- show six items in a panel about 200 px tall;
- use a larger `maxWidth` than the tooltip;
- use no `TooltipManager`.

Do not import it from default `TopBar.qml` or `shell.qml`. If it exceeds the
bar's 160 px tooltip area, document the boundary; do not resize the bar window
to hide the issue.

## 10. Delivery order

Stop and provide a diff for review after each step.

| Step | Work | Acceptance |
| --- | --- | --- |
| L0 | Complete blocking cleanup from `TOOLTIP_TT3_REVIEW.md`. | Clean status and no debug junk. |
| L1 | Add `FlareGeometry.js` and its Node test. | Pure module; tests pass with real output. |
| L2 | Add all flare layers and migrate `TooltipLayer`. | Equivalent rendering; clean geometry grep. |
| L3 | Complete tooltip controls, portal state, payloads, metrics, `R × t`, and multi-monitor handling. | Review items B4–B9, C, and D addressed. |
| L4 | Add the dev demo and `docs/flare.md`. | Demo is opt-in and docs include a menu example. |

## 11. Pitfalls

- Do not reintroduce tooltip vocabulary into `components/flare/`.
- Keep math out of QML bindings; put it in `FlareGeometry.js`.
- Keep all animation in `FlareMorph.qml`.
- Do not hardcode dimensions, radii, durations, or colors.
- Keep `Theme.barColor` as the single background-color source.
- Keep Rounded Screen calculations inside `FlareEdges.qml`.

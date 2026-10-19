# Hikai Native Dock implementation report

Date: 2026-10-19 (Asia/Ho_Chi_Minh). Baseline: `d5b053f9`.

Status: **IMPLEMENTED core Dock; PARTIAL final physical acceptance**.
The full plan's Definition of Done is not claimed. The user's subsequent style
request adds hover lift before the remaining physical checks; those checks remain open.

## Delivered behavior

| Requirement | Implementation | Validation |
| --- | --- | --- |
| Existing taskbar ON/OFF contract | `AppState.taskbarManualState` watches the existing file; missing state is OFF. No `dock.enabled` setting and no Waybar process changes. | PASS: real `taskbar_ctl.sh --toggle` updates all fixture outputs live; deployed Niri Dock enabled through the same controller, shell IPC responds `pong`, no legacy taskbar process spawned. |
| Shared Classic/Hikai pins | `taskbar_pins_ctl.py` reads and edits `~/hakucfg/config/taskbar-pin-apps`; ordered image modules normalize into `TaskbarPins.qml`. | PASS: list/add/remove/move/reload, duplicate no-op, reserved menu, JSONC strings/comments/trailing commas, desktop launch metadata, atomic replacement/failure cleanup, managed symlinks and adjacent alias removal. |
| Pin preservation and error recovery | Narrow text edits preserve unrelated blocks/comments. Shared image blocks survive removal. Backend diagnostics are exposed and logged; QML retains the last valid model. | PASS: external edit reload, malformed JSONC keeps last-known-good model, subsequent valid edit recovers. Comments inside a modified modules array are reformatted with that array. |
| Settings v4 | `visibilityMode`, `exclusiveSpace`, `iconSize`, `hoverLift`, `hoverScale`; strict types, 32–72 px icons in 4 px steps, 0–48 px lift and 0–100% enlargement. V1–V3 migrate in memory without read-side writes. | PASS: backend validation, previous settings preservation, actual slider controls, live preview, Discard, Apply, Reload, Reset and migration tests. |
| Running applications | `ToplevelManager`, exact/heuristic/startupClass desktop resolution, grouped windows, stable keys, pins merged before unpinned running apps. | PASS: real 0/1/2-window lifecycle, pure model cases for fallback IDs, heuristic/startupClass, deduplication, close and ordering. All applications are shown on each output. |
| Launch/activate/cycle | DesktopEntry execution first; stored Waybar command only when metadata is unavailable. Recent focus survives a layer-shell click clearing activation. | PASS: stopped fixture pin launches, pointer clicks cycle A → B, rapid click handling, no duplicate pinned/running icon. |
| Indicators and labels | Full-accent dots through five windows; five dots plus remaining count above five; tooltip has exact window count and appears immediately. | IMPLEMENTED; 1/2-window runtime and model counts covered. Larger counts need visual smoke. |
| Bottom Dock and motion | Borderless trapezoid with straight slanted sides, rounded top corners and small concave bottom flares; 24 px horizontal padding, zero bottom padding, a 2 px artwork-to-dot gap, center-seed morph and bounded scrolling. Hover, pressed and focus states have no background. Open/close durations are 360/224 ms (10%/30% shorter). Content follows RoundedScreen's side/bottom reserved bounds; the trigger stays at the physical edge. | PASS: runtime sizing/retargeting and frame attachment assertions; motion uses shared HAnimation tokens. |
| Autohide and input | Middle 20% bottom trigger; shared SafeZoneController, morph/target/headroom envelope, grace cancellation; transparent area click-through. | PASS: virtual-pointer events on Labwc and Mango nested, and on the actual Niri session. Left/right edges do not open; center opens; leave closes; re-entry cancels close. |
| Always mode | Pointer exit does not close the Dock; switching to autohide outside the envelope closes immediately. | PASS: runtime and actual pointer tests. |
| Direct pinning | Right-click toggles Pin/Unpin through the shared backend, without a popup. | PASS: direct pin/unpin before and after hover, running item retained and reserved menu excluded. |
| App termination | Middle-click sends SIGTERM to compositor-reported app PIDs and descendants. Saved Exit RAM threshold requires a second middle-click in a warning tooltip. Leaving, Escape or another action cancels. | PASS: disposable-process backend tests, headless/current-Niri input confirmation/cancellation, and real Niri PID lookup plus confirmed SIGTERM against a disposable window. |
| App Menu | Existing `UiState.openHakuMenu(screenName, "drun")`; no second launcher. | PASS: pointer click routes to the correct output/mode; showing Dock preserves existing transient panel ownership. |
| Mounted drives | Reuses `SysStats.acquireExtended()`; filters root/system mounts and opens storage paths with `gio open`. | PASS: injected mount/filter and pointer dispatch fixtures. Real removable-device insertion/ejection still needs hardware smoke. |
| Trash | Fixed rightmost item opens `trash:///` through `gio open`. | PASS: pointer dispatch fixture. Empty/full icon status is DEFERRED (D6b); no mount/eject manager added. |
| Stable exclusive space | Top-layer frame reservations precede the Bottom-layer Dock reservation. Frame visuals cancel the Dock's inward offset using shared fixed height; the physical rails stay at the output edges. | PASS: frame dimensions stay fixed, maximized clients reserve Dock height above the border, and reveal leaves client geometry stable on Labwc. Earlier geometry also passed Niri/Mango nested and physical Hyprland. |
| Multiple outputs/hotplug | One Dock per screen, shared models, output-local trigger and menu routing, balanced stats subscriptions. Null screen is handled during delegate teardown. | PASS: two headless outputs plus off/on of HEADLESS-2; returning output acquires exactly one subscription. Real cable hotplug/fractional scaling remains pending. |
| Hover effects | Settings sliders control lift and upward enlargement with smooth neighboring influence and shared motion tokens. Defaults preserve 14 px lift and original icon size; zero disables each effect independently. Slots/dots stay fixed; clipping bounds, hit areas and menu anchors follow enlarged artwork. | PASS: Labwc/current Niri pointer checks for zero/maximum effects, peak/neighbor influence, stable slots/width, clipping bounds, raised hit area, enlarged anchors and Discard. |

## Runtime evidence

Quickshell **0.3.2**. See [D0 probe](HIKAI_DOCK_D0_PROBE.md) for the source gate.

| Environment | Protocol source | Model/settings/reservation harness | Pointer acceptance |
| --- | --- | --- | --- |
| Hyprland 0.56.2, original physical session | PASS | PASS | D0 activate source PASS; complete Dock pointer suite not run before session switch. |
| Niri 26.04, nested | PASS | PASS | Initial runs failed at trigger during fixture investigation; superseded by the successful physical Niri trace, not recorded as a nested PASS. |
| Niri 26.04, current physical eDP-1 session | PASS | Source/model behavior also exercised by pointer suite | PASS: full input suite, including fullscreen, launch, App Menu, pin/cycle, drive and Trash dispatch. |
| MangoWM 0.18.0, nested Wayland | PASS | PASS | PASS: full input suite. Primary-session smoke remains pending. |
| Labwc, two isolated headless outputs | PASS through real fixtures | PASS, including simulated hotplug | PASS: full input suite. |

The subsequent style update passed the full repository check and expanded pointer
suite on Labwc and the current Niri session. The suite previews a 6 px frame border
and verifies Dock attachment, peak/neighbor lift, stable layout, raised hit areas,
context traversal and autohide. The installed shell was reloaded and IPC returned
`pong`. These results do not extend the earlier Mango/Hyprland visual coverage.

The frame-order regression reproduced a 65 px frame shrink when Dock exclusive
space was enabled. Frame reservations now precede the Dock, and frame visuals
cancel its offset. Labwc and nested Niri checks keep the frame at physical edges,
verify client work-area changes across exclusive ON/OFF and manual OFF, and cover
output removal/return. The TopBar/RoundedScreen pixel matrix and Dock input suite
also pass. The installed Niri shell was reloaded without changing saved settings.

The final surface redesign replaces the giant-flare ears with a trapezoid.
Its straight slanted sides widen the base, two quadratic curves round the top
vertices, and small concave flares join the sides to the bottom attachment edge.
Icon slots, hover, frame attachment and reservation stay unchanged.
The earlier Dock-only ear scaling extension was removed from the shared Flare.
The updated headless pointer suite and nested Niri reservation suite pass, and
the live Niri shape was visually inspected after reload. One earlier nested run
reported a 109 px work-area change instead of 65 px; the final repeat passed.

The user subsequently requested Top-only Dock visuals/input, replacing the earlier
Overlay implementation. Fullscreen clients may cover both the Dock and its trigger;
the input suite now checks that behavior. The separate Dock reservation stays on
Bottom, inside the Top-layer frame reservations. No compositor workspace backend
was rewritten.
The Top-only update passed the headless input and reservation suites. Niri's live
layer listing confirms `hakuspace-dock` on Top, and shell IPC returns `pong`.

The early Niri trigger failures are retained as test findings. A later full
physical trace confirmed pointer enter at local bottom coordinates, valid input
regions, the original complete input acceptance sequence and a passing result. Raw
protocol traces/user window titles stay in `/tmp`, outside the repository.

## Direct input update (2026-10-19)

The latest request removes the pin popup and icon background component. Right-click
now toggles pinning; middle-click requests app termination. The warning tooltip
appears immediately and asks for a second middle-click when aggregate RSS meets
Exit's saved `RAM_THRESHOLD_MB` (default 300 MB). Moving away, Escape, left/right
click or closing the Dock clears the confirmation. PID roots must still have the
same start times; signals use pidfds, and the calling desktop shell is protected.
Unknown compositor PIDs produce a tooltip error instead of process-name guessing.

Niri PID lookup and actual SIGTERM passed against a separately created, disposable
Quickshell window. No running user app was terminated. Seven backend tests cover
threshold parsing, Niri/Hyprland/Mango mappings, RAM checks, PID changes, descendant
deduplication and shell protection. Headless and physical Niri pointer tests pass
with a non-destructive backend fixture. The updated nested Mango pointer suite also
passes, and its client query exposes numeric PIDs in the expected format. Actual
termination on Hyprland/Mango remains untested. The complete repository gate passes with
a disposable Git index. The new controller is linked into the installed bin
folder and Hikai has been reloaded.

## Live icon resources (2026-10-19)

A shared, event-driven icon host now resolves files with the project's existing
GTK/GIO dependency. It watches GTK settings/GSettings, active/inherited theme
folders, displayed files and symlink targets; updates use versioned file URLs to
bypass stale Qt pixmaps. It runs only while manual Dock state is ON and does not
replace the app model, change pin ordering or reload Quickshell. The current
session uses the GTK3 platform theme. Other platform-theme integrations such as
qt6ct/KDE have not been validated.

Four native-monitor tests cover edits, atomic replacement, deletion/recreation,
new icons, theme switches, symlinked settings, absolute paths and buffered requests. The QML resource
harness verifies actual red → blue → green icon pixels, static/lively wallpaper
refresh on reopen, deletion, overwrite versions and overlapping requests. It uses
private settings and assets; no installed icon files or wallpaper selection change.

## Verification and remaining work

- PASS: `git diff --check`, QML structural checker and native QML loader checks.
- PASS: Qt 6 qmllint syntax analysis with existing project-style/type-import warnings allowed; this is not a zero-warning lint claim.
- PASS: pin backend tests, settings backend tests, Dock app-model and geometry tests.
- PASS: `scripts/precommit_check.sh`, using a disposable Git index/object directory so no source files were staged or committed.
- PASS: isolated runtime and input runners; the default runner never modifies installed user settings/pins/state. Its launch/file-manager commands are fixture programs.
- PARTIAL: primary-session Mango/Hyprland Dock pointer/visual smoke, real multi-monitor and fractional scale, physical drive arrival/removal, full Classic → Hikai → Classic session switch and compositor reconnect.
- DEFERRED: D6b Trash empty/full status and the plan's other explicitly deferred features. Hover lift is implemented by subsequent user request; the full physical hover matrix remains pending.

## Live session

Hikai was reloaded on the user's Niri session and the existing controller enabled
`taskbar_manual_state`. The deployed Dock is a Top surface on `eDP-1`; its
reservation is absent when exclusive space is OFF. Shared pins and persisted
shell preferences were not changed by this live activation. Move to the middle
fifth of the bottom edge to reveal the default autohide Dock.

During the later style check, the user's manual state was OFF. The controller
temporarily enabled Dock for rest/hover screenshots, then restored OFF. Visual
inspection confirmed the borderless Flare, frame attachment, wider padding,
closer dots and unclipped icon lift. Persisted visibility was already `always`;
the style check did not modify it.

## Suggested commits (not executed)

1. `feat(hikai): add taskbar state and dock settings v3`
2. `feat(taskbar): share JSONC pins and group native windows`
3. `feat(hikai): render native dock with safe-zone input and stable reservation`
4. `test(hikai): cover dock input, persistence and output lifecycle`
5. `fix(hikai): align dock with frame and animate icon hover lift`

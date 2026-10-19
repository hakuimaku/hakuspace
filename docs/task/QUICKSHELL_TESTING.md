# HakuSpace Quickshell — Testing Guide (Hikai backend)

> Synchronized with the current P3 baseline at HEAD `64418615` (2026-10-11). This document lists **currently available features**, **temporarily missing features**, and verification commands. Record the result (pass/fail and notes) when running each check.
> Convention: commands are run in a terminal; "Expected" describes the correct result. Commands using paths such as `~/.local/bin/...` assume deployment through `install.sh`/`update.sh`.

---

## Native Dock verification (2026-10-19)

```bash
python3 scripts/test_taskbar_pins_ctl.py
python3 scripts/test_dock_app_ctl.py
python3 scripts/test_dock_icon_watch.py
python3 scripts/test_hakucfg_hikai.py
bash scripts/test_hikai_resource_refresh.sh
node scripts/test_dock_app_model.js
node scripts/test_dock_geometry.js
bash scripts/test_hikai_dock.sh
HAKUSPACE_DOCK_INPUT=1 bash scripts/test_hikai_dock.sh
HAKUSPACE_DOCK_REORDER=1 bash scripts/test_hikai_dock.sh
HAKUSPACE_HAKUMENU_TEST=1 HAKUSPACE_DOCK_TOOLTIP=1 bash scripts/test_hikai_dock.sh --current
bash scripts/test_hikai_dock.sh --niri
bash scripts/test_hikai_dock.sh --mango
```

The default mode uses two headless Labwc outputs. Nested modes require a running
parent Wayland display. Every runner uses copied QML, private HOME/state/settings,
shared-pin fixtures and D-Bus. Input mode sends real Wayland virtual-pointer
events and mocks application/file-manager launches and termination responses. It checks edge activation,
grace re-entry, click-through, pin/unpin, window grouping/cycling, fullscreen coverage of the Top-layer trigger,
App Menu routing, launch, drives and Trash. Hover checks cover peak/neighbor lift,
zero/maximum lift and enlargement, fixed slots/width, clipping bounds, raised hit
areas, enlarged anchors, immediate tooltips, direct right-click pinning,
local pin/unpin feedback without overlapping tooltips,
shared icon-size persistence on Apply, untouched pin files during preview/Discard,
high-RAM confirmation/cancellation, autohide and live frame insets. Moving from a
middle-clicked icon to another icon must hide the old tooltip while Dock keyboard
focus stays on the clicked item. Escape must hide both the warning and tooltip
even if the pointer remains over that item. The HakuMenu input suite
also covers rapid App Menu toggles, tooltip suppression while HakuMenu owns input,
window-focus restoration, and switching between Tab navigation and pointer hover.
These tooltip checks pass on the live desktop and isolated Labwc. An earlier full live
HakuMenu run stopped at its fullscreen click-through fixture (expected one
client click, observed zero); the complete isolated HakuMenu run passes.
Backend tests use disposable processes to check first-click SIGTERM below the threshold,
second-click confirmation above it, PID identity changes and shell protection.
On Labwc, the input suite separately checks real native close requests against
fixture windows: first-click confirmation, refreshed confirmation after window
membership changes, closing every confirmed window, and minimized-window restore.
The native path never invokes the PID termination fixture.
The reorder harness sends separate press, motion and release events to test
early-motion and long-press dragging, shared-file persistence/reload, Applications ordering, Escape,
outside-drop and external-edit cancellation, autohide leases, crowded edge scrolling
and manual OFF during a gesture. It also checks feedback placement, expiry, backend
errors and autohide release after removing a stopped pin. Fixture desktop entries
prevent accidental app launches.
The regular harness checks maximized
client reservation, fixed frame dimensions across exclusive ON/OFF and manual OFF,
draft/Discard/persistence, external pin edits and malformed
JSONC recovery. `--current` runs on the current compositor; input mode there
moves the real session pointer and briefly opens fixture windows.
Both manual OFF and pointer-driven autohide sample the closing animation: the
surface and fading icons stay visible, item input stops immediately, and manual
OFF clears the input mask before the visual window unmaps after the animation.
The settings harness checks the actual hover sliders, Apply/Discard/Reset and
reload persistence, including migration from version 3 without losing Dock choices.
Hikai settings live in `~/hakucfg/hikai/`. Deployment tests verify
legacy relocation, preserved bytes and permissions, existing-destination priority,
repeated sync and controller writes through the new default paths.

See [HIKAI_DOCK_D0_PROBE.md](HIKAI_DOCK_D0_PROBE.md) for the window-source probe.
The implementation report records the final runtime and physical coverage.

## Post-P3 Settings verification (updated for V3)

Status: **IMPLEMENTED / PHYSICAL VERIFY**. See
[QUICKSHELL_STYLE.md](QUICKSHELL_STYLE.md) for schema ownership and geometry.

```bash
python3 scripts/test_hikai_settings_ctl.py
bash scripts/test_hikai_shell.sh
bash scripts/test_hikai_shell.sh --headless
HAKUSPACE_TEST_SCALE=1.25 bash scripts/test_hikai_shell.sh --headless
```

The headless runner needs Labwc, grim, dbus-run-session and permission to create local
sockets; fractional mode also needs wlr-randr. Both runners use disposable
preferences, copied QML and isolated runtime paths. Headless mode uses a separate
D-Bus session, HOME and two outputs. It does not change the active user's shell.
Missing deployed avatar/stats/sidebar helpers and portal/PipeWire warnings are
expected in that isolated fixture; QML type/reference/binding failures fail it.

| Automated check | Result / coverage |
|---|---|
| Backend | Pass: valid/missing read, partial writes, preservation, v1 → v2 migration without read-side writes, independent screen ranges, strict types/version/enum, malformed JSON, symlink/FIFO rejection, permissions, atomic replacement/failure cleanup, reset, check and CLI JSON. |
| Offscreen QML | Pass: actual Shell page/sliders instantiate; missing-file and v1 startup, explicit migration Apply, radius independence, border/Y independence, live/captured anchor modes; live R=4/12/24, presets, draft/dirty, Apply/reload, Discard, Reset/Discard, Reset/Apply, invalid edits and stale theme payload isolation. |
| Labwc headless, two outputs, scale 1.0 | Pass: five rendered screen radius/border combinations, pixel checks for no top rail and independent masks, actual module-lane positioning and captured rects on the source monitor; real TopBars/RoundedScreen/Settings/Navigation, all optional modules off, zero Row widths, fixed Logo footprint, tray ownership cleanup, recording override, Labwc workspace exclusion and Keep/Discard close lifecycle. Opens Navigation/Dashboard/Sidebar/Settings at all three radii and presets; checks that the Sidebar ear tip stays inside Navigation's contour (24 px spike regression). |
| Labwc headless, two outputs, scale 1.25 | Pass: same runtime/layout/lifecycle harness with both outputs configured by wlr-randr. Physical fractional-scale inspection remains pending. |

Headless image artifacts can be retained for inspection:

```bash
HAKUSPACE_TEST_ARTIFACT_DIR=/tmp/hikai-screen-geometry scripts/test_hikai_shell.sh --headless
```

`case-0.ppm` through `case-4.ppm` correspond to 0/0, 0/6, 24/0, 24/6, 20/4.
`test_rounded_screen_pixels.py` checks actual screen-edge pixels with TopBar hidden
and visible. `bar-case-*.ppm` captures verify top corners follow the compositor's
TopBar exclusive zone without doubling the side/bottom inset.
The harness varies the reserved bar height independently of the nominal theme
height. It also asserts the full-width TopBar host and renders real WindowTitle,
Calendar and Notifications tooltips and HakuMenu at radius 24; pixel assertions
cover their attachment rows to catch a one-pixel gap. At fractional surface
origins the last physical Canvas row may be blended; checks require coverage
there and fully opaque rail pixels immediately inside it.
Calendar also checks that its padded body and full right foot fit inside TopBar's
drawable window, with a pixel sample below the old fixed-height clipping boundary.
Dashboard captures at R=4/12/24 check that its top bridge stops at the attachment
tangent, without an extra opaque row forming a step at the right ear tip.
Notification Center captures with four history entries at R=24 check that the
interior bottom-left corner has no detached foot and the right foot still joins
the physical screen edge, including on the second output and fractional scale.
Set `QS_GEOMETRY_DEBUG=1` when starting a real Hikai session to inspect attachment,
insets, screen/local anchors, flare span and safe-zone corridors. Debug is off by
default and does not accept input. Keep it off during pixel-matrix tests.
The required physical matrix is listed below.

The precommit gate includes backend and offscreen QML checks when Quickshell is
installed. Its existing untracked-source rule still applies. Before staging new
files, the gate can run with a disposable Git index/object directory containing
intent-to-add entries; the real index and object database remain untouched.

Physical acceptance remains pending; automated/headless checks do not prove
visual compatibility or replace the requested WM matrix:

1. On Hyprland, Niri and Mango, test R=4/12/24 with TopBar, RoundedScreen,
   Navigation, Dashboard, Sidebar, Settings, HakuMenu, ActionMenu, Wallpaper,
   real tray menu, notification popup/center, volume OSD, tooltips and Picker.
   Check seams, masks, negative bounds, clipping and narrow widths.
2. Check Ink/Dark/Soft for text/accent/hover/selection/disabled contrast at scale
   1.0 and a fractional scale. Drag the slider, use arrow keys, and verify focus.
3. Toggle each module and combinations (minimal left/right, center off, all off).
   Logo stays accessible; Cava remains conditional; active recording stays visible;
   hiding the bell preserves server, popups, history and DND. Open a real tray
   menu, hide tray and verify no stale ownership or invisible input remains.
4. With two real outputs, change radius/tone/gates and check both outputs,
   Navigation shift, safeSpan, right widths and tray/notification anchors.
5. Save R=20, soft, tray=false; change wallpaper, accent, font and font size through
   the real theme flow. Confirm those three shell values remain unchanged.
6. Check Apply → Quickshell reload, logout/login and Hikai → Classic → Hikai.
   Shell preferences survive and Classic files remain unchanged.
7. Check edits → close → Keep/Discard, Apply, Reload confirmation, Reset → Discard
   and Reset → Apply, including multiple dirty stores and backend failures.

Do not record DONE from this partial runtime coverage. No repository commit or
deployment is performed by the test runners.

## 0. Before each handoff (Gemini) and after each deployment (user)

```bash
# In the repository: validation gate
scripts/precommit_check.sh
# Expected: "All checks passed!" (checks debug code, untracked source files, stray files at the
# repository root, qml_syntax_check.py, node test_flare_geometry.js, and bash -n)

# On the machine running Hikai: clean startup log
qs log -c hakuspace | tail -30
# Expected: no TypeError, ReferenceError, "is not a type", singleton error, or QColor undefined
```
Note: `qml_syntax_check.py` only catches mismatched brackets/quotes; it does **not** replace `qmllint` and does not detect behavioral errors.
Verify that no debug code remains: `grep -rnE "INJECTED|Perf Test|ancestor|console\.log" src` should print nothing (except the parse-error line from `Theme.qml`).

### P0 labwc result (2026-10-07)

Status: **IMPLEMENTED / VERIFY** for the full P0 milestone. This session had one 1920×1080 output at scale 1.0, Quickshell 0.3.1, and `HEAD` `68c3ba59` plus the P0 working-tree edits.

| Check | Result |
|---|---|
| Hikai startup, IPC `ping`, Labwc workspaces absent | Pass; TopBar visible, no workspace dots, `haku_backend.sh --verify` passed. |
| `shell.reload` IPC | Pass after changing `Quickshell.reload()` to `Quickshell.reload(false)`; the no-argument call had logged `Insufficient arguments`. |
| Classic ↔ Hikai | Pass for two consecutive round trips; final backend restored to Hikai. |
| Volume/brightness through `level_control.sh` | Pass; both OSDs visible in screenshots, values changed and returned to their starting values. |
| Rapid volume actions | Pass; ten `volume-up` calls changed 32% → 52%, ten `volume-down` calls returned to 32%. |
| Volume → brightness | Pass; the brightness OSD replaced the volume OSD. |
| Mic mute | Pass; source mute toggled and restored without output-level OSD. |
| Classic fallback with QS absent | Pass; volume 32% → 34% → 32% by direct commands. |
| Opaque bar color (historical P0 result) | Passed before the all-black theme update: `#000000` with opaque off, `#111111` with opaque on. Recheck both states against the current `#000000` requirement. |
| Bar hidden with RoundedScreen enabled | Pass; screenshot showed all four frame edges; original bar state restored. |
| Current QS log | No QML type/reference errors or crash loop. One host-portal app-ID registration warning remains. |

Still to check interactively on labwc: actual hardware keys, Settings scroll, fullscreen overlay and click-through, OSD lifetime after the action queue settles, media/recording/Cava behavior, tooltip lifecycle, and monitor hotplug or different scales. Hyprland, Niri, and MangoWM workspace and Dynamic Center matrices remain pending until those sessions are available. Do not mark P0 DONE from this labwc pass.

---

## 1. Backend (M0)

### 1.1 Switching and `--verify`
```bash
~/.local/bin/haku_backend.sh set hikai
~/.local/bin/haku_backend.sh --verify      # Expected: "Verification passed."
pgrep -a swaync                            # Expected: empty (native notifications active in Hikai)
~/.local/bin/haku_backend.sh set classic   # Expected: waybar/taskbar/... return, with no quickshell
pgrep -af 'qs -c hakuspace'                # Expected: empty after switching to classic
```
Switch **several times in succession**: this must not create two supervisors or two `qs` processes (`pgrep -af qs_supervisor.sh` and `pgrep -af 'qs -c hakuspace'` must each return at most one line).
If a manually started `qs -c hakuspace` instance already exists, `set hikai` must stop it and start it again.

### 1.2 Manager guards and Hikai-compatible app state
```bash
~/.local/bin/haku_backend.sh set hikai
for m in waybar_manager.sh rounded_screen_manager.sh edge_trigger_manager.sh; do ~/.local/bin/$m --startup; done
pgrep -x waybar; pgrep -x taskbar    # Expected: empty

~/.local/bin/taskbar_manager.sh --toggle
cat ~/.local/state/hakuspace/state/taskbar_manual_state   # Expected: flips 0/1; no Waybar taskbar process starts

~/.local/bin/cava_manager.sh toggle
cat ~/.local/state/hakuspace/state/cava_layer_state       # Expected: flips 0/1
pgrep -af 'cava_layer.py'                           # Expected when state=1: one Cava Underbar process

~/.local/bin/desktop_icons_manager.sh --toggle
cat ~/.local/state/hakuspace/state/desktop_icons_state    # Expected: flips 0/1
pgrep -af 'desktop_icons.py'                        # Expected when state=1: one Desktop Icons app process
```
Desktop Icons and Cava Underbar are explicitly allowed in Hikai as standalone apps. Taskbar remains a Hikai state-only toggle; it must not start legacy Waybar surfaces. In Hikai, Cava Underbar always operates with dynamic exclusive mode (`--dynamic`).

### 1.3 Autostart and fresh startup
Log out/in (or reboot) on the `hikai` backend for each WM: the bar appears and `--verify` passes. All four autostart entries must call `session_start.sh --early` (`grep -rn session_start src/home/.config/{hypr,niri,labwc,mango}`). A reboot must preserve the selected backend.

### 1.4 Emergency key and fallback
- **Super+Esc** (all four WMs) calls `haku_backend.sh set classic`: it must work even when QS is dead.
- Kill QS three times in succession within ≤ 60 s (`qs -c hakuspace kill`): the supervisor detects the crash loop and automatically switches to classic (see `$XDG_RUNTIME_DIR/hakuspace/qs.log`).
- Preserve `Haku Space Mode`: `head -1 src/core/theme/haku_space_mode.sh` must be `#!/usr/bin/env bash`; `haku_shell_mode.sh` is the old shim (`exec haku_space_mode.sh`); if an old `haku_shell_state` exists, `session_start.sh --early` migrates it to `haku_space_state`.

---

## 2. Live theme and state (M1)

1. **Live theme:** change the accent with `change_theme.sh` (or the Theme menu): hover/selection fills, text, icons, workspace indicators and the MPRIS icon circle change **immediately**, without restarting QS. Bar, tooltip, ordinary idle modules, Picker overlay/card and OSD backgrounds stay opaque `#000000`; Logo and Settings stay accent-filled. Also test changing the font and font size.
2. **Live state:** `echo 0 > ~/.local/state/hakuspace/state/waybar_manual_state` → the bar hides immediately; `echo 1` → it appears again. With either value of `opaque_theme_state`, the bar and tooltip remain `#000000`.
3. **Rounded Screen chassis:** use Shell → Rounded Screen, not source-code constants.
   Test radius/border pairs 0/0, 0/6, 24/0, 24/6 and 20/4; only left/right/bottom
   rails reserve space. Radius 24 with border 0 still rounds corners. Base Radius
   changes do not change the screen radius. Border changes never move Flare Y.
   Check Apply/Discard/Reset, two outputs, scale 1.0/1.25 and desktop click-through.
   The chassis remains independent of Classic configuration and manager toggles.

---

## 3. Picker (`haku_pick.sh`)

```bash
printf 'Option A\nOption B\nOption C\n' | ~/.local/bin/haku_pick.sh --prompt "Test Picker"
```
- The picker appears in the center of the screen over an opaque black overlay; its card is black, while selected/hovered rows have accent backgrounds and black text. Typing filters, ↑/↓ selects, and Enter prints the exact selected line; **Esc → exit 1**.
- Run it **twice in succession**, selecting one line each time: both invocations print the correct result and do not hang; `pgrep -af haku_pick` is empty afterward.
- Cleanup: `ls $XDG_RUNTIME_DIR/hakuspace` must show no leftover `pick_fifo_*`/`pick_req_*` or unexpected regular files.
- Kill QS while the picker is open → `haku_pick.sh` exits with status 1 (does not hang).
- Password mode: `printf '' | haku_pick.sh --password --prompt pw` (input is masked); `--no-custom` must disallow arbitrary typed strings.
- `--width/--height/--selected/--lines` currently have **no effect** in Hikai (see section 8).
- No script currently calls `haku_pick.sh` (`rofi -dmenu` calls remain, work in classic; in Hikai they attempt to call rofi, which is forbidden): migrating call sites belongs to M4.
- To diagnose IPC when the picker does not appear: run `scripts/qs_picker_probe.sh` from the repository (do not deploy it to `~/.local/bin`) and inspect `qs log -c hakuspace | tail -20`.

---

## 4. Top bar

Expected layout: **left** Logo, Workspaces, WindowTitle; **right** Tray, Settings group (+ Power profile), Recorder, Clock, Notification; **center** Dynamic Center, hidden when idle.

| Module | Test | Expected |
|---|---|---|
| **Logo** | Hover; click | Accent background and black glyph in both states. Hover expands the pill smoothly. Clicking toggles radial Navigation controller (Sidebar, Dashboard, Settings). Logo morphs into Navigation hub (`7604c1f0`). |
| **Workspaces** | Switch workspace with the keyboard; scroll over the group; click a dot | The accent indicator **expands and contracts** toward the new dot (it stretches farther when moving farther, and changes direction correctly); a dot with windows is brighter than an empty dot; repeated key presses do not stutter. *Record clearly whether clicking/scrolling switches workspaces (see observation 1 in section 8).* |
| **WindowTitle** | Change the focused window; hover | Class + title change with a fade effect; visible title is limited to 32 Unicode characters with an ellipsis, while the tooltip keeps the full title. Hover uses dark grey `#2b2b2b` with accent icon/text. Hyprland provides data; Niri has an event-stream implementation that still needs runtime verification. Mango and Labwc do not provide data yet. |
| **Tray** | Have `nm-applet`, `blueman-applet`, `fcitx5` running; hover and right click | Hover uses dark grey `#2b2b2b`; tooltip text remains accent and tray icon artwork keeps its app-provided colours. Normal left click activates; `onlyMenu` left click requests its menu. Every usable short or long DBusMenu opens in the QML + Flare panel. Escape, outside click, or an action closes with a morph and releases desktop input. Missing or persistently empty menu models use the platform fallback; no-menu items use `secondaryActivate`. Scrolling reaches the applet; the icon disappears when it exits. Middle click is **not supported yet** |
| **Settings** | Scroll on the brightness icon; scroll / left click / right click on the volume icon; hover the battery; click Power profile | Settings pill stays accent with black icons, including on hover; icons may scale slightly. Brightness changes (`brightnessctl`) and left click toggles night light; volume changes by ±1%, left click mutes/unmutes, right click opens `pavucontrol`; tooltips show the correct value; Power profile cycles `performance → balanced → power-saver`. On desktops, the brightness and battery icons hide automatically |
| **Recorder** | Start/stop recording with `record.sh` (F11 or click) | While recording: a blinking accent chip with elapsed time hosted exclusively in the right Recorder group (`8f21ac42`); otherwise: icon only. |
| **Clock** | Hover; scroll; right click; leave and left click | `HH:mm` + weekday/date on two lines. Hover and left click request the same calendar through TooltipManager/Flare; scroll changes the visible month in place, and right click returns to the current month. Current day has a solid `Theme.accent` fill, black text `#000000`, and ~3-4px breathing room clearance within the day cell (`604638ea`). |
| **Notification** | Hover; click | Native notification indicator. Hover opens tooltip; click toggles Notification Center panel. |

Not attached to the bar (test if temporarily reattached): **Monitor** (CPU/RAM/temp drawer; values must match `btop`/`top`; closing the drawer stops `SysStats` polling). `MusicGroup` was removed; MPRIS uses Dynamic Center. When audible, Cava occupies a stable slot left of MPRIS in the centered media cluster and shares one process across screens.

General checks:
- No fake values ("12%", "99%") remain in any module; `qs log` is clean.
- Switch hikai ↔ classic several times: the classic bar returns correctly, with no extra processes.
- Plug/unplug a monitor while QS is running: no crash; each monitor has its own bar.

### Dynamic Center (N11)

- Scroll volume or brightness, then press the hardware volume, mute, and brightness keys: the shared `level_control.sh` path must open the OSD immediately in Hikai. TopBar draws its flare on the Top layer; the Overlay draws a black rounded background, read-only slider, and percentage. The percentage updates to the confirmed value. It closes about 1.4 s after the last command completes. Try 10–20 rapid inputs and switch directly from volume to brightness; the OSD should stay open. In classic mode or before Quickshell starts, the script must still adjust the device directly. Mic mute changes the source without showing the output-volume OSD. Reloading the shell or background polling alone must not show the OSD. Check visibility over a fullscreen client and click-through behavior.
- Screen recording state is hosted exclusively in the right `RecorderGroup`; `CenterModule` / `CenterState` no longer hosts `REC` and tracks media/OSD only (`8f21ac42`).
- Start/pause media: show title and artist, with play/pause on click when the player supports it. Playing players take priority; ties and paused players use D-Bus name order. A stopped player is ignored. During playback, the shared Cava process keeps reading audio even while its visual is hidden. After 3 seconds of detected sound, Cava appears in a stable slot left of MPRIS. Once visible, Cava remains shown through silence while MPRIS is still Playing. When MPRIS pauses, Cava stays visible with resting bars for 5 seconds before hiding and returning MPRIS to the center; resuming within that period cancels the hide. Hover both modules and check that the cluster stays centered. The MPRIS icon always has an accent circle with a black glyph; its surrounding module is black when idle and accent with black caption on hover.
- With the Cava binary or config unavailable, the Cava module hides after the process fails and does not restart repeatedly. Restore the dependency and reload Quickshell before checking Cava again.
- Test a long title, many tray icons, narrow output, and both together: the media title must elide and Cava hide before the centered cluster touches either side. Repeat on outputs with different sizes/scales. Check the extra 4 px top padding and the OSD seam; left/right and bottom padding stay at their previous values. Toggle the topbar: RoundedScreen must keep its full four-edge rounded border in both states.
- Check `qs log -c hakuspace` for QML errors while switching states. Interactive visual and multi-monitor checks remain necessary after deployment.

---

## 5. Temporarily missing Hikai features (not bugs)

- **Notifications:** Native notifications (P2) are active in Hikai (`NotificationServer` claims `org.freedesktop.Notifications`). `swaync` is blocked.
- **Super+R / Launcher:** Routes directly to HakuMenu Drun tab (`DesktopEntries` search & launch).
- **Large surfaces:** Navigation, Dashboard, Sidebar, Settings stub, HakuMenu (General, Drun, live Theme tab), and Wallpaper carousel are implemented.
- **Power & Clipboard:** Headless backends (`power_ctl.sh`, `clipboard_ctl.sh`) are complete; native Quickshell UI surfaces are deferred to P4 (P4.2 & P4.3).
- **Theme-tab parity update:** Hikai now exposes Cava Underbar, Desktop Icons, Taskbar, Niri Animation, wallpaper controls, and the backend switch. Desktop Icons and Cava Underbar run as standalone apps; Taskbar is a state-only toggle until/if a native Hikai surface is implemented. Edge Trigger remains deferred.
- **MangoWM:** workspaces are implemented with `mmsg` events; click, scroll, active/focused semantics, and monitor targeting still need runtime verification.
- **Labwc:** the workspace module is intentionally hidden because Quickshell 0.3.1 crashes when loading ext-workspace. Hikai itself must start and remain stable.

> **Super+Esc** works independently of the backend and always exits Hikai to Classic.

---

## 6. Tooltip and flare

Implemented: a background shape that expands/contracts around the hovered module, wraps around the Topbar with a concave curve, and wraps around the Rounded Screen edge when near the left/right edge.

| # | Case | Expected |
|---|---|---|
| T1 | Move onto a module → away → back (after 50 ms, 300 ms, 3 s) | Tooltip reappears (wait ~400 ms if fully hidden); is not empty; does not hide while the pointer remains on the module |
| T2 | Keep the pointer over a module whose text changes (scroll the Clock month; change volume in Settings) | Tooltip text updates in place immediately, without flickering |
| T3 | WindowTitle tooltip with a very long title | Wraps onto multiple lines, width ≤ 500 px, has 22 px padding on each side, is not clipped, and does not overflow the screen |
| T4 | Enable the opaque theme | Tooltip background matches the bar background |
| T5 | Restart QS and wait a few seconds | No tooltip appears automatically |
| T6 | Move quickly A → B → C and stay there | Tooltip settles under C |
| T7 | Move between two modules with equally long tooltip text | Tooltip moves to the correct new module |
| T8 | Move between adjacent modules in a short interval | Background follows the movement (leading edge moves first, trailing edge more slowly) without waiting 400 ms |
| T9 | Module near the left edge (Logo) and right edge (Notification/Clock); toggle Rounded Screen on and off | Body expands to the frame's inner edge (or screen edge when off); the lower corner at the edge becomes a concave curve flowing along the edge; no upper ear appears at the edge |
| T10 | Move continuously from an edge module to a middle module and back | Shape changes **continuously**, with no jump between styles |
| T11 | Different `R` (radius) and `t` (thickness): `R ∈ {10,20,40}`, `t ∈ {0,4,8}` | Especially when `R > barH`: the edge-wrapping foot remains correctly tangent; record the result |
| T12 | Two monitors | Tooltip appears only on the monitor with the pointer; each monitor wraps its own edge correctly |
| T13 | Change resolution/scale | Remains correct (uses the window's actual width) |

P1 implements panel/bar/target dismissal and Clock's calendar grid. The 2026-10-08 Clock closeout tested hover, scroll across a year boundary, right-click reset, left-click reopen, and visual fit at scale 1.0; see `P1_STATUS.md`. Re-run the complete T1–T13 matrix interactively; then hide a hovered target, hide the bar while its tooltip is visible, rapidly move across two monitors, and open `UiState.activePanel`. Confirm no flare remains stuck and the tooltip does not reappear until a valid hover.

---

## 7. Performance

The 2026-10-07 Niri interaction-idle sample of the already-running deployed QS process was 14.8% of one CPU core over 5 s with media/Cava active and about 504 MB RSS. This is not a clean shell-only baseline. Measure these before considering tooltip/flare complete:
```bash
# Wayland surface changes during morph (target: 0 xdg_popup/reposition/set_size)
WAYLAND_DEBUG=client qs -c hakuspace 2>&1 | grep -cE 'xdg_popup|reposition|set_size'   # run for a few seconds; the log is very large
# Scene graph frame timing
QSG_RENDER_TIMING=1 qs -c hakuspace
# CPU while idle and while moving across 5 adjacent modules
top -H -p "$(pgrep -f 'qs -c hakuspace' | head -1)"
```
Record: idle CPU (bar not interacting), CPU while morphing, and whether any frame exceeds ~16 ms. Shared Audio and Brightness services poll every 2 s; shared Recorder polls every 1 s; shared `PpdProfile` polls every 2 s. Check their impact on idle CPU.

### P1 tray and calendar checks

1. Run `timeout 11s qs -p scripts/qs_tray_menu_probe.qml --no-color` on the deployed session. Confirm `nm-applet`, `blueman-applet`, and an ordinary tray item expose live `QsMenuOpener` children; record `onlyMenu`, button/check state, nested entries, and changes while the menu remains open. The 2026-10-07 Niri result is in `P1_STATUS.md`.
2. Run `python3 scripts/tray_short_fixture.py` in the graphical session; it offers an action, a checkbox, and a submenu with an action and two radio choices, and logs activations. Right click it; verify rows, submenu/Back, radio, repeated open, Flare attachment, Escape, outside click, action-close morph, and transfer to another tray icon. Stop the fixture while its menu is open and verify the panel disappears without blocking desktop clicks. Recheck at 1.0x, 1.25x, and 1.5x scale when available. Test a real `onlyMenu` item on left click if available.
3. For long `nm-applet`, `blueman-applet`, and Fcitx5 menus, verify the HakuSpace QML + Flare panel appears immediately and never falls back because of height. Scroll tall lists, enter submenus and Back, use Escape and click outside, then check desktop input. Change networks/devices while a menu remains open to test live model updates. A context-menu-only/no-menu item still needs a real app test. Verify the panel stays within each monitor at scale 1.0 and a fractional scale. Current Niri results and untested cases are in `TRAY_FULL_QML_FLARE_REPORT.md`.
4. Hover Clock, scroll across year boundaries, right click to reset, and left click to reopen. Verify today and month names, repeated leave/reentry, and the right edge. Repeat on a fractional-scale output when available. The full calendar must remain inside the tooltip flare without a separate popup. The 2026-10-08 Niri pass covered scale 1.0 only; see `P1_STATUS.md`.

---

## 8. Observations to verify on the machine (not fixed yet)

1. **Workspace click/scroll on Hyprland:** audit after QS reload and on multiple monitors. The old case-sensitive `Env.wmName` comparison is no longer in the activation path.
2. **Animation curve:** `HAnimation` uses a 4-number bezier; Qt requires 6 numbers. Observe whether workspace movement overshoots as designed (the `spatialCurve` control point has y = 1.21) or is merely the default movement.
3. **Picker:** `--width/--height/--selected/--lines` have not been applied.
4. **Hyprland blur layer:** if layer blur is enabled, check whether the transparent strip beneath the bar (namespace `hakuspace-bar`, with no layer rule yet) is blurred.
5. **Ungated polling** (shared levels, Recorder, power profile): see section 7.

---

## 9. P3 Native surfaces verification matrix

### 9.1 Navigation (Radial Controller)
- **Visual:** 3-region annular radial controller anchored at top-left. Equal 120° sector geometry: Sidebar (90° → 210°), Dashboard (210° → 330°), Settings (330° → 450°/90°).
- **Morph:** TopBar Logo morphs smoothly into Navigation hub on open; sectors collapse back into hub on close, and Logo restores its TopBar circular footprint while Flare retracts into RoundedScreen seam.
- **Routing:** Hover or click on sector transitions cleanly to target surface (Sidebar, Dashboard, Settings). Escape closes and releases input.

### 9.2 Dashboard
- **Geometry:** 45% output width × 45% output height. Flare attaches to RoundedScreen top rail.
- **Pointer safe zone:** 200 logical px safe margin beyond shell. Moving pointer outside safe zone closes Dashboard/Navigation.
- **Avatar:** Origin avatar displays user image from `~/.local/share/hakuspace/user/`. Left-click returns to radial Navigation; right-click opens avatar file chooser without closing Dashboard.
- **Widgets:**
  - Clock card: live time/date display.
  - MPRIS card: album artwork fallback, player controls, progress bar.
  - Dynamic widget host: embedded `CalendarGrid` with month navigation and current-day accent marker.
  - Monitor card: 2×2 grid showing ROM, RAM, CPU, GPU (or `N/A` if unavailable). Single non-shell `SysStats` poller with 2000 ms cadence.

### 9.3 Sidebar
- **Visual:** Left-edge elongated rounded lobe attached to RoundedScreen left edge, circular action dots and plus button.
- **Handoff:** Hovering Navigation Sidebar sector expands Sidebar immediately via invisible transition bridge without flicker.
- **Lifecycle:** Sidebar stays open while pointer remains in sector ∪ bridge ∪ Sidebar. Leaving that union closes reliably. Escape closes. Dot/plus actions remain explicit stubs.

### 9.4 Settings stub
- **Visual:** Centered inner surface with backdrop separation (`still working rn...` placeholder).
- **Lifecycle:** Opened from Navigation Settings sector; Escape or outside click closes.

### 9.5 HakuMenu
- **Presentations:** `topFlare` keeps the existing top trigger and split Top-visual/Overlay-input windows. Dock App Menu toggles `dockFloating`, a bottom-center Overlay card with a narrow input mask, bottom controls and reversible Temp Note motion. Legacy IPC/launcher calls keep `topFlare`.
- **Tabs:** Segmented controller with moving `SelectionPill`:
  - **General:** Compact width (38% output width), actions populated from `hm_general.sh`.
  - **Drun:** Standard width (40% output width), `DesktopEntries` model, instant search filtering, keyboard/click launch. Super+R routes here.
  - **Theme:** Wide layout with a right-hand state rail. Cava Underbar, Desktop Icons, Taskbar, and Auto Random Wallpaper render ON/OFF pills; toggle rows keep HakuMenu open. Niri Animation is available as an action. The backend switch is the final row, has no state pill, and is labeled `Go back to Surface` in Hikai / `Explore the Abyss` in Classic.
- **Auto-close:** Each presentation uses its own safe-zone geometry and the shared grace controller. Floating zones include the real Dock anchor, handoff corridor and current/final card. Typing retains keyboard lease; pointer movement inside releases it. Outside remains click-through; Escape, App Menu toggle and leaving the zones close the menu.

Run `node scripts/test_hakumenu_geometry.js` and `bash scripts/test_hikai_hakumenu.sh`
for two isolated outputs (1280×720 and 1024×768), real virtual-keyboard/pointer
events, legacy trigger/prefix/launch/Escape behavior, floating morph reversal,
first-frame readiness without disabled-item fading, tab clicks and typing during
the remaining opening bounce,
footer placement, stable widths, cross-style/output ownership, fullscreen,
disabled-Dock fallback and crowded/scrolled icon anchors. `--current` moves input
on the current compositor while keeping HOME/state/settings/pins disposable.
`HAKUSPACE_HAKUMENU_ARTIFACT_DIR` selects an existing directory for screenshots.

### 9.6 Wallpaper carousel

- **Refresh:** Re-read static/lively directories on every open. Close/reopen during
  loading queues one fresh scan. Added/removed files and newly saved wallpaper
  directories appear on reopen; previews carry file versions to invalidate stale
  image textures without discarding the bounded preview cache.
- **Regression:** `scripts/test_hikai_resource_refresh.sh` runs actual discovery
  and QML against private files. It covers add/remove/overwrite, static/lively,
  rapid reopen, escaped filenames and rendered Dock icon pixels across edits and
  theme changes. `scripts/test_dock_icon_watch.py` covers native file events,
  atomic replacement, delete/restore/add, theme switches and batched stdin.
- **Visual:** Standalone full-screen Overlay without generic background panel. Fixed physical center slot with overlapping/stacked side cards. Soft blurred shadows on cards.
- **Navigation:** Left / Right arrow keys, mouse wheel, or pointer selection.
- **Apply:** Enter key or center card click initiates async apply (static image via `wallpaper_ctl.sh` or lively via backend) and triggers animated close sequence.
- **Performance:** Bounded prefetch window, lazy thumbnail decoding, input coalescing (85 ms), rapid navigation throttle guard (55 ms).

### 9.7 Shell frame polish & shared geometry
- **Frame attachment:** TooltipLayer, TrayMenuPanel, NotificationPopup, NotificationCenterPanel, and LevelOsdOverlay consume shared `ScreenGeometry` attachment/bounds and captured screen-local anchors.
- **Level OSD:** Compact capsule layout; optical center stays fixed across 0%, 9%, 10%, 99%, 100%.
- **TopBar recording:** Recording state (`REC` chip + timer) is restricted to right `RecorderGroup`; `CenterState` handles media/OSD only (`8f21ac42`).
- **Calendar marker:** Current day in Clock calendar and Dashboard calendar has solid `Theme.accent` fill with black `#000000` text and 3–4px breathing room clearance (`604638ea`).

### 9.8 Shared Action Layer / Morph Menu
- **Host Window:** Single shared centered `ActionMenuPanel` on `WlrLayer.Overlay` with dimmed backdrop and exclusive keyboard focus.
- **Motion language:**
  - First open: circular center reveal (`MultiEffect` mask expanding to surface diagonal, `actionLayerOpenDuration`).
  - Close: smooth fade + scale zoom out (`actionLayerCloseDuration`).
  - Page morph: button expands/morphs directly into child surface via `ActionMenuMorphProxy` and animated profile geometry (`actionLayerMorphDuration`).
  - Reverse morph: child surface contracts back into seed button geometry on Back or Escape.
- **Flows:**
  - `record`: Record mode -> Micro + Sound -> Mic Source child page -> start recording.
  - `power`: Horizontal action cards (Suspend, Reboot, Poweroff, Hibernate, Lock, Logout).
  - `power -> exit`: Logout button morphs directly into Exit confirmation report in same layer!
  - `exit`: Process report with scrollable active processes and Cancel / Exit Anyway actions.
  - `theme`: Theme root -> Font / Size / Accent / Rofi / Waybar child pages with live reflection on reverse morph.
- **Verification commands:**
  ```bash
  record.sh
  shutdown.sh
  exit.sh
  change_theme.sh
  qs -c hakuspace ipc call actionMenu status
  qs -c hakuspace ipc call actionMenu close
  ```


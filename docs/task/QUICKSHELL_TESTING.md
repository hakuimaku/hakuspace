# HakuSpace Quickshell — Testing Guide (Hikai backend)

> Synchronized with the P1 working tree based on `68c3ba59` (2026-10-07). This document lists **currently available features**, **temporarily missing features**, and verification commands. Record the result (pass/fail and notes) when running each check.
> Convention: commands are run in a terminal; "Expected" describes the correct result. Commands using paths such as `~/.local/bin/...` assume deployment through `install.sh`/`update.sh`.

---

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
pgrep -a swaync                            # Expected: present (temporary exception, see section 5)
~/.local/bin/haku_backend.sh set classic   # Expected: waybar/taskbar/... return, with no quickshell
pgrep -af 'qs -c hakuspace'                # Expected: empty after switching to classic
```
Switch **several times in succession**: this must not create two supervisors or two `qs` processes (`pgrep -af qs_supervisor.sh` and `pgrep -af 'qs -c hakuspace'` must each return at most one line).
If a manually started `qs -c hakuspace` instance already exists, `set hikai` must stop it and start it again.

### 1.2 Manager guards (do not run legacy apps in Hikai)
```bash
~/.local/bin/haku_backend.sh set hikai
for m in waybar_manager.sh taskbar_manager.sh rounded_screen_manager.sh edge_trigger_manager.sh \
         cava_manager.sh desktop_icons_manager.sh; do ~/.local/bin/$m --startup; done
pgrep -x waybar; pgrep -x taskbar; pgrep -f '\.py'    # Expected: all three empty
```
Also try `--toggle` and `--reload`: they must only change the state file; no legacy process may appear.

### 1.3 Autostart and fresh startup
Log out/in (or reboot) on the `hikai` backend for each WM: the bar appears and `--verify` passes. All four autostart entries must call `session_start.sh --early` (`grep -rn session_start src/home/.config/{hypr,niri,labwc,mango}`). A reboot must preserve the selected backend.

### 1.4 Emergency key and fallback
- **Super+Esc** (all four WMs) calls `haku_backend.sh set classic`: it must work even when QS is dead.
- Kill QS three times in succession within ≤ 60 s (`qs -c hakuspace kill`): the supervisor detects the crash loop and automatically switches to classic (see `$XDG_RUNTIME_DIR/hakuspace/qs.log`).
- Preserve `Haku Space Mode`: `head -1 src/core/theme/haku_space_mode.sh` must be `#!/usr/bin/env bash`; `haku_shell_mode.sh` is the old shim (`exec haku_space_mode.sh`); if an old `haku_shell_state` exists, `session_start.sh --early` migrates it to `haku_space_state`.

---

## 2. Live theme and state (M1)

1. **Live theme:** change the accent with `change_theme.sh` (or the Theme menu): hover/selection fills, text, icons, workspace indicators and the MPRIS icon circle change **immediately**, without restarting QS. Bar, tooltip, ordinary idle modules, Picker overlay/card and OSD backgrounds stay opaque `#000000`; Logo and Settings stay accent-filled. Also test changing the font and font size.
2. **Live state:** `echo 0 > ~/.local/state/hakuspace/state/waybar_manual_state` → the bar hides immediately; `echo 1` → it appears again. With either value of `opaque_theme_state`, the bar and tooltip remain `#000000`. Toggle `rounded_screen_state` to show/hide the rounded frame. If a file is deleted or empty, retain the defaults (bar visible, opaque off, rounded off, dynamic on).
3. **Rounded Screen:** change `border_thickness`/`border_radius` in `~/hakucfg/config/rounded-screen.conf`: the frame updates immediately.

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

Expected layout: **left** Logo, Workspaces, WindowTitle; **right** Tray, Settings group (+ Power profile), Recorder, Clock, Notification (stub); **center** Dynamic Center, hidden when idle.

| Module | Test | Expected |
|---|---|---|
| **Logo** | Hover; click | Accent background and black glyph in both states. Hover grows the icon font size by 2 px and expands the pill by `Theme.pad`, with a smooth width transition. Clicking does not open anything yet (record `UiState.activePanel`); tooltip says "Have a nice day!…" |
| **Workspaces** | Switch workspace with the keyboard; scroll over the group; click a dot | The accent indicator **expands and contracts** toward the new dot (it stretches farther when moving farther, and changes direction correctly); a dot with windows is brighter than an empty dot; repeated key presses do not stutter. *Record clearly whether clicking/scrolling switches workspaces (see observation 1 in section 8).* |
| **WindowTitle** | Change the focused window; hover | Class + title change with a fade effect; visible title is limited to 32 Unicode characters with an ellipsis, while the tooltip keeps the full title. Hover uses dark grey `#2b2b2b` with accent icon/text. Hyprland provides data; Niri has an event-stream implementation that still needs runtime verification. Mango and Labwc do not provide data yet. |
| **Tray** | Have `nm-applet`, `blueman-applet`, `fcitx5` running; hover and right click | Hover uses dark grey `#2b2b2b`; tooltip text remains accent and tray icon artwork keeps its app-provided colours. Normal left click activates; `onlyMenu` left click requests its menu. Every usable short or long DBusMenu opens in the QML + Flare panel. Escape, outside click, or an action closes with a morph and releases desktop input. Missing or persistently empty menu models use the platform fallback; no-menu items use `secondaryActivate`. Scrolling reaches the applet; the icon disappears when it exits. Middle click is **not supported yet** |
| **Settings** | Scroll on the brightness icon; scroll / left click / right click on the volume icon; hover the battery; click Power profile | Settings pill stays accent with black icons, including on hover; icons may scale slightly. Brightness changes (`brightnessctl`) and left click toggles night light; volume changes by ±1%, left click mutes/unmutes, right click opens `pavucontrol`; tooltips show the correct value; Power profile cycles `performance → balanced → power-saver`. On desktops, the brightness and battery icons hide automatically |
| **Recorder** | Start/stop recording with `record.sh` (F11 or click) | While recording: a blinking accent chip with elapsed time; otherwise: icon only. (`record.sh` still uses rofi's picker in classic) |
| **Clock** | Hover; scroll; right click; leave and left click | `HH:mm` + weekday/date on two lines. Hover and left click request the same calendar through TooltipManager/Flare; scroll changes the visible month in place, and right click returns to the current month. Current day has a black circle with accent border and text. |
| **Notification** | Hover | Stub: only the "Notifications" tooltip |

Not attached to the bar (test if temporarily reattached): **Monitor** (CPU/RAM/temp drawer; values must match `btop`/`top`; closing the drawer stops `SysStats` polling). `MusicGroup` was removed; MPRIS uses Dynamic Center. When audible, Cava occupies a stable slot left of MPRIS in the centered media cluster and shares one process across screens.

General checks:
- No fake values ("12%", "99%") remain in any module; `qs log` is clean.
- Switch hikai ↔ classic several times: the classic bar returns correctly, with no extra processes.
- Plug/unplug a monitor while QS is running: no crash; each monitor has its own bar.

### Dynamic Center (N11)

- Scroll volume or brightness, then press the hardware volume, mute, and brightness keys: the shared `level_control.sh` path must open the OSD immediately in Hikai. TopBar draws its flare on the Top layer; the Overlay draws a black rounded background, read-only slider, and percentage. The percentage updates to the confirmed value. It closes about 1.4 s after the last command completes. Try 10–20 rapid inputs and switch directly from volume to brightness; the OSD should stay open. In classic mode or before Quickshell starts, the script must still adjust the device directly. Mic mute changes the source without showing the output-volume OSD. Reloading the shell or background polling alone must not show the OSD. Check visibility over a fullscreen client and click-through behavior.
- Record the screen: Center shows compact `REC` without elapsed time; the right Recorder keeps the elapsed timer and start/stop control. Volume and brightness still open the separate OSD while recording, temporarily hiding the Center visual.
- Start/pause media: show title and artist, with play/pause on click when the player supports it. Playing players take priority; ties and paused players use D-Bus name order. A stopped player is ignored. During playback, the shared Cava process keeps reading audio even while its visual is hidden. After 3 seconds of detected sound, Cava appears in a stable slot left of MPRIS. Once visible, Cava remains shown through silence while MPRIS is still Playing. When MPRIS pauses, Cava stays visible with resting bars for 5 seconds before hiding and returning MPRIS to the center; resuming within that period cancels the hide. Hover both modules and check that the cluster stays centered. The MPRIS icon always has an accent circle with a black glyph; its surrounding module is black when idle and accent with black caption on hover.
- With the Cava binary or config unavailable, the Cava module hides after the process fails and does not restart repeatedly. Restore the dependency and reload Quickshell before checking Cava again.
- Test a long title, many tray icons, narrow output, and both together: the media title must elide and Cava hide before the centered cluster touches either side. Repeat on outputs with different sizes/scales. Check the extra 4 px top padding and the OSD seam; left/right and bottom padding stay at their previous values. Toggle the topbar: RoundedScreen must keep its full four-edge rounded border in both states.
- Check `qs log -c hakuspace` for QML errors while switching states. Interactive visual and multi-monitor checks remain necessary after deployment.

---

## 5. Temporarily missing Hikai features (not bugs)

- **Notifications:** `swaync` is allowed to run and handle notifications until M3 (`QS_ALLOW_SWAYNC=1`; `--verify` ignores swaync).
- **Super+R, Super+/ (launcher), Super+N (notifications):** do nothing in Hikai because the `launcher`/`notif` IPC endpoints do not exist yet (M3/M4).
- **HakuMenu, power menu, wallpaper picker, clipboard menu:** still use legacy rofi/scripts; they cannot run while rofi is forbidden (M4).
- **Notification, Monitor:** notification is a stub and Monitor is not attached. `MusicGroup` was removed; Dynamic Center handles MPRIS media and Cava appears conditionally beside it.
- **Edge trigger, cava layer, taskbar, desktop icons:** not available in Hikai (M5/M6).
- **MangoWM:** workspaces are implemented with `mmsg` events; click, scroll, active/focused semantics, and monitor targeting still need runtime verification.
- **Labwc:** the workspace module is intentionally hidden because Quickshell 0.3.1 crashes when loading ext-workspace. Hikai itself must start and remain stable.

> **Super+Esc** works independently of the backend and always exits Hikai to Classic.

> M3 requirement: QS's `NotificationServer` must claim the D-Bus name `org.freedesktop.Notifications` **before** swaync is disabled and `QS_ALLOW_SWAYNC` is removed; at that point `--verify` must block swaync again.

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

# HakuSpace × Quickshell — Implementation Plan & Status

> Master plan for the **Hikai** backend (Quickshell). Written by Claude, implemented by Gemini, directed by the user.
> **Synced with the code at commit `bee8b633` (2026-10-05) plus the working tree.** The code is the source of truth: where this document and the code disagree, the code wins and this document should be corrected.
> Items marked **VERIFY** have not been verified yet and must be probed before use. Items marked **(observation)** describe behaviour that exists in the code today but was not asked for or looks suspicious; they are listed in Appendix C and have **not** been changed.
> Companion documents in `docs/task/`: `M2_PLAN.md` (top bar), `FLARE_LIB_SPEC.md` (flare/morph library), `quickshell-testing.md` (manual checks), `quickshell_style.md` (tokens/style).

---

## 0. Status at a glance

| Milestone | Scope | Status |
|---|---|---|
| **M0** | Backend switch, guards, supervisor, facades, autostart, emergency key | **Done** (tested on real machine) |
| **M1** | `Theme`/`AppState` singletons, theme JSON, picker + `haku_pick.sh` | **Done** (tested). `haku_pick.sh` works but **no script calls it yet** (see M4) |
| **M2** | Top bar (`top`) | **In progress** — see table below and `M2_PLAN.md` |
| **Flare lib** | `components/flare/*`, tooltip layer, `FlareGeometry.js` + node tests | **Done through L2.1** (tooltip migrated). Hardening L3 partly done; L4 (demo + `docs/flare.md`) and `FlareWindow` pending |
| **M3** | Notification server, control center | Not started. `swaync` is allowed in Hikai via `QS_ALLOW_SWAYNC=1` until then |
| **M4** | Launcher, HakuMenu, power menu, wallpaper picker, migrate `rofi -dmenu` call-sites to `haku_pick` | Not started. `launcher.sh`/`notif.sh` exist but their QS IPC targets do not |
| **M5** | Rounded screen (done early), edge trigger, cava layer, taskbar, OSD | `RoundedScreen.qml` done; the rest not started |
| **M6** | Desktop icons, other bar variants, polish | Not started |
| **M7** | Packaging (`pkg-quickshell`), `doctor.sh`, nix, EN+VN docs, 4-WM test | Not started (no `quickshell` reference yet in `install.sh`, `doctor.sh`, `src/packages/*`, `nix/`, `README`) |

M2 module status (as built):

| Module | Status | Notes |
|---|---|---|
| Logo | Done | Click → `UiState.toggle("hakumenu")`; no panel consumes it yet |
| Workspaces | **Rework planned** | Morphing "worm" indicator; Hyprland + Niri only, known bugs. Multi-WM rework (4 WM, per-slot click + tooltip): `M2_WORKSPACES_PLAN.md` |
| WindowTitle | Done (not in original plan) | Shows class + title; **Hyprland only** (data from `WM`) |
| Tray | Done | `SystemTray` + `IconImage`; right-click uses `item.display()` |
| Settings group | Done | Backlight / volume / battery in one accent pill + power-profile module; no drawer |
| Recorder | Done | Polls `/tmp/recording_pid` every 1 s; click runs `record.sh` |
| Clock | Done | Stacked two-line layout; tooltip is still a text placeholder (no calendar grid) |
| Notification | **Stub** | Static module, no data |
| Music (mpris) | **Stub, not mounted** | `MusicGroup.qml` is a placeholder |
| Cava | **Exists, not mounted** | `CavaGroup.qml` works standalone but was removed from the bar layout |
| Monitor (cpu/ram/temp) | **Exists, not mounted** | Removed from the layout by user request; `SysStats` + `HDrawer` kept |
| Mango / Labwc workspaces | Not supported | `WM.supported = false` on anything except Hyprland/Niri |

---

## 1. Working rules (read before coding)

1. **Work sequentially by milestones.** Each milestone is its own group of commits with acceptance criteria (section 10). Do not start the next one early.
2. **The `classic` backend must keep 100 % of its behaviour.** Do not rename existing files, flags or state files (the one exception, `haku_shell_mode.sh` → `haku_space_mode.sh`, was requested by the user and keeps a deprecated shim).
3. **Do not guess Quickshell APIs.** Check docs for the installed version (`quickshell --version`; docs known up to v0.3.1). Probe when unsure; **VERIFY** means probing is mandatory.
4. **Code defensively** (null checks, log errors, no crash on missing files). Gemini may run commands on the user's machine (it has done so for `haku_backend.sh set hikai`), but graphical results still need the user's confirmation: list manual checks in `quickshell-testing.md` and state clearly what was **not** run.
5. **Run `scripts/precommit_check.sh` before every commit** (debug-code grep, untracked source files, junk files in the repo root, `qml_syntax_check.py`, `node scripts/test_flare_geometry.js`, `bash -n`). Also read your own `git diff` end to end.
6. **No regex/string-patch scripts on QML files.** Edit in place and re-read the result (this caused three broken hand-offs).
7. **Do not refactor outside scope.** Note pre-existing bugs under "Observations".
8. **Ask the user when stuck.** State assumptions.
9. Code comments in **English**; docs in `docs/` have EN and VN versions (the task docs here are working documents).
10. Bash style: shebang `#!/usr/bin/env bash`, `-h|--help`, state files contain `0|1`, `source haku_theme.sh` for `STATE_DIR`/`THEME_RENDER_DIR`. Script names must be **globally unique** in `src/core/**` (deployed flat into `~/.local/bin`).
11. **No hard-coded colours/durations/radii in QML**; use `Theme.*` / `HAnimation.*` tokens (known exceptions listed in `quickshell_style.md`).
12. **Panels that attach to the bar or to the screen edge must use the Flare library** (`FlareHost`); do not hand-roll flare/morph maths in a consumer.

---

## 2. Goals, non-goals, constraints

### Goals
- A **second backend** named **Hikai** (Quickshell). `classic` stays; the user can switch on the fly and the choice survives reboot.
- **Centralised architecture:** in Hikai, TopBar, RoundedScreen, Picker (and later notifications, launcher, menus, cava layer, taskbar, desktop icons) run **inside a single `qs` process**.
  - `RoundedScreen.qml` is native to Hikai and unrelated to the classic Python `rounded_screen.py`.
- These classic apps are **blocked** in Hikai: `waybar`, `taskbar`, `rofi`, and the four Python GTK apps (`edge_trigger.py`, `rounded_screen.py`, `cava_layer.py`, `desktop_icons.py`). **`swaync` is temporarily allowed** (D-Bus activation re-spawns it; see D2 and Risks).
- Modern look: animations, unified theme from the existing colour pipeline, shared flare/morph behaviour across all panels that live in the work area.

### Non-goals
- No removal of classic code or packages. No new lock screen (`hyprlock` via `lock.sh` stays), no wallpaper drawing (`awww`/`mpvpaper`), no replacement of `hypridle`, `polkit`, `fcitx5`, `nm-applet`, `blueman-applet`, `wl-paste`/`cliphist`.
- No 1:1 port of all 7 waybar modes and 4 rofi themes at the start.

### Hard constraints
- Four compositors supported at minimum: **Hyprland, Niri, MangoWM, Labwc** (currently only Hyprland and Niri have workspace data; see Risks).
- Deploy mechanism: `src/core/**` is copied/symlinked **flat** into `~/.local/bin`.
- Naming: the aesthetic mode is **"Haku Space Mode"** (`haku_space_mode.sh`, state `haku_space_state`; `haku_shell_mode.sh` is a deprecated shim, and `session_start.sh` migrates `haku_shell_state` → `haku_space_state`). "Change Shell" (login shell fish/zsh) is separate. The new concept is the **backend** (`haku_backend.sh`, state `shell_backend`, value **`hikai`**; the menu label is "Hikai Backend").

---

## 3. Repo facts (verified)

### 3.1 Layout & deploy
- `src/core/{app,lib,menu,sys,theme,util}/*` → `~/.local/bin` (flat). `src/home/.config/*` → `~/.config/*`, except `ONCE_CONFIGS` (Thunar, xfce4, mpv, btop, cava, mimeapps.list) and `SKIP_CONFIGS` (hypr, niri, mango, labwc, gtk-3.0). `src/home/.config/quickshell/hakuspace/` is deployed by the general rule.
- User configs live in `~/hakucfg/` (templates `src/home/hakucfg/`); `setting.sh` has `SETTING_VERSION`.
- `scripts/` holds repo tooling: `precommit_check.sh`, `qml_syntax_check.py`, `test_flare_geometry.js`, `qs_picker_probe.sh`, `variables.sh`, `functions.sh`.

### 3.2 State
- `STATE_DIR = ~/.local/state/hakuspace/state/`; theme output in `~/.local/state/hakuspace/theme/` (`THEME_RENDER_DIR`, output only, never read back).
- State files read by QML (`AppState.qml`, via `FileView` + `watchChanges`): `waybar_manual_state` (default 1), `opaque_theme_state` (default 0), `rounded_screen_state` (default 0 in QML), `rounded_screen_dynamic_state` (default 1). Rounded-screen geometry comes from `~/hakucfg/config/rounded-screen.conf` (`border_thickness`, `border_radius`; QML defaults 4 and 20).
- Backend: `shell_backend` (`classic` | `hikai`). Migration helper: `haku_shell_state` → `haku_space_state`.
- Other `/tmp` files read cross-process: `/tmp/recording_pid`, `/tmp/recording_time` (Recorder module), `/tmp/cava-layer.pid` (cava toggle compatibility; reset by `session_start.sh` and `haku_backend.sh`), `/tmp/random_wallpaper_status`.

### 3.3 Manager pattern and guards
`waybar_`, `taskbar_`, `edge_trigger_`, `rounded_screen_`, `desktop_icons_`, `cava_manager.sh` keep their CLI (`--startup`, `--toggle`, `--reload`, `-h`) and state files; in Hikai they only update state (guard `haku_qs_mode`) and never launch the classic app. (10 guard call-sites across the six managers.)

### 3.4 Autostart and keybinds
- All four autostarts (`hypr/config/autostart.lua`, `niri/autostart.kdl`, `labwc/autostart`, `mango/autostart.conf`) call `session_start.sh --early` instead of launching `swaync` directly.
- Keybinds use the facades `launcher.sh` (Super+R, Super+/) and `notif.sh` (Super+N). Emergency key **Super+Esc → `haku_backend.sh set classic`** exists in all four WMs.
- In Hikai, `launcher.sh`/`notif.sh` call IPC targets that **do not exist yet** (`launcher`, `notif`): the keys do nothing until M3/M4 (documented in `quickshell-testing.md`).

---

## 4. Architecture decisions (as built)

**D1 — Backend state.** `$STATE_DIR/shell_backend` holds `classic` or `hikai`. `haku_backend_lib.sh` is the only place that defines the value (`QS_BACKEND_NAME="hikai"`); scripts ask via `haku_qs_mode` / `haku_backend_is`. `haku_qs_alive` matches only `qs|quickshell … -c hakuspace` (anchored regex, so other Quickshell configs and editors are not matched).

**D2 — Blocking in three layers.**
1. `session_start.sh --early` starts the stack for the chosen backend (classic: `swaync`; Hikai: optional `swaync` + `qs_supervisor.sh`).
2. Guards in the six managers (`haku_qs_mode` → state only).
3. Facades (`launcher.sh`, `notif.sh`, `haku_pick.sh`) branch on backend.
`haku_backend.sh --verify` lists forbidden processes. **Temporary exception:** `QS_ALLOW_SWAYNC=1` (exported by `haku_backend_lib.sh`, marked `TEMP, remove at M3`): swaync is not killed on switch, is started by `session_start.sh`, and is ignored by `--verify`. Reason: swaync ships a D-Bus activation file for `org.freedesktop.Notifications`; with no notification server in QS, any `notify-send` would respawn it. **M3 must have QS claim the D-Bus name first, then kill swaync and remove the flag.**

**D3 — Facades keep the old CLI** so `haku_space_mode.sh`, `hm_*.sh`, `change_theme.sh` and keybinds keep working.

**D4 — State files for toggles, IPC for instant actions.** Managers are the only writers of toggle state files; QML reads them with `FileView` (`AppState`), so it works even when IPC fails. Instant actions use `qs -c hakuspace ipc call <target> <fn> [args]` (section 6). QML-owned state (e.g. future DND) is not implemented yet; there is **no `StateFile` helper** (each flag is a `FileView` in `AppState`).

**D5 — `haku_pick` replaces `rofi -dmenu`.** Classic → rofi; Hikai → picker overlay in QS via IPC + FIFO (section 7). **Call-sites are not migrated yet** (Appendix A.1).

**D6 — Script-mode protocol.** `hm_general.sh`, `hm_theme.sh`, `hm_setting.sh` print a list with no arg and act with an arg; QML will run them as-is in M4 (no menu logic rewritten in QML).

**D7 — Theme via JSON.** `gen_style.sh` → `render_quickshell` writes a **flat** `quickshell.json` atomically (`jq` → `.tmp` → `mv`). `Theme.qml` watches it with `FileView` and maps keys (see `quickshell_style.md`). QML never parses `state.env`.

**D8 — Supervisor and fallback.** `qs_supervisor.sh` loops `qs -c hakuspace`; waits if a hakuspace instance already runs; exits when the backend is no longer Hikai; 3 crashes within 60 s → `haku_backend.sh set classic`. `session_start.sh` and `set hikai` start it only if `qs_supervisor.sh` is not already running.

**D9 — Flare library** (`components/flare/*`): geometry (pure JS, node-tested) / surface / morph / content / host. Every panel attached to the bar uses `FlareHost`. See `FLARE_LIB_SPEC.md`.

**D10 — Tooltip surface inside the bar window.** `TopBar` is a *tall, transparent* `PanelWindow` (`barH + tipAreaH`, `tipAreaH = 160`) with `exclusiveZone = barH` and `mask: Region { item: barBg }`, so the extra strip is click-through and tooltips are drawn in the same surface as the bar (seamless flare, no popup, no per-frame surface reconfigure). Namespace `hakuspace-bar` (no Hyprland layer rule exists for it; **VERIFY** blur behaviour if the user enables layer blur).

**D11 — Pre-commit gate.** `scripts/precommit_check.sh` (see rule 5).

---

## 5. Roadmap

### M0 — Backend scaffolding — **Done**
`haku_backend_lib.sh`, `haku_backend.sh` (`set`, `--toggle`, `--check`, `--verify`, `--recover`), `session_start.sh`, `qs_supervisor.sh`, six manager guards, `launcher.sh`/`notif.sh` facades, four autostarts, emergency keybind ×4, `apply_style.sh` guard (swaync reload only in classic), `exit.sh` kill list (`qs -c hakuspace`, `quickshell`, `qs_supervisor.sh`), `open_config.sh`, menu entry "Hikai Backend (classic/hikai)" in `hm_theme.sh`.

### M1 — Theme, state, picker — **Done**
`Env`, `Theme`, `AppState` singletons; `renderer quickshell` in `gen_style.sh`; `Picker.qml` overlay (`PanelWindow`, layer Overlay, exclusive keyboard focus, filter, ↑/↓/Enter/Esc, password and no-custom modes; result written to a FIFO through a `Process` using the `HAKU_PICK_TEXT` environment variable); `haku_pick.sh`. Not part of M1 anymore: converting scripts to `haku_pick` (moved to M4).

### M2 — Top bar — **In progress** (details in `M2_PLAN.md`)
Mounted: Logo, Workspaces, WindowTitle (left); Tray, Settings group (+ power profile), Recorder, Clock, Notification stub (right). Center row is empty. Not mounted: Music, Cava, Monitor.
Remaining: real Notification data (needs M3 or swaync bridge), Music/Cava decision, calendar tooltip, Mango/Labwc workspaces, tray middle-click/menu polish, resource gating of pollers.

### Flare library — **Done through L2.1**
See `FLARE_LIB_SPEC.md` for L0–L4 status.

### M3 — Notifications — Not started
`NotificationServer` in QML claiming `org.freedesktop.Notifications` **before** swaync is killed; popup + history + DND; control center; `notif.sh` IPC; remove `QS_ALLOW_SWAYNC`.

### M4 — Launcher & menus — Not started
`launcher` (drun/emoji), `hakumenu` (script-mode), `power`, `wallpaper` (with `--list-json`), `picker` call-site migration (Appendix A), `FlareWindow` for large panels (see `FLARE_LIB_SPEC.md` §5).

### M5 — Aesthetic modules — Partially done
`RoundedScreen.qml` is done (Canvas corners + stroke, three spacer `PanelWindow`s on layer Bottom, layer Top when dynamic / Overlay otherwise, `mask: Region {}`, geometry from `rounded-screen.conf`). Edge trigger, cava layer, taskbar, OSD: not started.

### M6 / M7 — Not started
Desktop icons, extra bar variants; packaging, `doctor.sh`, `update.sh`/`rollback.sh`, nix, docs, 4-WM test.

---

## 6. IPC contract

Implemented (`shell.qml`):

| target | function | notes |
|---|---|---|
| `shell` | `ping() → "pong"`, `reload()` (`Quickshell.reload()`), `quit()` | `ping` is the health check of `haku_backend.sh` / `session_start.sh` |
| `picker` | `open(fifo: string, jsonString: string)` | JSON: `prompt`, `items[]`, `password`, `noCustom`, plus `width/height/selected/lines` (sent by `haku_pick.sh`, currently ignored by the picker) |

Planned (not implemented): `launcher.open(mode)`, `hakumenu.toggle/open(tab)`, `power.toggle`, `wallpaper.toggle`, `notif.toggleCenter/toggleDnd/clearAll/count`, `bar.cycle/select`. `UiState.activePanel` exists as the in-process equivalent for panels.

Command form: `qs -c hakuspace ipc call <target> <function> [args…]`.

---

## 7. Picker protocol (`haku_pick.sh`)

`haku_pick.sh [--prompt T] [--password] [--no-custom] [--width W] [--height H] [--selected N] [--lines N]` reads items from stdin and prints the chosen line; **exit 1 on cancel**.
- Classic: `rofi -dmenu -i -p … -theme option-menu.rasi` with the flags mapped.
- Hikai: build `pick_req_$$.json` (jq) and a FIFO `pick_fifo_$$` in `$XDG_RUNTIME_DIR/hakuspace/`; `timeout 3 qs -c hakuspace ipc call picker open <fifo> <json>` (stderr appended to `qs.log`); then wait on the FIFO with `IFS= read -r -t 1`, exiting 1 if QS dies (`haku_qs_alive`). There is **no overall time limit** (a human may take their time). The picker writes the chosen line verbatim, or `__CANCEL__` on Esc / hide. Temp files are removed by `trap`.

---

## 8. Supervisor logic (as built)
`qs_supervisor.sh`: loop { exit if backend ≠ Hikai; if a hakuspace instance is alive, wait for it to exit; run `qs -c hakuspace >> qs.log`; exit if the backend changed meanwhile; track crash timestamps; ≥ 3 within 60 s → `haku_backend.sh set classic`, exit 1; sleep 1 }. Log: `$XDG_RUNTIME_DIR/hakuspace/qs.log`.

---

## 9. QML folder structure (as built)

```
src/home/.config/quickshell/hakuspace/
├── shell.qml                      Picker, IpcHandlers, Variants{TopBar}, Variants{RoundedScreen}
├── services/                      (qmldir lists singletons explicitly)
│   ├── Env.qml  Theme.qml  AppState.qml  HAnimation.qml  UiState.qml
│   ├── SysStats.qml               cpu/ram/temp, acquire()/release() ref-counted
│   ├── TooltipManager.qml         tooltip timing state machine (show 400 ms, grace 120 ms, warm 300 ms)
│   ├── FlareEdges.qml             bounds from Rounded Screen thickness
│   └── WM/WM.qml                  Hyprland + Niri adapter (workspaces, active window)
├── components/
│   ├── TopBar.qml  TopModule.qml  RoundedScreen.qml
│   ├── base/   HButton  HPanel  HDrawer  HTooltip  TooltipLayer
│   ├── flare/  FlareGeometry.js  FlareSurface  FlareMorph  FlareContent  FlareHost
│   └── top/    Logo Workspaces WindowTitle TrayGroup SettingsGroup RecorderGroup ClockGroup
│               NotificationGroup(stub) MusicGroup(stub) MonitorGroup CavaGroup  (last four not mounted except the stub)
└── modules/picker/Picker.qml      (+ qmldir)
```
Planned but absent: `modules/{notif,launcher,hakumenu,power,wallpaper}`, `assets/`, `FlareWindow.qml`, `WorkspacePill.qml` (workspace pills are drawn inside `Workspaces.qml`).

---

## 10. Acceptance criteria
- **M0–M1:** switch back and forth cleanly; `haku_backend.sh --verify` passes in Hikai; picker works twice in a row and cleans up; theme and state files react live. *(met)*
- **M2–M4:** bar replaces waybar `top`; notifications and launcher replace swaync/rofi in Hikai. *(M2 partial; M3–M4 pending)*
- **M5–M7:** parity with classic, stable fallback, packaging and docs.
- **Always:** `scripts/precommit_check.sh` green; `qs.log` has no `TypeError`/`ReferenceError`; classic unchanged.

---

## 11. Test matrix
Per `quickshell-testing.md`. Across **Hyprland, Niri, Mango, Labwc**, both switch directions, and one reboot: switch in-session; bar, workspaces, tray (nm-applet, blueman-applet, fcitx5); notifications (from `notify-send`, `screenshot.sh`, `record.sh`) and DND; Super+R / Super+/ / Super+N / Super+V / F11; live accent/wallpaper change; opaque on/off; Haku Space Mode on/off; edge trigger (M5); multi-monitor hotplug; `lock.sh` and `exit.sh`; recovery (kill QS, crash loop). Currently exercised mainly on Hyprland.

---

## 12. Code conventions
- QML: one component per file, PascalCase; singletons `pragma Singleton` and listed in `services/qmldir`; new top modules must be added to `components/top/qmldir`.
- No polling while hidden (see Observations: Settings and Recorder still poll unconditionally); `Process`/`FileView` must tolerate missing files (`printErrors: false`).
- No `~` in paths: use `Env.*` / `Quickshell.env`.
- Bash: `command -v` before external tools; spawn helper `( "$@" & ) >/dev/null 2>&1`.
- Debug output only through a gated helper (`dbg()` + `HAKU_DEBUG=1`); the pre-commit check rejects stray `console.log`.
- Copy Nerd Font glyphs from the original files; do not retype them.

---

## 13. Install, update, rollback, doctor, docs, nix (**not done yet**)
- Packaging: none of `src/packages/*`, `install.sh`, `update.sh`, `doctor.sh`, `rollback.sh`, `nix/`, `README.md` mention Quickshell. Needed: `quickshell` (Arch `extra` 0.3.x; **VERIFY** name per distro), Qt deps pulled automatically (`qt6-declarative`, `qt6-svg`, `qt6-wayland`), `cava`, `jq`, `brightnessctl`, `wl-clipboard`, `cliphist`, `node` (for the flare tests only, dev dependency). Mirror the OPTIONAL package handling in `install.sh`.
- `doctor.sh`: check `qs`, deployed QML directory, `qs -c hakuspace ipc show`, `--verify` result.
- `setting.sh`: bump `SETTING_VERSION` if new variables are added.
- Docs: `docs/core/quickshell.md` (+ `docs/vietnamese/VN_quickshell.md`), update `docs/architecture.md`, `README.md`, Fedora/NixOS guides.

---

## 14. Risks and open questions

### Risks
1. **Single point of failure:** QS crash loses bar/launcher. Mitigated by D8, `qs.log`, emergency key.
2. **D-Bus name collision for notifications** (swaync vs QS): handled by `QS_ALLOW_SWAYNC` until M3.
3. **Workspaces on Mango/Labwc** have no verified data source.
4. **Tray menus** use `item.display()` (native menu); themed menus (`QsMenuOpener`) are not done.
5. **Desktop icons + drag and drop** on layer-shell.
6. **Hyprland pointer grab** with exclusive-keyboard surfaces (edge trigger, large panels).
7. **Layer blur on the tall bar window:** no Hyprland rule exists for `hakuspace-bar`; if layer blur is enabled, the transparent strip could be blurred (**VERIFY**).
8. **Panels in separate windows** (menus, M4) meet the bar along a surface seam; check for hairlines at fractional scale.

### Open questions (defaults chosen; user may change)
- **Q1 Desktop icons in Hikai:** off until M6.
- **Q2 Bar variants at launch:** only `top`.
- **Q3 Multi-monitor:** bar and rounded screen on every screen; tooltip layer only on the bar that owns the hovered module; edge trigger primary-only.
- **Q4 OSD:** optional, M5.
- **Q5 Music/Cava/Monitor modules:** currently not mounted. Decide whether to restore (drawer), fold into another group, or delete.

---

## 15. Report template per milestone/step
1. New and modified files (one-line reason each).
2. **Real output** of `scripts/precommit_check.sh` (or "not run").
3. VERIFY items handled: conclusion + source.
4. What could not be tested (needs the user's screen) → add to `quickshell-testing.md`.
5. Assumptions and deviations from the plan.
6. Observations about existing bugs (do not fix).
7. Proposed next steps.

---

## Appendix A — Call-sites (status)

### A.1 `rofi -dmenu` → `haku_pick` — **not migrated** (all still call `rofi -dmenu`; classic-safe)
`util/clipboard_menu.sh`, `util/record.sh` (×2), `util/shell_switcher.sh` (×2; one is a sudo password → `--password`), `util/gen_shortcut.sh`, `sys/exit.sh`, `theme/change_theme.sh` (×4), `app/taskbar/taskbar_manager.sh`, `util/waybar_manager.sh` (`--select`), `sys/shutdown.sh` (→ `power` in QS), `theme/rofi_theme_switcher.sh` (rofi-only: hide in Hikai).

### A.2 `rofi -show …` → QS modules — **not migrated**
`menu/hakumenu.sh` (script-mode → `hakumenu`), `theme/wallpaper_select.sh` (→ `wallpaper` + `--list-json`), `theme/niri_animation_switcher.sh` (M6), `menu/hm_general.sh` (`rofi -show drun` → `launcher.sh drun`). Keybinds already use `launcher.sh` (done).

### A.3 `swaync-client`
`notif.sh` (classic branch only), `apply_style.sh` (classic only — done), `edge_trigger.py` and `swaync/config.json` and `waybar/module/notification_module` (classic-only by design).

### A.4 Other references
`desktop_icons.py` (off in Hikai), `util/open_config.sh` (done), `sys/exit.sh` (done), `theme/opaque_theme.sh` (classic renderers kept).

### A.5 Minor observations (fyi)
- `labwc/autostart` calls `fcitx5 -d` twice.
- `menu/hm_general.sh` fallback calls `notify-send` on every run if `~/hakucfg/general-menu.sh` is missing → repeated toasts.

---

## Appendix B — File inventory

**Created (shell side):** `src/core/lib/haku_backend_lib.sh`, `src/core/lib/haku_pick.sh`, `src/core/sys/haku_backend.sh`, `src/core/sys/session_start.sh`, `src/core/sys/qs_supervisor.sh`, `src/core/util/launcher.sh`, `src/core/util/notif.sh`, `src/core/theme/haku_space_mode.sh` (+ deprecated shim `haku_shell_mode.sh`), `scripts/precommit_check.sh`, `scripts/qml_syntax_check.py`, `scripts/test_flare_geometry.js`, `scripts/qs_picker_probe.sh`.
**Created (QML):** the tree in section 9.
**Still to create:** `src/packages/pkg-quickshell.txt`, `scripts/check_no_rofi_in_qs.sh`, `docs/core/quickshell.md`, `docs/vietnamese/VN_quickshell.md`, `docs/flare.md`, `FlareWindow.qml`, `modules/{notif,launcher,hakumenu,power,wallpaper}`.

---

## Appendix C — Observations (code today; not changed)

1. **`WM.activate()` compares `Env.wmName === "hyprland"`** (raw value) while the rest of `WM.qml` uses the lower-cased `_wm`. On Hyprland `XDG_CURRENT_DESKTOP` is `Hyprland` (set in `hypr/config/environment.lua`), so by reading the code the click/scroll on workspaces would not dispatch on Hyprland (Niri's value is already lower-case). **VERIFY** on the machine; likely fix: compare `_wm`.
2. **`HAnimation` curves have 4 numbers** (`[0.38, 1.21, 0.22, 1.0]`, `moduleCurve`, …). Qt's `easing.bezierCurve` takes control points plus the end point (groups of 6: `…, 1, 1`). **VERIFY** that the curves are actually applied (they may fall back silently).
3. **Pollers are not gated by visibility:** `SettingsGroup` runs a 2 s `Timer` + `Process` (sysfs brightness, `wpctl`, `powerprofilesctl`) permanently; `RecorderGroup` runs a 1 s `bash` poll permanently. The M2 plan asked for polling only when needed (`SysStats` is the only ref-counted poller, and it is not mounted).
4. **Tray middle-click** is not handled (`TopModule` accepts left/right buttons only); tray menus use the native `display()`.
5. **`TopModule` contains hard-coded colours** (`#ff3333` urgent, `#000000` accent-hover, `#ffffff`); `RoundedScreen` fills with `#000000`.
6. **Tooltip max width is 400** (`TooltipLayer`), not 360 as in the original spec.
7. **`haku_pick.sh` ignores `--width/--height/--selected/--lines` in Hikai** (they are sent in the JSON but the picker does not use them).
8. **`Env.wmName` defaults to `"Hyprland"`** when `XDG_CURRENT_DESKTOP` is empty.
9. **`hm_theme.sh`** reads `shell_backend` directly instead of sourcing the lib (cosmetic).
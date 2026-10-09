# HakuSpace × Quickshell — Implementation Plan (for Gemini)

> This document is the **spec + roadmap** written by Claude, Gemini is the coder.
> Everything in section 2 and Appendix A has been read directly from the `hakuspace` source repo (release v26.09-2). Where it says **VERIFY**, it means it hasn't been verified yet, Gemini must check before using.

---

## 0. Working Rules (read before coding)

1. **Work sequentially by milestones (M0 → M7).** Each milestone is a separate group of commits, with its own acceptance criteria (section 9). Do not start the next milestone beforehand.
2. **The `classic` backend must retain 100% of its behavior.** All modified scripts must run exactly as before when the backend is `classic` (default). Do not change existing file names, flags, or state files.
3. **Do not guess Quickshell APIs.** Check the docs for the exact installed version (`quickshell --version`; latest known docs is v0.3.1). If unsure, write a small QML probe file to test. Where it says VERIFY, probing is mandatory.
4. **Gemini does not have a Wayland screen to test.** Write defensive code (null checks, error logging, no crashing on missing files). For each milestone, write a manual test checklist in `docs/quickshell-testing.md` for the user to run. If runnable, run `bash -n`, `shellcheck`, `qmllint`.
5. **Do not refactor outside the scope.** If you find pre-existing bugs in the repo, note them in the "Observations" section of the report, do not mix in fixes.
6. **Ask the user when stuck** instead of making things up. State any assumptions being made.
7. Write code comments in **English** (matching repo style). Documentation in `docs/` has EN and VN versions.
8. Follow the repo's bash style: shebang `#!/usr/bin/env bash`, support `-h|--help`, state files contain `0|1`, `source haku_theme.sh` to get `STATE_DIR`, `THEME_RENDER_DIR`.

---

## 1. Goals, Non-goals, Constraints

### Goals
- Add a **second backend** for HakuSpace named **Hikai** (using Quickshell). The old backend (`classic`) remains and is not replaced.
- **Centralized Architecture:** In the `hikai` backend, **all modules (TopBar, RoundedScreen, Cava, Picker, Desktop Icons...) run together inside a single `qs` (Quickshell) process.**
  - **IMPORTANT CONCEPT NOTE:** In Hikai, `RoundedScreen.qml` is an integral, native part of the shell architecture itself. It is conceptually and technically separated from the standalone classic "mini-apps" (like the Python `rounded_screen.py` or `edge_trigger.py`). Hikai renders its own rounded corners natively within Quickshell.
- The following Classic apps are **blocked and must not run** in Hikai: `waybar`, `taskbar`, `swaync`, `rofi`, and the 4 Python GTK layer-shell apps (`edge_trigger.py`, `rounded_screen.py`, `cava_layer.py`, `desktop_icons.py`).
- Switch back and forth between the 2 backends on-the-fly (without logging out), and remember the choice across reboots.
- More modern UI, with animations, unified theme matching the existing color pipeline.

### Non-goals (will not do)
- Do not remove old packages, do not delete classic code.
- Do not make a new lock screen (keep `hyprlock` via `lock.sh`), do not draw wallpaper (still `awww`/`mpvpaper`), do not replace `hypridle`, `polkit`, `fcitx5`, `nm-applet`, `blueman-applet`, `wl-paste`/`cliphist`.
- Do not port 1:1 all 7 waybar modes and 4 rofi themes from the start (see M2, M6).

### Hard Constraints
- All 4 compositors must be minimally supported: **Hyprland, Niri, MangoWM, Labwc**.
- Must be compatible with the deploy mechanism: `src/core/**` is copied/symlinked **flat** into `~/.local/bin`, so **file names must be unique across the repo**.
- Naming concepts: the repo already has **"Haku Space Mode"** (`haku_space_mode.sh`: groups rounded-screen + cava + opaque + edge-trigger) and **"Change Shell"** (changing login shell fish/zsh). Our new concept is called **"backend"** (`haku_backend.sh`, state `shell_backend`). Do not use the word "shell mode" for it.

---

## 2. Repo Facts (verified)

### 2.1 Layout & deploy
- `src/core/{app,lib,menu,sys,theme,util}/*` → deployed **flat** into `~/.local/bin` (`find "$SOURCE_CORE" -type f`).
- `src/home/.config/*` → `~/.config/*`. Exceptions in `scripts/variables.sh`:
  - `ONCE_CONFIGS` (deploy only once): Thunar, xfce4, mpv, btop, cava, mimeapps.list.
  - `SKIP_CONFIGS` (deploy separately): hypr, niri, mango, labwc, gtk-3.0.
- The new QML directory `src/home/.config/quickshell/hakuspace/` will **auto-deploy** following the general rule (not in those 2 lists).
- User configs: `~/hakucfg/` (templates in `src/home/hakucfg/`). `update.sh` does not touch `~/hakucfg`. The file `hakucfg/setting.sh` has `SETTING_VERSION` (currently `26.09-2`) used by `update.sh` to check old settings → **if adding new variables to `setting.sh`, read `update.sh` to see how to bump the version**.
- WM configs (4 WMs) have an `include` line pointing to custom files in `~/hakucfg/wm/*-custom.*`.

### 2.2 State
- State directory: `~/.local/state/hakuspace/state/` (variable `STATE_DIR` in `src/core/lib/haku_theme.sh`). Theme source of truth: `state.env` (`ACCENT_COLOR`, `FONT_FAMILY`, `FONT_SIZE`).
- Theme render files (output only, **never read back**): `~/.local/state/hakuspace/theme/` (`THEME_RENDER_DIR`).
- Existing toggle state files (content `0|1`, in `$STATE_DIR`):
  `haku_space_state`, `rounded_screen_state`, `rounded_screen_dynamic_state` (default 1), `edge_trigger_state`, `taskbar_manual_state`, `waybar_manual_state` (default 1), `waybar_current_mode` (string, default `top`), `desktop_icons_state`, `opaque_theme_state`, `cava_top_state`, `cava_dynamic_state`, `cava_color_state` (default 1 = accent).
- Cava toggle **does not have a state file**: relies on the existence of `/tmp/cava-layer.pid` (both `hm_theme.sh` and the swaync button read this file).
- Other `/tmp` files being cross-read: `/tmp/random_wallpaper_status`, `/tmp/recording_pid`, `/tmp/recording_time`.
- Taskbar: JSON theme at `~/.local/state/hakuspace/taskbar-theme` (`icon-size`, `format` with/without `{name}`), pinned apps list at `~/hakucfg/config/taskbar-pin-apps` (waybar JSON module format, e.g., `image#kitty` with `exec: taskbar_geticon.sh kitty`, `on-click`).
- Rounded screen: `~/hakucfg/config/rounded-screen.conf` (ini `[Settings]`: `border_thickness`, `border_radius`, `dynamic_position`).
- Edge trigger: **config is in the `CONFIG` + `SAFE_ZONES` dict right at the top of `edge_trigger.py`**, no external config file yet.

### 2.3 `*_manager.sh` Pattern
All managers (`waybar_`, `taskbar_`, `edge_trigger_`, `rounded_screen_`, `desktop_icons_`, `cava_`) share a pattern: state file `0|1`, `--startup` (restore according to state), `--toggle`, `--reload`, `-h`. They launch/kill using `pgrep/pkill -f <bin path>` (taskbar is a symlink `~/.local/bin/taskbar` pointing to waybar). **This is the centralized blocking point** — see D2.

### 2.4 Autostart & keybinds touching old stack
- 4 autostart files: `hypr/config/autostart.lua`, `niri/autostart.kdl`, `labwc/autostart`, `mango/autostart.conf`. Each has: `swaync` (run directly), and the lines `rounded_screen_manager.sh --startup`, `edge_trigger_manager.sh --startup`, `taskbar_manager.sh --startup`, `waybar_manager.sh`, `desktop_icons_manager.sh --startup`, then `welcome.sh` (uses `notify-send`) at the end.
- Keybinds **calling directly** to rofi/swaync (need to change to facade): `rofi -show drun` (Super+R), `rofi -modi emoji -show emoji` (Super+/), `swaync-client -t -sw` (Super+N) — in `hypr/config/keybinding.lua` (lines 21, 23, 27), `niri/keybinds.kdl` (28, 31, 32), `labwc/rc.xml` (271, 283, 286), `mango/bind.conf` (16, 20, 37).
- Remaining keybinds already go through scripts (`hakumenu.sh`, `wallpaper_select.sh`, `clipboard_menu.sh`, `record.sh`, `waybar_manager.sh --cycle|--toggle`, `taskbar_manager.sh --toggle`, `cava_manager.sh`...) so we only need to edit **inside the scripts**.

### 2.5 Call-sites list to handle → Appendix A.

---

## 3. Architecture Decisions

**D1 — One `shell_backend` state** (`classic` | `hikai`, default `classic`) at `$STATE_DIR/shell_backend`. All scripts query the backend via a single function in the new library `haku_backend_lib.sh`.

**D2 — 3-layer Blocking** ("prevent from running"):
1. *Dispatcher*: autostart only boots the stack for the correct backend.
2. *Guard in manager*: at the top of each `*_manager.sh`, if the backend is `hikai`, **do not launch the old app**; only update the state file and exit 0 (QML will react automatically, see D4).
3. *UI Facade*: every call to `rofi`/`swaync-client` goes through a facade script/`haku_pick` which branches based on backend.
   Plus a check tool: `haku_backend.sh --verify` lists forbidden processes still alive (used for acceptance and `doctor.sh`).

**D3 — Facade keeps old CLI.** `waybar_manager.sh`, `taskbar_manager.sh`, `edge_trigger_manager.sh`, `rounded_screen_manager.sh`, `cava_manager.sh`, `desktop_icons_manager.sh` keep their flags + state files, allowing `haku_space_mode.sh`, `hm_*.sh`, `change_theme.sh` and existing keybinds to continue working.

**D4 — State file control first, IPC for instant actions.**
- Toggle/settings (bar on/off, rounded, edge, taskbar, opaque, cava...): **manager script is the sole writer to the state file**; QML uses `FileView` + `watchChanges` to react and also reads the state on startup (replacing `--startup` mechanism). Pros: works even if IPC fails, state survives restarts.
- Instant actions (open launcher/menu/picker, toggle notification center...): `qs -c hakuspace ipc call <target> <fn> [args]` (see section 5).
- **New** states owned by QML (e.g., DND): QML writes them itself via the `StateFile` helper.

**D5 — `haku_pick` replaces all `rofi -dmenu`** (section 6). Classic → rofi; QS → picker in Quickshell via IPC + FIFO.

**D6 — Reuse script-mode protocol.** `hm_general.sh`, `hm_theme.sh`, `hm_setting.sh` (no arg → print list, with arg → execute) are executed directly by QML. Do not rewrite menu logic in QML in the early stages.

**D7 — Theme via JSON.** Add `quickshell` renderer to `gen_style.sh` outputting `$THEME_RENDER_DIR/quickshell.json`; QML watches the file. QML **does not** parse `state.env` or other render files (keeps "output only" rule).

**D8 — Supervisor + safe fallback.** A script `qs_supervisor.sh` runs `qs -c hakuspace` in a loop; if it crashes ≥3 times in 60s, it auto calls `haku_backend.sh set classic` then exits. Add an emergency keybind at the compositor level (check for key conflicts first) calling `haku_backend.sh set classic`, usable even if QS dies.

---

## 4. Execution Roadmap (Milestones)

### M0: Initialization & Architecture
- Create QML folder structure (`components/`, `services/`, `modules/`, `shell.qml`).
- Write `haku_backend_lib.sh` (contains `haku_qs_mode`).
- Write `haku_backend.sh set <classic|hikai>`.
- Update 6 managers with guards (D2).
- Write `qs_supervisor.sh`.
- Test: switch back and forth successfully, no QS UI yet but no classic apps running.

### M1: IPC & Global State (Theme, State, Picker)
- Write `Theme.qml` (watches JSON) and update `gen_style.sh`.
- Write `AppState.qml` (watches all `.state` files via `FileView`).
- Implement Picker module in QML.
- Write `haku_pick.sh` facade + update all scripts in A.1 to use it.
- Test: all old menus (theme, clipboard, etc.) appear in Quickshell UI when `hikai` mode is active.

### M2: TopBar - Left & Center
- Write `WM.qml` reading workspaces from Hyprland/Niri (M2.1) and Mango/Labwc (M2.2).
- TopBar Left: Workspace pill.
- TopBar Center: Clock & Cava widget.
- Integrate cava: QS spawns cava process internally and reads stdout.

### M3: TopBar - Right & Notifications
- TopBar Right: System tray, volume, brightness, battery, network.
- Write `notif.sh` facade.
- Implement Notification Server in QML (replaces swaync).
- Handle Super+N.

### M4: Launcher & OS Integration
- Write `launcher.sh` facade.
- Implement Launcher (drun/emoji) in QML (replaces rofi drun).
- Handle Super+R, Super+/.

### M5: Aesthetic Modules
- Implement Rounded Screen in QML.
- Implement Edge Trigger in QML.
- Implement OSD (Volume/Brightness popups).

### M6: Taskbar & Desktop Icons (Optional/Advanced)
- Implement Taskbar (Dock) in QML.
- Handle desktop icons if desired (or keep disabled).

### M7: Final Polish & Release
- Update `doctor.sh`, `update.sh`, `install.sh`.
- Finalize documentation.
- Rigorous testing across all 4 WMs.

---

## 5. IPC Architecture (Draft)
```bash
# Toggle Notification Center
qs -c hakuspace ipc call shell toggle_notif

# Open Launcher
qs -c hakuspace ipc call shell open_launcher "drun"
```

## 6. Picker (haku_pick.sh) Protocol
```bash
# haku_pick.sh receives standard rofi -dmenu stdin
echo -e "A\nB" | haku_pick.sh --prompt "Choose:"
```

---

## 7. Supervisor Logic
```bash
# qs_supervisor.sh
CRASH_COUNT=0
LAST_CRASH_TIME=$(date +%s)
while true; do
    qs -c hakuspace
    NOW=$(date +%s)
    if (( NOW - LAST_CRASH_TIME < 60 )); then
        ((CRASH_COUNT++))
    else
        CRASH_COUNT=1
    fi
    LAST_CRASH_TIME=$NOW
    if (( CRASH_COUNT >= 3 )); then
        notify-send "Quickshell crashed" "Falling back to Classic mode."
        haku_backend.sh set classic
        exit 1
    fi
    sleep 1
done
```

---

## 8. QML Folder Structure
```
src/home/.config/quickshell/hakuspace/
├── shell.qml
├── qmldir
├── services/
│   ├── Theme.qml
│   ├── AppState.qml
│   ├── WM.qml
│   └── qmldir
├── components/
│   ├── TopBar.qml
│   ├── RoundedScreen.qml
│   ├── WorkspacePill.qml
│   └── qmldir
├── modules/
│   ├── picker/
│   │   ├── Picker.qml
│   │   └── qmldir
│   ├── notif/
│   └── launcher/
└── assets/
```

---

## 9. Acceptance Criteria for Milestones
- **M0-M1**: Picker functions flawlessly, theme changes live, state updates correctly.
- **M2-M4**: TopBar fully replaces Waybar functionality, Launcher/Notif replace Rofi/Swaync.
- **M5-M7**: Complete parity with Classic mode, stable fallback, clean docs.

---

## 10. Test Matrix
Test matrix across **4 WMs** (Hyprland, Niri, Mango, Labwc), bidirectional backend switching, and one reboot:
- switch classic ↔ quickshell during session; reboot retains backend
- bar + workspaces + tray (nm-applet, blueman-applet visible)
- notifications from `notify-send`, `screenshot.sh`, `record.sh`; DND
- Super+R, Super+/, Super+N, Super+Tab, Super+Y, Super+V (clipboard), F11 (record)
- change accent/wallpaper → theme updates live
- opaque theme on/off
- Haku Space Mode on/off
- edge trigger all four edges (dwell/cooldown/auto-close)
- multi-monitor: hotplugging monitors while QS is running does not crash
- lock screen (`lock.sh`), exit WM (`exit.sh`) in QS mode
- recovery: kill QS, QS crash-loop

---

## 11. Code Conventions
- QML: one component per file, PascalCase name; singletons declared `pragma Singleton` + `qmldir`; no heavy logic in `shell.qml`.
- No `Timer` polling when invisible; use `visible`/`LazyLoader`.
- All `Process` must handle errors and log to `$XDG_RUNTIME_DIR/hakuspace/qs.log` (module prefix).
- No hard-coded `~` paths; use `Quickshell.env`.
- Bash: check `command -v` before calling external tools; no reckless `disown` (repo actively avoided it); use `spawn() { ( "$@" & ) >/dev/null 2>&1; }` like menu scripts.
- When adding new scripts → ensure names are **globally unique** in `src/core/**`.

---

## 12. Install, update, rollback, doctor, docs, nix
- **Package**: needs Quickshell + Qt deps. Arch: **VERIFY** `quickshell` (repo) or `quickshell-git` (AUR). Create `src/packages/pkg-quickshell.txt` and variable `PKG_QUICKSHELL` in `scripts/variables.sh`; **read `install.sh` (OPTIONAL handling area, around lines 75–120)** to mirror asking/installing, remember regex filtering `^[a-zA-Z0-9@._+-]+$`. `update.sh` currently ignores OPTIONAL — decide and note if Quickshell is optional or core.
- **Runtime deps to verify**: `qt6-declarative`, `qt6-wayland` (already present), `qt6-imageformats` (PNG/WebP icons), `cava`, `jq`, `brightnessctl`, `wl-clipboard`, `cliphist`.
- **`doctor.sh`**: add checks for `qs`/`quickshell`, deployed QML directory, `qs -c hakuspace ipc show` when backend is QS; warn if `--verify` finds forbidden processes.
- **`rollback.sh`/`update.sh`**: ensure `~/.config/quickshell` is backed up/restored properly.
- **`hakucfg/setting.sh`**: if adding a variable (e.g. `QS_BAR_VARIANT`), bump `SETTING_VERSION` according to `update.sh` mechanism.
- **Docs**: `docs/core/quickshell.md` (EN) + `docs/vietnamese/VN_quickshell.md`; update `docs/architecture.md` (Dive Deeper section), `README.md`, `docs/fedora_guide.md` (+VN version) and `docs/nixos.md`.
- **Nix**: add `quickshell` to config in `nix/hakuspace-config.nix` (and variants in `nix/`), determine how to test both offline/online flakes.

---

## 13. Risks & Open Questions

### Risks
1. **Single point of failure**: QS crash means losing bar/notifs/launcher. Mitigated by D8, clear logs, emergency keybind.
2. **D-Bus name collision** for notifications between swaync and QS during transition/startup (M0 step 3).
3. **Workspaces on Mango/Labwc** lack verified data sources (8.7).
4. **Tray + DBus menus** in QML are often tricky to render perfectly.
5. **Desktop icons + drag-drop** on layer-shell.
6. **Hyprland pointer-grab** with exclusive keyboard-interactivity surface (edge-trigger, 8.5).
7. **Nerd Font Glyphs**: copy exactly from original files, prone to breaking if re-typed.

### Open Questions (defaults chosen, user can change)
- **Q1 — Desktop icons in QS mode**: default **off until M6** (follows "only 1 quickshell" rule). To change to "keep Python app as exception", just remove the guard in `desktop_icons_manager.sh`.
- **Q2 — Number of bar variants at launch**: only `top`; rest in M6.
- **Q3 — Multi-monitor scope**: bar/rounded on all screens, edge-trigger only primary screen at launch.
- **Q4 — Volume/Brightness OSD** (absent in classic except swaync widget): optional in M5, drop if lacking time.

---

## 14. Report Template per milestone (Gemini sends back to user/Claude)
1. List of **new** and **modified** files (with 1-line reason).
2. What has been self-tested (`bash -n`, `shellcheck`, `qmllint`, API probes) and results.
3. What **cannot** be tested (needs real screen) → checklist in `docs/quickshell-testing.md`.
4. All **VERIFY** items handled: conclusion + docs source.
5. Assumptions made, deviations from this plan (if any) and reasons.
6. **Observations** about existing bugs in repo (do not fix).
7. Proposed next steps.

---

## Appendix A — Call-sites to handle (scanned from source)

### A.1 `rofi -dmenu` → `haku_pick`
| File | Location | Notes |
|---|---|---|
| `util/clipboard_menu.sh` | ~line 31 | `cliphist list \| rofi -dmenu -p ...` |
| `util/record.sh` | ~162, ~186 | choose mode; choose mic (multi-step) |
| `util/shell_switcher.sh` | ~50, ~104 | line 50 is **sudo password** input → `--password` |
| `util/gen_shortcut.sh` | ~50 | add shortcut menu |
| `sys/exit.sh` | ~52 | has `-theme-str` setting `width:50%; height:60%` → `--width/--height`, has `-selected-row 0` |
| `theme/change_theme.sh` | ~12, ~27, ~37, ~43 | main menu, font size, font, accent |
| `app/taskbar/taskbar_manager.sh` | ~146 | icon size input (here-string) |
| `util/waybar_manager.sh` | ~134 | `--select` (in QS: choose bar variant) |
| `sys/shutdown.sh` | ~49 | custom theme + `EXTEND`; change to `power` (QS) |
| `theme/rofi_theme_switcher.sh` | ~38 | **rofi-only**: hide "Change Rofi Theme" item in QS mode |

### A.2 `rofi -show ...` → QS modules
| File | Notes |
|---|---|
| `menu/hakumenu.sh` | `-modes` 3 scripts → `hakumenu` (script-mode) |
| `theme/wallpaper_select.sh` | `-modes Wallpaper/Lively` → `wallpaper` + `--list-json` |
| `theme/niri_animation_switcher.sh` | script-mode Open/Close (Niri only) → port in M6 |
| `menu/hm_general.sh` | `spawn rofi -show drun` → `launcher.sh drun` |
| Keybind ×4 WM | drun, emoji → `launcher.sh` |

### A.3 `swaync-client` → `notif.sh` / drop in QS
`edge_trigger.py` (classic-only), `theme/apply_style.sh` (guard), keybind Super+N ×4 WM, `waybar/module/notification_module` (classic-only), buttons/commands in `swaync/config.json` (classic-only).

### A.4 Other waybar/taskbar references
`desktop_icons.py` (Waybar menu uses `pgrep waybar` + `waybar_manager.sh`; in QS mode desktop icons are off), `util/open_config.sh` (add QS folder), `sys/exit.sh` (app list and `rm -rf /tmp/waybar*`), `theme/opaque_theme.sh` (waybar/rofi/swaync renderer — keep for classic).

### A.5 Minor observations (out of scope, fyi only)
- `labwc/autostart` calls `fcitx5 -d` twice.
- `menu/hm_general.sh`: if `~/hakucfg/general-menu.sh` is missing or fails, fallback branch calls `notify-send` every time script runs (both list and select) → in QS mode this becomes repeated toasts.

---

## Appendix B — Projected new file list
```
src/core/lib/haku_backend_lib.sh
src/core/lib/haku_pick.sh
src/core/sys/haku_backend.sh
src/core/sys/session_start.sh
src/core/sys/qs_supervisor.sh
src/core/util/launcher.sh
src/core/util/notif.sh
src/home/.config/quickshell/hakuspace/**            (QML tree in section 8)
src/packages/pkg-quickshell.txt
scripts/check_no_rofi_in_qs.sh
docs/core/quickshell.md
docs/vietnamese/VN_quickshell.md
docs/quickshell-testing.md
```
- Removed monitor module and drawer from TopBar layout per user request.

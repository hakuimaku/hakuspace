# Core System Scripts (src/core/sys)

The scripts inside `src/core/sys/` are the backbone of your desktop's lifecycle management. While other scripts handle aesthetics or quick utilities, these scripts manage how your computer sleeps, locks, shuts down, and handles user authentication.

They are designed to be completely Window Manager agnostic, meaning they work seamlessly whether you're logging into Hyprland, Niri, Mango, or Labwc!

Here is a detailed breakdown of each script:

## Power & Session Management

### `exit.sh` (The Safe Exit)
Have you ever logged out and had your system hang, or found zombie processes still running in the background?
- **Architecture:** `exit.sh` is now a stable public facade. Destructive cleanup and WM quit live in the headless `backend/system/session_exit_ctl.sh`; Classic confirmation/UI lives in `frontend/classic/exit_rofi.sh`.
- **Process report:** `exit.sh --process-report` (or `session_exit_ctl.sh process-report`) is side-effect free and prints active processes sorted by aggregate RAM usage.
- **Classic confirmation:** Calling `exit.sh` with no arguments keeps the existing Rofi system-monitor confirmation. Escape, cancel, or any row other than `[!] EXIT ANYWAY` is a frontend-only no-op.
- **Explicit execute:** `session_exit_ctl.sh execute` performs the existing graceful `SIGTERM`, forced cleanup, socket/runtime cleanup, user-systemd teardown, and Hyprland/Niri/Mango/Labwc quit branch. It requires the explicit `execute` subcommand; invoking the backend with no arguments cannot terminate the session. `exit.sh --execute` exposes the same explicit headless operation.

### `shutdown.sh` (The Power Menu)
Your elegant replacement for typing terminal commands to reboot.
- **Architecture:** `shutdown.sh` is the stable public facade. Classic presentation lives in `frontend/classic/power_rofi.sh`, while explicit actions live in the headless `backend/system/power_ctl.sh`. The frontend maps the selected row index to a stable action ID instead of dispatching from the displayed icon.
- **Classic UI:** Calling `shutdown.sh` with no arguments keeps the icon-based menu and `shutdown.rasi`. Use `-v` / `--vertical` for `shutdown-vert.rasi`, and `-e` / `--extend` to pass Classic placement arguments through to the menu.
- **Headless actions:** `shutdown.sh --suspend`, `--reboot`, `--poweroff`, `--hibernate`, `--lock`, and `--logout` delegate to explicit controller commands. `shutdown.sh --list` is side-effect free and prints the stable action IDs.
- **Session-exit boundary:** Logout delegates to the stable `exit.sh` facade, so the normal power menu still gets Classic confirmation. The underlying cleanup is independently callable through `session_exit_ctl.sh execute` for explicit headless use.

### `dpms_handler.sh` (Monitor Power Control)
Managing monitor power states varies wildly between different Window Managers. This script unifies them.
- **What it does:** It accepts `on` or `off` arguments to instantly power down or wake up your displays (DPMS).
- **How it works:** It detects your `XDG_CURRENT_DESKTOP` and translates the command into the correct protocol: `hyprctl` for Hyprland, `niri msg` for Niri, `mmsg` for Mango, or `wlr-randr` for Labwc.

## Idle & Lock Screen

### Idle ownership and native Hikai policy

`idle_backend_ctl.sh reconcile` selects the idle owner during `session_start.sh --early` and every backend commit. Classic retains exactly one user-owned `hypridle`; Hikai stops it before committing native ownership. Shell transitions wait for the native FileView watcher to acknowledge activation or cleanup, and rollback/crash-loop recovery restores the matching idle owner. `idle_backend_ctl.sh status` reports the backend and daemon count without changing them.

Hikai uses four independent Quickshell `IdleMonitor` objects for dim, native lock, display off, and suspend. Saved `~/hakucfg/hikai/hikai-shell.json` schema v8 preferences provide defaults of 200/230/300/360 seconds and 10% brightness. Enabled stages must have strictly increasing timeouts in 10–86400 seconds. Session → Idle & Power edits the existing Shell store; Apply commits policy, and draft edits do not arm idle actions. Migration from v7 preserves existing preferences and adds native defaults. Classic's `hypridle.conf` and user timeout overrides remain independent and unchanged.

`IdleService` calls `LockState.requestLock()` directly, routes DPMS through `dpms_handler.sh`, and requests `power_ctl.sh suspend` only after `LockState.secure` and a fresh inhibitor check. A failed secure-lock deadline cancels idle suspend. `idle_actions.sh` serializes brightness/DPMS effects and stores only recovery markers under `$XDG_RUNTIME_DIR/hakuspace`; activity, disabling, reload, startup after a crash, and backend handoff restore owned effects without unlocking. It is an action helper, not another idle timer.

`idle_session_watch.py` uses Gio on the system bus to watch only the current login session's Lock/Unlock and logind PrepareForSleep. It retains a logind sleep delay fd, forwards streamed JSON to QML, and releases the fd only after a matching secure-lock acknowledgment. Wake reacquires the delay before publishing resume; external Unlock never authenticates the native lock. These hooks remain active in Hikai even if idle timeouts are disabled. A disconnected bridge is restarted and native timeout actions wait for readiness.

The compositor must support [ext-idle-notify-v1](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/IdleMonitor/). External sleep uses logind's bounded [delay inhibitor](https://www.freedesktop.org/software/systemd/man/latest/org.freedesktop.login1.html): logind may continue when `InhibitDelayMaxUSec` expires even if the shell cannot secure the lock. The bridge never acknowledges an insecure lock, but a delay inhibitor cannot veto arbitrary external suspend forever. Explicit requests to bypass inhibitors are outside this protection.

Diagnostics: `qs -c hakuspace ipc call idle status` reports ownership, readiness, monitor and stage state, and errors. `idle inhibitStatus` reports the last observed custom inhibition. `idle forceStage <dim|lock|displayOff|suspend>` is rejected unless `HAKUSPACE_IDLE_TEST=1`; forced stages still use the normal condition and secure-lock gates. Do not enable that test flag in a normal session.

Targeted checks live in `tests/hikai/idle/`. The runtime harness uses a private Labwc compositor, two headless outputs, software rendering, a stub lock state, and stub brightness/DPMS/power commands. It covers native notifications, Wayland app inhibition, retries, stale condition results, backend changes, secure-only suspend dispatch, external sleep/wake routing, and QML reload. `test_session.sh` checks the composed Session page and Apply with private preferences. These are protocol and lifecycle checks, not hardware GPU/FPS evidence. Real lid/power-button sleep, output hotplug, and Hyprland/Niri/Mango/Labwc hardware smoke checks remain manual; never substitute a real suspend for the harness's stub.

### `idle_inhibit.sh` (The Smart Sleep Blocker)
There's nothing more annoying than your screen turning off while you're watching a video or listening to a podcast.
- **What it does:** Both Classic hypridle conditions and Hikai stages call this backend-neutral policy helper. No hypridle binary is required for native checks or the Keep Awake quick action.
- **Audio Detection:** It checks PulseAudio/PipeWire sink inputs and blocks idle for unmuted, uncorked audio streams, including browser playback.
- **Manual Toggle:** `--toggle` and manual-only `--check` share `~/.local/state/hakuspace/state/[system].idle-inhibit.enabled` across both backends. `--condition` (also the default with no arguments) exits 0 when idle actions are allowed. `--status-json` reports manual/audio/combined inhibition; `--no-audio` skips audio for a native policy check. Active audio retains the existing five-second grace period. Blocked native stages retry every 30 seconds without requiring user activity.

### `lock.sh` (The Smart Screen Locker)
Secures your computer when you step away.
- **Mode-Aware Routing:** In **Hikai** mode, `lock.sh` requests the native Quickshell Wayland session lock (`qs -c hakuspace ipc call lock lock`) and waits until the compositor confirms every output is securely covered (`WlSessionLock.secure`). In **Classic** mode, it launches `hyprlock`.
- **Fail-Closed Fallback:** If Hikai native locking is unavailable or does not reach the secure lock state, `lock.sh` automatically falls back to `hyprlock` rather than leaving the session unlocked.
- **PAM & Troubleshooting:** Native Hikai locking authenticates through a single shared Quickshell `PamContext` using the system `login` PAM service (`/etc/pam.d/login`). You can inspect lock state without exposing credentials via `qs -c hakuspace ipc call lock status`.
- **Dynamic Resolution (Classic / Fallback):** When launching `hyprlock`, it detects your monitor's current resolution (handling Hyprland, Niri, Mango, and fallback sysfs paths). Screens `1920x1080` or larger use `hyprlock.conf`, while smaller displays load `hyprlock_tiny.conf`.

## Boot & Authentication

### `polkit_start.sh` (The Privilege Manager)
Whenever an app needs root permissions (like GParted or a system updater), it needs an authentication window to ask for your password.
- **What it does:** Starts the MATE Polkit authentication agent (`polkit-mate-authentication-agent-1`) in the background on startup.
- **Cross-Distro Compatibility:** Because file paths differ across operating systems, this script dynamically hunts down the exact binary location whether you are running Arch Linux, Fedora, or NixOS, ensuring you never miss a password prompt.

### `welcome.sh` (The Greeting)
A small quality-of-life script.
- **What it does:** If `WELCOME_MSG=true` is set in your `~/hakucfg/setting.sh`, it waits two seconds after you log in and sends a friendly "Have a good day" system notification to greet you.


---
**Previous:** [Theming Engine](theme.md) | **Next:** [Utilities](util.md)

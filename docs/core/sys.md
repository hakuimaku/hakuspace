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

`idle_backend_ctl.sh reconcile` selects the idle owner during `session_start.sh --early` and every backend commit. Classic retains exactly one user-owned `hypridle`; Hikai stops it before committing native ownership. Before a Classic commit, the shell requests native `idle release` and waits for tracked recovery, retries, and queued mutations to finish while Hikai still owns idle. Only then does it commit Classic and start hypridle. If Quickshell has died or must be killed, emergency recovery drains its serialized native effects before committing Classic; a failed drain prevents handoff. Rollback can reacquire native ownership, and crash-loop recovery restores the matching idle owner. `idle_backend_ctl.sh status` reports the backend and daemon count without changing them.

Hikai uses four independent Quickshell `IdleMonitor` objects for dim, native lock, display off, and suspend. Saved `~/hakucfg/hikai/hikai-shell.json` schema v9 preferences provide defaults of 300 seconds dim, 120 seconds lock, 120 seconds display off, and 600 seconds suspend (cumulative chaining: dim at 5 min, lock 2 min after dim, display off 2 min after lock, suspend 10 min after display off) and 10% brightness. Canonical defaults are: Manual Keep Awake: off, Automatic audio inhibit (`inhibitOnAudio`): off, Respect application inhibitors: on. Timeouts are configured in 10–86400 seconds in multiples of 10. Session → Idle & Power edits the existing Shell store; Apply commits policy, and draft edits do not arm idle actions. Schema migration v8 → v9 disables the previously implicit audio-inhibit default so audio playback does not block idle unless explicitly enabled as an opt-in preference. Classic's `hypridle.conf` and user timeout overrides remain independent and align with the same cumulative timings.

`IdleService` calls `LockState.requestLock()` directly, routes DPMS through `dpms_handler.sh`, and requests `power_ctl.sh suspend` only after `LockState.secure` and a fresh inhibitor check. A failed secure-lock deadline cancels idle suspend. External sleep releases its logind delay as soon as the native lock is secure; DPMS off is best effort and cannot delay this acknowledgment. Wake recovery is idempotent.

Timeout, inhibitor-policy, and enabled changes explicitly disarm and re-arm each stage in a later event-loop turn. The new countdown starts at re-arm. A separate activity subscription while applied prevents re-arm from synthesizing a resume or restoring brightness; real activity or disabling the stage performs that recovery. Generation checks invalidate pending conditions and stale action results. Native stages wait until pending cleanup succeeds, so a delayed recovery cannot restore an effect acquired by a later idle cycle.

`idle_actions.sh` serializes brightness/DPMS effects and retains recovery markers under `$XDG_RUNTIME_DIR/hakuspace`. Each QML instance claims an owner token in the existing `idle-actions.lock` file. Commands and detached destruction cleanup carry that token; once a newer instance claims it, an older cleanup exits without touching brightness or DPMS. Activity, disabling, reload, startup after a crash, and backend handoff restore owned effects without unlocking. No new preference or persistent state file is introduced.

`idle_session_watch.py` uses Gio on the system bus to watch only the current login session's Lock/Unlock and logind PrepareForSleep. It acquires the delay fd before subscribing to sleep signals and announcing readiness, and defensively acquires a missing fd at the start of a new sleep transaction. Repeated sleep/wake signals retain one serial and one fd per transaction. Only a matching secure-lock acknowledgment releases the delay; wake rearms it before publishing resume. External Unlock never authenticates the native lock. These hooks remain active in Hikai even if idle timeouts are disabled. A disconnected bridge is restarted and native timeout actions wait for readiness.

The compositor must support [ext-idle-notify-v1](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/IdleMonitor/). External sleep uses logind's bounded [delay inhibitor](https://www.freedesktop.org/software/systemd/man/latest/org.freedesktop.login1.html): logind may continue when `InhibitDelayMaxUSec` expires even if the shell cannot secure the lock. The bridge never acknowledges an insecure lock, but a delay inhibitor cannot veto arbitrary external suspend forever. Explicit requests to bypass inhibitors are outside this protection.

Diagnostics: `qs -c hakuspace ipc call idle status` reports ownership, readiness, requested/armed stage policy, and errors. `customInhibit` and `idle inhibitStatus` contain `manual`, `audioPolicyEnabled`, `audio`, `effective`, `known`, `refreshing`, `checkedAtMs`, and `error` from coalesced `idle_inhibit.sh --status-json` reads, rather than the last stage callback. IPC refreshes asynchronously; the first response can have `known:false` and clients may read again after refresh. Helper errors inhibit stage execution and are visible in diagnostics. `idle forceStage <dim|lock|displayOff|suspend>` is rejected unless `HAKUSPACE_IDLE_TEST=1`; forced stages still use the normal condition and secure-lock gates. Do not enable that test flag in a normal session.

Runtime logs use the `[idle]` prefix and include monitor arming, timeout/condition decisions, inhibitor reasons, action start/exit, and logind/security events. Follow them with `qs log -c hakuspace -t 100 -f --no-color --log-times | rg --line-buffered '\[idle\]'`. `qs -c hakuspace ipc call idle logs` returns the most recent 128 events as JSON without a new log file or preference. Session displays whether saved idle management is active or paused by audio/Keep Awake. Idle duration controls use +/- ten-second steps and direct numeric input, bounded by enabled neighboring stages; brightness uses five-percent steps. Changes still require Apply.

Targeted checks live in `tests/hikai/idle/`. `test_runtime.sh` covers native notifications and application inhibition. `test_hardening.sh` uses a private two-output Labwc compositor, real Wayland idle/input events, software rendering, a stub lock state, and fake brightness/DPMS/power commands with timestamped logs and explicit failure gates. It tests runtime re-arm, generation cancellation, sleep ACK before DPMS completion, failures, diagnostics, and reload. `test_ownership.py` includes 20 switch cycles and preserves independent Classic/Hikai timeout files. `test_session.sh` checks the composed Session page and Apply. These are protocol and lifecycle checks, not hardware GPU/FPS evidence. Real lid/power-button sleep, output hotplug, and hardware smoke checks remain manual; never substitute a real suspend for the harness's stub.

### `idle_inhibit.sh` (The Smart Sleep Blocker)
There's nothing more annoying than your screen turning off while you're watching a video or listening to a podcast.
- **What it does:** Both Classic hypridle conditions and Hikai stages call this backend-neutral policy helper. No hypridle binary is required for native checks or the Keep Awake quick action.
- **Audio Detection:** It checks PulseAudio/PipeWire sink inputs and blocks idle for unmuted, uncorked audio streams. Playback on any output inhibits idle, including quiet passages; it does not sample the default sink's volume. Zen intentionally follows the same rule as every other browser, so its video/audio playback keeps the desktop awake; the old `zen-bin` exception is not retained. Muted or corked streams do not auto-inhibit, and manual Keep Awake remains independent.
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

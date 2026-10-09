# P2 Native Notifications — first execution batch

Status: **P2.0 verified; P2.1 verified on one Hyprland output with multi-monitor pending; P2.2 lifecycle skeleton verified.**
P2.3 and later phases have not started. The live Hikai session still uses SwayNC.

## Baseline and local API

- Start HEAD: `66042dca` on branch `quickshell`.
- Installed Quickshell: `0.3.1` (Arch Linux build).
- Verified local types from `/usr/lib/qt6/qml/Quickshell/Services/Notifications/quickshell-service-notifications.qmltypes`.
- `NotificationServer`, `Notification`, `NotificationAction`, close reasons, urgency, `keepOnReload`, and `trackedNotifications` exist.
- The installed runtime exposes `Notification.expireTimeout` in **milliseconds**: `notify-send -t 1000` yielded `expireTimeout: 1000`. Use the measured runtime behavior, despite older upstream source comments saying seconds.

## P2.0 shared panel audit

`FlarePanelWindow` already accepts generic `panelComponent`, `panelProps`, `panelKey`, anchor X/width and per-screen `modelData`. Its closing mask falls to zero size when `panelOpen` becomes false, and `UiState.activePanel` has the one-large-panel contract. A Notification Center may need a larger width; this can be a small configurable width property when P2.4 starts. No P2.0 code change was needed. Existing Tray implementation was left untouched. Interactive Tray regression was not rerun in this batch because no panel code changed.

## P2.1 ownership

The server is owned by one `NotificationStore` singleton, with one `Instantiator` and `model: 1`, outside all screen variants. It initially advertises plain bodies only; markup, links, images, actions, inline reply and persistence capabilities remain off.

The private-bus probe (`python3 scripts/notification_probe.py`) proved that Quickshell owns `org.freedesktop.Notifications` and one `notify-send` produces one model record. The same probe passed on the real Hyprland session bus after temporarily stopping SwayNC. The service-only probe exited and SwayNC was restored; final `busctl --user status org.freedesktop.Notifications` showed `Comm=swaync`, while `qs -c hakuspace ipc call shell ping` returned `pong`. This session has one connected monitor (`hyprctl monitors -j`), so the multi-monitor event-count acceptance remains untested.

During development, the deployed Hikai process has `QS_ALLOW_SWAYNC=1`. `NotificationStore` does not instantiate its server when that flag is set. This preserves the notification path until the P2.7 cutover. The probe process runs without the flag and tests native ownership. To repeat the real-session procedure, stop SwayNC, run `python3 scripts/notification_probe.py --inner`, then start `swaync` in a detached session; always verify the final D-Bus owner. The default probe uses a private bus and does not touch the desktop daemon.

The live shell had to be restarted once after adding the guard: `keepOnReload` retained an already acquired server through a QML reload. After the restart, SwayNC resumed ownership and the Hikai shell remained running.

## P2.2 lifecycle skeleton

`Notifications.qml` stores plain snapshot records in one authoritative array and live protocol handles in a separate private map. `closed()` removes the handle immediately. Replacement updates a live record with the same protocol ID; internal keys remain stable and are independent of protocol ID reuse. Non-transient closed records remain in history, while transient records are removed when closed. `count` is the number of non-transient, non-dismissed history rows. Dismiss hides a row and sends `dismiss()` to a live handle; expire sends `expire()` and records its distinct close reason.

For reload, a `PersistentProperties` holder attached to `ShellRoot` carries a JSON string of plain snapshots and the next internal key in memory. It does not write history to disk. `keepOnReload` re-emits active protocol objects, which rebind to their prior records without a new popup eligibility flag. Raw JS arrays did not transfer across the installed Quickshell reload boundary; the JSON string did.

The probe passed: two independent notifications, replacement without count inflation, remote `CloseNotification`, local dismiss, short timeout, explicit expire, critical urgency metadata, transient removal, and reload with unchanged count and internal keys. Default timeout, zero timeout longevity, critical default timeout, action invocation, real popup timing, and restart behavior still belong to later phases.

## Phase boundary

No popup, Notification Center, `notif` IPC, `notif.sh` change, or SwayNC cutover was made. P2.3 is held until the P2.1 multi-monitor acceptance can be tested, as required by the execution plan. Niri, MangoWM, fractional scale and visual input behavior remain unverified.

# P2 Native Notifications — status

Status: **PARTIAL.** P2.0–P2.2 are implemented; P2.3 Popup and P2.4 Center are implemented and tested on Hyprland. P2.5–P2.7 remain. The live Hikai session still uses SwayNC.

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

The private-bus probe (`python3 scripts/notification_probe.py`) proved that Quickshell owns `org.freedesktop.Notifications` and one `notify-send` produces one model record. The same probe passed on the real Hyprland session bus after temporarily stopping SwayNC. The service-only probe exited and SwayNC was restored; final `busctl --user status org.freedesktop.Notifications` showed `Comm=swaync`, while `qs -c hakuspace ipc call shell ping` returned `pong`.

Hyprland normally has one physical output here. A temporary `HAKU-P2-TEST` headless output made `Quickshell.screens.length == 2` in the probe; one send still produced one record, and replacement/reload tests passed. The output was removed, leaving only `eDP-1`. Physical two-monitor placement remains a later UI test.

During development, the deployed Hikai process has `QS_ALLOW_SWAYNC=1`. `NotificationStore` does not instantiate its server when that flag is set. This preserves the notification path until the P2.7 cutover. The probe process runs without the flag and tests native ownership. To repeat the real-session procedure, stop SwayNC, run `python3 scripts/notification_probe.py --inner`, then start `swaync` in a detached session; always verify the final D-Bus owner. The default probe uses a private bus and does not touch the desktop daemon.

The live shell had to be restarted once after adding the guard: `keepOnReload` retained an already acquired server through a QML reload. After the restart, SwayNC resumed ownership and the Hikai shell remained running.

## P2.2 lifecycle skeleton

`Notifications.qml` stores plain snapshot records in one authoritative array and live protocol handles in a separate private map. `closed()` removes the handle immediately. Replacement updates a live record with the same protocol ID; internal keys remain stable and are independent of protocol ID reuse. Non-transient closed records remain in history, while transient records are removed when closed. `count` is the number of non-transient, non-dismissed history rows. Dismiss hides a row and sends `dismiss()` to a live handle; expire sends `expire()` and records its distinct close reason.

For reload, a `PersistentProperties` holder attached to `ShellRoot` carries a JSON string of plain snapshots and the next internal key in memory. It does not write history to disk. `keepOnReload` re-emits active protocol objects, which rebind to their prior records without a new popup eligibility flag. Raw JS arrays did not transfer across the installed Quickshell reload boundary; the JSON string did.

The probe passed: two independent notifications, replacement without count inflation, remote `CloseNotification`, local dismiss, short timeout, explicit expire, critical urgency metadata, transient removal, and reload with unchanged count and internal keys. Batch 2 also verified default and critical default timeout, DND suppression, the newest-three popup cap and idempotent clear-all. Action invocation and full process restart behavior belong to later phases.

## First batch boundary

The first batch made no popup, Notification Center, `notif` IPC, `notif.sh` or SwayNC cutover change.

## Batch 2: initialization order

`NotificationStore._started` keeps its sole server inactive until `PersistentProperties.onLoaded` calls `start(memory)`. `start()` restores snapshot JSON and the next key, clears restored popup eligibility, then activates the server. With a 2-second artificial delay, the private-bus probe observed no owner and an inactive server before initialization. On reload it observed an inactive new server before retained notifications rebound; count and logical keys remained unchanged.

## Batch 2: popup

`NotificationPopup.qml` is a small per-screen Overlay layer with no workspace reservation or keyboard focus. It reads a filtered view of the global records. Placement uses Quickshell's first available screen, with fallback to that screen if the original output disappears; no compositor-specific polling was added. The newest three eligible live records appear, reduced further if screen height cannot fit three. The popup width is at most 350 logical pixels. Summary, body and card height are bounded; all text is rendered as plain text. Close calls `NotificationStore.dismiss(key)`. The one service deadline controls expiry; there is no hover pause. Actions and image previews are not shown because support is not yet implemented. The toast enters with a short opacity animation and disappears immediately when its record closes.

DND suppresses all popups, including critical, while preserving non-transient history. Turning DND on hides visible popups immediately; turning it off does not replay them. Opening Center also clears visible popup eligibility. Notifications received while Center is open enter history without becoming later toasts.

Hyprland private-bus UI checks: four sends yielded four history rows and three toast surfaces; replacement kept one toast with updated text; remote close removed it; a short timeout removed the next toast. A 600-character body with literal `<b>` text stayed inside a 350×156 layer. `hyprctl activewindow` reported the same address before and after popup display. Full UI reload changed one active record from one toast to zero toasts while count stayed one.

## Batch 2: Notification Center

`NotificationCenterPanel.qml` reuses `FlarePanelWindow` unchanged. `UiState.notificationPanel` holds only screen name and anchor geometry, while `activePanel` still owns mutual exclusion. The bell left click toggles Center and right click toggles the one service DND flag. Header, bell and service use the same count definition: non-transient, non-dismissed history rows. Center displays plain-text cards, a bounded scrolling list, an empty state, DND toggle, per-item dismiss and Clear All. No inactive action buttons are shown.

Hyprland private-bus UI checks: Center rendered four records and its header controls without overlap. DND preserved history and Clear All reduced count to zero. Synthetic Tray state transferred to Center and back through `UiState.activePanel`. A normal close left no `hakuspace-flare-panel` layer; disconnecting the Center-owning headless output cleared `UiState.notificationPanel` and also left no Flare layer. A temporary second output received Center ownership when opened from that screen, while popup placement stayed on the documented first output. The output was removed afterward.

## Batch 2 verification limits

Physical pointer tests of bell clicks, toast close, Escape, outside click and wheel scrolling were not run; handlers use the existing `TopModule` and `FlarePanelWindow` paths. A real Tray menu transfer was not repeated; the state transfer used a temporary menu payload. Niri, MangoWM, physical two-monitor and fractional-scale sessions were unavailable. Mark these `IMPLEMENTED / VERIFY`, not PASS. P2.5 actions/images and deeper timeout/restart checks, P2.6 IPC/facade, and P2.7 SwayNC cutover remain open.

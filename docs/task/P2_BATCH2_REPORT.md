# P2 Native Notifications — Batch 2 Report

## 1. Baseline

- Start HEAD: `45a9f553`
- End HEAD: report commit containing this file, after `6505e983`.
- Commits: `b605b5c8` (gate server until restore), `6505e983` (popup and Center), report commit.
- Git status: only the two supplied plans, `P2_NATIVE_NOTIFICATIONS_CODEX_PLAN.md` and `P2_BATCH2_CODEX_INSTRUCTIONS.md`, remain untracked intentionally.

## 2. P2.2 initialization race

- Root cause: the native server could activate before `PersistentProperties.onLoaded` restored the snapshot and next key.
- Fix: server activation requires `NotificationStore._started`; `start(memory)` restores both values before setting it. Restored records lose popup eligibility.
- Probe: `HAKU_P2_PROBE_DELAY_MS=2500 python3 scripts/notification_probe.py` checked inactive server/no owner before restore and during reload, then retained binding.
- Reload result: count `7 → 7`, logical keys `[1, 2, 3, 4, 5, 6, 7, 9] → [1, 2, 3, 4, 5, 6, 7, 9]`; no replay popup.

## 3. P2.3 Popup

- Files: `Notifications.qml`, `NotificationPopup.qml`, `notification/NotificationCard.qml`, `shell.qml`.
- Architecture: one global service; per-screen Overlay windows render a filtered view of its records. Windows have no exclusive zone or keyboard focus and mask only the card stack.
- Screen policy: first available Quickshell screen; an existing popup stays on its origin screen, and falls back to the first screen only if that origin disappears.
- Stack policy: newest three eligible live notifications, reduced if screen height cannot hold them. History remains intact. Width is at most 350 logical pixels; summary/body and card height are bounded.
- Timeout policy: service deadline only, with no hover pause.
- DND behavior: incoming notifications enter history without a toast. Turning DND on hides visible toasts; turning it off does not replay them. Critical notifications follow the same rule.
- Replacement result: one existing toast updated to the replacement text. Remote close and short timeout removed their toasts.
- Reload result: one active record remained in history while its toast count went from one to zero.
- Focus/input result: `hyprctl activewindow` stayed on the same address and the popup layer occupied a small card-sized area. Literal `<b>` and a 600-character body remained bounded plain text. Actual desktop click-through and toast close clicks still need interactive verification.

## 4. P2.4 Notification Center

- Files: `NotificationCenterPanel.qml`, `notification/NotificationCenterContent.qml`, `NotificationGroup.qml`, `TopBar.qml`, `UiState.qml`, `shell.qml`.
- FlarePanelWindow reuse: Center uses the existing primitive unchanged, including its Escape/outside-click dismissal path and close animation.
- UiState changes: a small screen/anchor payload plus the existing `activePanel` mutual-exclusion contract; screen removal closes its Center.
- TopBar behavior: left click toggles Center; right click toggles DND. The icon and tooltip show count/DND state.
- Count semantics: service, bell and Center all use non-transient, non-dismissed history rows; remote-closed rows may remain counted.
- DND: Center and bell call the same service flag.
- Clear All: one service operation removes history and dismisses live handles; the probe verified a second call is harmless.
- Tray transfer: synthetic Tray state transferred to Center and back with one active panel. Real Tray menu pointer interaction remains to be checked.

## 5. Runtime matrix

`PASS` means exercised on the running Hyprland session or isolated private-bus UI. `IMPLEMENTED / VERIFY` means the code path exists but the specified physical interaction was not exercised.

| Case | Hyprland | Niri | Mango |
|---|---|---|---|
| normal popup | PASS | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| replacement | PASS | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| dismiss | service PASS; toast click VERIFY | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| timeout | PASS | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| DND | service/UI state PASS; click VERIFY | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| center | renders/opens by state PASS; bell click VERIFY | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| Escape | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| outside click | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| Tray transfer | synthetic state PASS; real menu VERIFY | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |
| reload | PASS | IMPLEMENTED / VERIFY | IMPLEMENTED / VERIFY |

Other checks: four sends produced four history rows and three visible toasts; DND suppressed a fifth toast but kept its history row; Clear All reduced count to zero. Center header buttons rendered without overlap. Long-text and replacement screenshots were inspected. Wheel scrolling, per-item button clicks, left/right bell clicks, Escape and outside click remain interactive checks.

## 6. Multi-monitor

- Temporary output: Hyprland headless output `HAKU-P2-BATCH2`, later `HAKU-P2-HOTPLUG` for removal while Center owned it.
- One event/send: the global model retained one event per send; a popup appeared on the documented first screen only.
- Popup placement: eDP-1 had one toast, the added output had zero. The service now also excludes duplicate fallback when the origin output still exists.
- Center transfer: opening from output A then B moved the one Center to B. Removing B cleared the Center payload and left no Flare layer.
- Cleanup: both temporary outputs removed; final monitor list was only `eDP-1`. Physical two-monitor and fractional-scale checks remain unavailable.

## 7. Final daemon state

- `QS_ALLOW_SWAYNC=1` in the running `qs -c hakuspace` process and in the deployed backend library.
- `pgrep -a swaync`: `1019 swaync`.
- D-Bus `org.freedesktop.Notifications`: PID 1019, `Comm=swaync`, `/usr/bin/swaync`.
- `qs -c hakuspace ipc call shell ping`: `pong`.

## 8. Static checks

- Diff check: `git diff --check` and staged diff check passed.
- QML syntax: the Quickshell QML syntax check passed through `scripts/precommit_check.sh`.
- Precommit: passed after the final screen-routing fix.
- Debug grep: only the pre-existing `Theme.qml` parse-error `console.log` appeared.
- Private-bus probe: all service cases passed after the final fix, including delayed restore/reload, default and critical timeouts, DND, newest-three cap and idempotent Clear All.

## 9. Remaining work

- P2.5: action invocation, images and deeper timeout/restart checks.
- P2.6: `notif` IPC and Hikai facade routing.
- P2.7: controlled SwayNC cutover.
- Runtime verification: physical pointer/keyboard paths, scroll and real Tray transfer; Niri and Mango smoke tests; physical multi-monitor/fractional scale.

## 10. Status

**PARTIAL**

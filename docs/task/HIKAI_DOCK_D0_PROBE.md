# Hikai Dock D0 protocol probe

Date: 2026-10-19 (Asia/Ho_Chi_Minh). Source baseline: `d5b053f9`.
Initial worktree: only `docs/task/plan/` untracked; no tracked modifications.
Quickshell: **0.3.2**, Arch Linux distribution build.

## Results

| Compositor | Runtime | appId/title | Open/close | activated updates | activate A → B | Output |
| --- | --- | --- | --- | --- | --- | --- |
| Hyprland 0.56.2 | Current physical session | PASS | PASS | PASS | PASS | eDP-1 |
| Niri 26.04 (8ed0da4) | Isolated nested Wayland, private config/D-Bus | PASS | PASS | PASS | PASS | winit |
| MangoWM 0.18.0 (6e56166c) | Isolated nested Wayland, private config/D-Bus | PASS | PASS | PASS | PASS | WL-1 |

A disposable QML probe opened two `FloatingWindow` fixtures with unique titles,
resolved them exclusively through `ToplevelManager.toplevels.values`, activated
A after B was focused, activated B again, hid A and then B, and asserted removal.
All three runs returned:

```json
{"openedA":true,"openedB":true,"activatedA":true,"activatedB":true,"closedA":true,"closedB":true}
```

Fixture appId was `org.quickshell`. Physical-session metadata also resolved
`thunar`, `zen`, and `com.microsoft.VSCode`, each with output `eDP-1`.
No user titles or full protocol traces are committed.

## Input prerequisite

An initial timer-only probe did not switch to A. After delivering a pointer event
into a fixture, both activation directions passed. On Hyprland, a Wayland client
trace confirmed two actual `zwlr_foreign_toplevel_handle_v1.activate(wl_seat)`
requests. Dock clicks naturally supply this input context. This was a probe
setup issue, not evidence of a compositor-specific adapter requirement.
The host pointer and focused window were restored after input-assisted runs.

Temporary probe files and logs were kept under `/tmp/hikai-dock-d0`, outside
production source. No debug UI or logging is added to the shell.

## Startup baseline

- `bash scripts/test_hikai_shell.sh`: PASS (settings startup, legacy migration).
- `bash scripts/test_hikai_shell.sh --headless`: PASS (two Labwc outputs,
  settings lifecycle, real panel layout, RoundedScreen pixel matrix).
- Existing baseline warnings: missing isolated backend helpers/icons,
  portal/PipeWire service availability, deprecated FloatingWindow dimensions,
  and an undefined HScrollBar value in the offscreen harness.

The window-source gate is satisfied. Nested protocol checks do **not** replace
physical Dock acceptance on Niri/MangoWM, multi-monitor hotplug, or fullscreen.

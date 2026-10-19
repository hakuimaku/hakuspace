# HakuMenu dual-presentation baseline

Date: 2026-10-19 (Asia/Ho_Chi_Minh).

The dual-presentation plan supersedes the earlier floating-only plan. Existing
`topFlare` remains the default for the top trigger, IPC and launcher shortcuts.

Rollback checkpoint: `/tmp/hikai-dock-checkpoint-fifI4k/` contains the original
Quickshell/backend/scripts/task documents, tracked patch, HEAD, status and SHA256.
It was created before changing HakuMenu; no source was staged or committed.

Baseline checks passed: Dock runtime, pin backend (5 tests), settings backend
(10 tests), full repository check using a disposable Git index, and the real
TopBar/RoundedScreen pixel matrix including HakuMenu's original ceiling attachment.
After shared-content extraction, the same pixel matrix passes again.

Original behavior retained in `HakuMenuTopFlare.qml`: middle-fifth top trigger,
FlareMorph/curves, 38/40/42 percent mode widths, 40 percent height, top controls,
safe-zone corridor, Exclusive keyboard surface, search prefixes and existing lists.
Real keyboard/pointer tests cover tab switching, prefixes, Drun execution, Escape
and focus over a fullscreen client. Hardware multi-monitor coverage is not implied
by the isolated output tests.

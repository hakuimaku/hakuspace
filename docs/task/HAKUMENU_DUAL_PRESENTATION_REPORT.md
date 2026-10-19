# HakuMenu dual-presentation implementation

Date: 2026-10-19 (Asia/Ho_Chi_Minh).

Implemented the dual-presentation plan. The floating-only plan is superseded.
No commits were created. The pre-change checkpoint and baseline evidence are in
[HAKUMENU_DUAL_STYLE_BASELINE.md](HAKUMENU_DUAL_STYLE_BASELINE.md).

## Delivered behavior

| Area | Result |
| --- | --- |
| Legacy presentation | `HakuMenuTopFlare` retains the top-center trigger, original FlareMorph/curves, geometry, top controls, safe zones and split layers. Old two-argument calls, `hakumenu` IPC and `launcher.open("drun")` still select `topFlare`. |
| Shared content | `HakuMenuContent` owns one implementation of tabs, search, selection and keyboard routing. GeneralList, DrunList and ThemeList are unchanged. |
| Dock presentation | Dock App Menu toggles `dockFloating` in Drun mode. Its anchor comes from the actual lifted artwork, including the bounded host offset, side inset and Flickable scroll. |
| Floating geometry | One stable, centered chassis sits above the Dock with a `Theme.pad * 2` gap. Width follows the existing 42% maximum contract with small-output bounds. Height and placement stay within the usable output. Disabled Dock uses a bottom-center fallback. |
| Motion | One reversible scalar uses the Temp Note curves and remaining-distance duration. A subsequent user request reduces full open/close to 504/280 ms (10%/30% shorter); topFlare is now 360/308 ms with its original curves. Content fades after 55% reveal; search receives focus as soon as the clamped geometry reaches its final bounds, during the remaining bounce. Closing preserves the captured seed and displayed content. |
| Footer | Only floating moves tabs/search below the lists. Theme's state column stops above the footer. Switching modes does not change the floating chassis size. |
| Ownership | Style/output transfers reset the old floating surface immediately. Close clears transient anchor/style state. Only the owning `dockFloating` presentation leases Dock visibility. |
| Input | Overlay input is restricted to current/final card, anchor and handoff corridor. A temporary pointer blocker gates the morph without disabling or dimming content; fully revealed items respond immediately. The anchor relays repeated App Menu clicks because the Dock itself remains Top. Outside stays click-through. Both styles keep keyboard/prefix/launch/Escape behavior. |
| Content lifetime | Floating content loads on first use and remains resident on its output. This prevents deferred list callbacks from targeting a destroyed Loader item during rapid close/reopen, without changing the list components. |
| Optional neck | Not added. The plan explicitly makes the decorative connector optional; the final floating card is detached. No shared Flare framework changes were needed. |

## Verification

| Check | Coverage / result |
| --- | --- |
| Baseline | Dock runtime, pin/settings backends, repository checks and TopBar/RoundedScreen pixel matrix passed before the refactor. |
| Top compatibility | The same pixel matrix passed after extraction and after adding floating. Real keyboard tests cover top trigger, General/Drun/Theme, `>`/`~`, left/right, up/down, DesktopEntry execution, Escape and fullscreen focus. |
| Geometry | `test_hakumenu_geometry.js` passes for 320×240 through 2560×1440, borders 0/4/6, icons 32/48/72, Dock enabled/disabled, seed centering, bounds and interpolation/overshoot. |
| Labwc | Full pointer/keyboard suite passes on 1280×720 and 1024×768 outputs. Checks reverse reopen, footer geometry, stable mode widths, keyboard lease, click-through, cross-style/output transfer, fallback and crowded/scrolled Dock anchors. |
| Physical Niri | The full isolated suite passes on the actual Niri session, using disposable HOME/state/settings/pins and mocked launches. |
| Nested MangoWM | Full suite passes when run separately from other nested/current-session fixtures. An initial concurrent run failed the mode/width assertion; the separate repeat passed. |
| Nested Niri | The winit nested backend did not deliver virtual-pointer input to the top trigger, including retries. It is not recorded as a pass; the actual-session suite above covers Niri. |
| Dock regression | Existing pointer suite passes after anchor/lease integration. Stable frame/exclusive reservation checks remain part of the repository gate. |
| Repository gate | Final `precommit_check.sh` passes, including the new HakuMenu suite. A disposable index/object directory leaves the real Git index untouched. Structural QML and whitespace checks pass. |
| Installed session | Hikai was reloaded. The real App Menu opens floating, its second click closes it, and `hakumenu.openDefault` opens the legacy top presentation. Niri confirms the expected keyboard ownership; IPC returns `pong`. Live screenshots were inspected. |
| Artifacts | `/tmp/hakumenu-dual-artifacts/` contains topFlare and floating Drun/Theme screenshots. Virtual input is bound by output name when output-manager changes reorder globals. |

Remaining physical coverage: primary-session Hyprland/MangoWM, real two-monitor
cables and fractional scaling. Isolated geometry/output tests do not imply those
hardware checks passed. Shared user preferences, pins and manual Dock state are
not changed by the isolated suite.

## Reproduce

```bash
node scripts/test_hakumenu_geometry.js
bash scripts/test_hikai_hakumenu.sh
bash scripts/test_hikai_hakumenu.sh --mango
bash scripts/test_hikai_hakumenu.sh --current
bash scripts/test_hikai_shell.sh --headless
```

`--current` moves the session pointer and briefly opens fixture windows. The
default runner stays inside a private headless compositor. Its keyboard fixture
uses the virtual-keyboard protocol and the system US keymap, with no new dependency.

Suggested commit: `feat(hikai): add dock floating HakuMenu alongside top flare`

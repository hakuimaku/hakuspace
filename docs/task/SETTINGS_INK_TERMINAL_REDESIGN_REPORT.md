# Settings — Ink Terminal redesign report

Status: **DONE**

## 1. Summary

The Settings interior now uses a compact domain bar, contextual sidebar, bordered section cards and one persistent footer. Colors, typography and radii follow the existing dynamic Theme. A static, low-opacity grid disappears on small surfaces. The panel prefers 1180 × 750 px, clamped to the selected monitor with 32 px margins.

The provided plan was the implementation reference. `02_ink_terminal.html` was not present in the repository.

## 2. Files changed

Modified:

- `src/home/.config/quickshell/hakuspace/components/SettingsPanel.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/GeneralSettingsPage.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/ShellSettingsPage.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/ConfigEditorPage.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/InfoPage.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/SettingsActionButton.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/SettingsSegmentedToggle.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/SettingsSlider.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/SettingsTooltip.qml`
- `src/home/.config/quickshell/hakuspace/components/settings/ConfigTreeModel.js`
- `scripts/test_config_tree_model.js`
- `scripts/precommit_check.sh`

Added:

- `components/settings/SettingsTopBar.qml`
- `components/settings/SettingsSidebar.qml`
- `components/settings/SettingsConfigBrowser.qml`
- `components/settings/SettingsSectionCard.qml`
- `components/settings/SettingsSearchField.qml`
- `components/settings/SettingsFooter.qml`
- `components/settings/SettingsSliderRow.qml`
- `components/settings/SettingsToggleRow.qml`
- `scripts/settings_ink_harness.qml`
- `scripts/test_settings_ink.sh`
- This report.

The abbreviated component paths share `src/home/.config/quickshell/hakuspace/`. The supplied plan remains untouched. No store, backend, persisted key or configuration format changed. No dependency was added.

## 3. UI architecture

`SettingsPanel` retains screen ownership, layer-shell input ownership and the existing attach → center → expand / close lifecycle. All four page objects remain alive during tab changes.

The top bar owns primary navigation. The contextual sidebar receives section names and scroll anchors from the visible page. General derives groups and filtering from `SettingsStore.catalog`; Shell exposes its six existing sections; Info derives available groups from its existing row generators. Visible-section tracking follows scrolling, including the last section at the bottom of a page.

Config uses the same sidebar for the existing `ConfigTreeModel.js` tree and routes file selection through `ConfigEditorPage.requestSelect`. There is no nested duplicate browser. Small panels replace the sidebar with a keyboard-accessible section/file selector.

Each page exposes status, action labels, guards and dispatch to `SettingsFooter`. Config retains its original action state machine. Panel-level close/reload confirmations override the footer with Keep/Discard. Previous page footers and the separate confirmation overlay were removed.

General and Shell rows stack at narrow widths. Shell sliders retain their live bindings and show numeric badges. Info switches between two columns and one column. Internal tab changes fade for 160 ms without recreating pages.

## 4. Behavior intentionally preserved

Baseline before edits:

- `git status --short`: only `?? docs/task/plan/SETTINGS_INK_TERMINAL_REDESIGN_PLAN.md`.
- Settings controller: **PASS**, 17 tests.
- Existing Settings QML harness: **PASS**, missing/v1/v3/v4 scenarios.
- QML structural syntax check: **PASS**.

Contracts verified from the four stores and pages:

- General dirty state compares the live values with the last confirmed snapshot. Apply sends changed keys only and requires a ready, valid, dirty draft with no IO in progress. Unsupported/missing/duplicate assignments retain their edit restrictions. Newer edits survive an in-flight save.
- General Reload replaces the draft only after a backend read. Dirty Reload prompts Keep/Discard; Keep retains edits.
- Shell controls change the shared live preview immediately. Discard restores the saved snapshot; Reset previews defaults; Apply persists validated changes or an explicit migration. Migration alone is not a dirty user edit. IO still freezes Shell editing.
- Close prompts if any General, Shell or Config draft is dirty. Keep preserves all drafts; Discard restores all three domains and closes. Shell loading/saving still blocks closing.
- Config dirty state compares text with saved text. Pending file IDs, revision conflict protection, byte limits, stale-result handling and newer-edit preservation remain in the unchanged store.
- Config retains Cancel / Discard & Switch / Save & Switch, Keep Editing / Discard & Reload, and Cancel / Open Anyway. VS Code opens the saved file; the warning preserves the current draft.
- Escape cancels a panel confirmation first, then a Config confirmation, then requests close. The editor continues receiving text and its own editing shortcuts.
- Info remains a local, refreshable snapshot with optional rows and full-value tooltips.

## 5. Any behavior changed and why

Presentation changes only: local search, section navigation, responsive contextual selectors, denser card layouts and the shared footer. Search never changes catalog entries or values. Search updates return the form to its top so results cannot remain outside the viewport.

Escape handling is also attached to the common content ancestor, allowing focused child controls to use the same cancellation/close ordering. The original initial-focus handler remains.

Thin accent-derived borders remain visible even when `Theme.border` is transparent. The production accent is always derived from Theme.

## 6. General regression results

**PASS** in the redesign harness:

- All 17 catalog rows exist with an empty search.
- Search by label, key, group and hint; clearing restores all groups; no-result search preserves values.
- Section navigation and active sidebar tracking.
- Boolean, path, text, integer and enum draft changes; invalid integer validation disables Apply.
- Actual list Add and Remove controls, followed by persistence/reload.
- Clean Reload; dirty Reload → Keep and Discard; Apply and re-read.
- Dirty close → Keep and Discard.
- Real keyboard typing in search and Escape from search.

The unchanged General controller suite also passes (10 tests). Some field-type edits are exercised through the existing store API; list actions and search use production controls.

## 7. Shell regression results

**PASS** in the unchanged Settings harness (all four migration/startup scenarios): base radius, rounded-screen radius, border thickness, surface tones, dynamic Theme isolation, app accessories, icon size, hover lift/scale, Dockbar visibility/exclusive space, TopBar modules, invalid edit rejection, live preview, Discard, Reset, Apply and Reload persistence.

**PASS** in the redesign harness: actual radius slider movement, live radius updates, Discard, dirty Reload Keep/Discard, Reset preview, Apply through the common footer and real Space activation of an accessory toggle.

The Settings controller suite passes (17 tests). No existing harness assertion was weakened or structurally rewritten.

## 8. Config regression results

**PASS** in the redesign harness with three disposable files:

- File discovery and clean selection.
- Dirty switch → Cancel / Save & Switch / Discard & Switch.
- Exact saved text survives switching back.
- Dirty Reload → Keep Editing / Discard & Reload.
- Clean external-open flow and dirty VS Code warning → Cancel / Open Anyway.
- Open Anyway retains the draft.
- Real keyboard input reaches `PlainTextEditor` and the shared store.
- Save through the shared footer.
- Escape from the focused editor cancels confirmation before requesting Settings close.

The unchanged Config backend suite passes (7 tests), including file/revision safety. Tree-model fixtures pass. External launches use `/usr/bin/true` during testing; a real VS Code window was not launched.

## 9. Info regression results

**PASS**: load, refresh, populated cards, filtering unavailable groups and scrolling. The unchanged Info controller suite passes (9 tests).

**PASS** in the final harness at all three sizes and on Hyprland: removing optional hardware groups leaves no empty cards; hovering an elided repository value opens a tooltip containing its complete value.

## 10. Responsive/runtime observations

The actual Settings panel and input routes passed on isolated Labwc outputs at **1920×1080**, **1366×768** and **640×480**, with cyan, green and amber test accents. Each size runs the same workflow, including Tab/Enter/Space, real editor/search input, outside-click close, Escape, reopen and ownership transfer between two outputs.

The workflow also passed on the currently active **Hyprland** session using disposable HOME/settings/config fixtures. It did not write the user's real settings. The current-session runner uses real virtual keyboard/pointer events.

Runtime captures were inspected for the four pages and the compact Config confirmation footer. Examples: [General on Hyprland](/tmp/ink-settings-current/current-general.png), [Config on Hyprland](/tmp/ink-settings-current/current-config.png), [compact Config confirmation](/tmp/ink-settings-artifacts/640x480-config-confirmation.png). Artifacts are in `/tmp/ink-settings-artifacts/` and `/tmp/ink-settings-current/`; these temporary files are not committed repository assets. Screenshots capture the Settings surface rather than the desktop behind it.

## 11. Automated test commands + exact PASS/FAIL

| Command | Result |
| --- | --- |
| `python3 scripts/qml_syntax_check.py $(rg --files --hidden src/home/.config/quickshell -g '*.qml') scripts/settings_ink_harness.qml` | PASS |
| `python3 scripts/test_setting_ctl.py` | PASS, 10 tests |
| `python3 scripts/test_hikai_settings_ctl.py` | PASS, 17 tests |
| `python3 scripts/test_hakucfg_editor_ctl.py` | PASS, 7 tests |
| `python3 scripts/test_hakuspace_info_ctl.py` | PASS, 9 tests |
| `node scripts/test_config_tree_model.js` | PASS |
| `bash scripts/test_hikai_shell.sh` | PASS, all four scenarios |
| `bash scripts/test_hikai_shell.sh --headless` | PASS, runtime and RoundedScreen pixel matrix |
| `bash scripts/test_settings_ink.sh` | PASS, 1920×1080 |
| `INK_SIZE=1366x768 INK_ACCENT='#a3be8c' bash scripts/test_settings_ink.sh` | PASS |
| `INK_SIZE=640x480 INK_ACCENT='#d9a066' bash scripts/test_settings_ink.sh` | PASS |
| `INK_SIZE=current INK_ARTIFACT_DIR=/tmp/ink-settings-current bash scripts/test_settings_ink.sh --current` | PASS, Hyprland |
| `env -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE scripts/precommit_check.sh` | PASS, complete suite (`All checks passed!`) |

The first complete-gate attempt failed at the unrelated `unified-navigation` Taskbar bottom-pixel assertion. The unchanged HEAD control and the redesign both passed a separate repeat of `HAKUSPACE_CHROME_TEST=1 bash scripts/test_hikai_dock.sh`, including its pixel checker. No assertion, timer or non-Settings production code was changed to accommodate this failure.

Precommit uses a disposable Git index and object directory, with the original object directory supplied as an alternate. New files are added only to that temporary index to satisfy the repository's untracked-file guard. The real Git index is unchanged. Initial sandbox denial of private D-Bus sockets was resolved by running the isolated compositor checks with the required socket access.

## 12. Known limitations / follow-ups

- Niri and MangoWM physical sessions were not available for direct interaction testing. Physical multi-monitor hardware was not separately tested; two-output ownership is covered in Labwc.
- No real VS Code application launch was tested; backend invocation and warning semantics use a stub launcher.
- Existing baseline fixture warnings remain: missing unrelated helper binaries, offscreen window-mask/deprecation warnings and a teardown `HScrollBar` warning. The real Hyprland Settings run emitted no QML type/reference/binding errors.
- The repository's longer selection/toggle animation timings remain inherited from its existing motion primitives. No global animation settings were changed.
- Temporary screenshots/logs are evidence for this session and may be removed by system cleanup.

## 13. git diff --check result

**PASS**. No whitespace errors. No debug logging or temporary plan notes were added to production code.

## 14. git status --short

No commit was created; the supplied plan is still untracked. The real index has no staged changes.

```text
 M docs/task/QUICKSHELL_STYLE.md
 M scripts/hikai_dock_harness.qml
 M scripts/precommit_check.sh
 M scripts/test_config_tree_model.js
 M scripts/test_hikai_settings_ctl.py
 M scripts/test_taskbar_pins_ctl.py
 M src/core/backend/user/hikai_settings_ctl.py
 M src/core/backend/user/taskbar_pins_ctl.py
 M src/home/.config/quickshell/hakuspace/components/SettingsPanel.qml
 M src/home/.config/quickshell/hakuspace/components/motion/SelectionPill.qml
 M src/home/.config/quickshell/hakuspace/components/settings/ConfigEditorPage.qml
 M src/home/.config/quickshell/hakuspace/components/settings/ConfigTreeModel.js
 M src/home/.config/quickshell/hakuspace/components/settings/GeneralSettingsPage.qml
 M src/home/.config/quickshell/hakuspace/components/settings/InfoPage.qml
 M src/home/.config/quickshell/hakuspace/components/settings/SettingsActionButton.qml
 M src/home/.config/quickshell/hakuspace/components/settings/SettingsSegmentedToggle.qml
 M src/home/.config/quickshell/hakuspace/components/settings/SettingsSlider.qml
 M src/home/.config/quickshell/hakuspace/components/settings/SettingsTooltip.qml
 M src/home/.config/quickshell/hakuspace/components/settings/ShellSettingsPage.qml
 M src/home/.config/quickshell/hakuspace/services/ShellSettingsStore.qml
?? docs/task/SETTINGS_INK_TERMINAL_REDESIGN_REPORT.md
?? docs/task/plan/SETTINGS_INK_TERMINAL_REDESIGN_PLAN.md
?? scripts/settings_ink_harness.qml
?? scripts/test_settings_ink.sh
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsConfigBrowser.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsFooter.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsSearchField.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsSectionCard.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsSidebar.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsSliderRow.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsToggleRow.qml
?? src/home/.config/quickshell/hakuspace/components/settings/SettingsTopBar.qml
```

Suggested commit description: `feat(settings): redesign Settings as Ink Terminal with contextual navigation and shared footer`.


## 15. Live reload correction (2026-10-21)

The original cold-start checks missed a live reload failure in the user's running instance `khijgko5nt`. Introducing inline `SliderRow` / `ToggleRow` components into an already loaded page produced `is not a type` on Quickshell 0.3.2. The failure was reproduced in a disposable instance by loading the old page and replacing it with the redesigned page without restarting the process. A fresh process using the same files succeeded; symlink-based cold startup also succeeded.

The two row components now live in `SettingsSliderRow.qml` and `SettingsToggleRow.qml`. Their existing bindings, ranges, accessibility and store calls are unchanged; the owning page passes its original editability guard. Both new files were linked into the deployed Settings directory using the repository's existing per-file symlink convention.

`test_settings_ink.sh` now starts a minimal page, introduces the real Shell page through a warm reload, then reloads the complete interaction harness in the same process. Any failed configuration load fails the runner. No existing behavioral assertion was disabled.

Follow-up results:

| Check | Result |
| --- | --- |
| Warm reload + full Settings workflow, 1920×1080 | PASS |
| Warm reload + full Settings workflow, 640×480 | PASS |
| Warm reload + full Settings workflow, current Hyprland | PASS |
| Existing `bash scripts/test_hikai_shell.sh` | PASS, all four scenarios |
| `python3 scripts/test_hikai_settings_ctl.py` | PASS, 17 tests |
| QML syntax and whitespace checks | PASS |
| `qs ipc -i khijgko5nt call shell reload` | PASS; `Configuration Loaded` at 11:12:20 Asia/Ho_Chi_Minh |
| `qs ipc -i khijgko5nt call shell ping` | PASS; `pong` |
| Actual instance log after that reload | No new configuration-load error observed |

The earlier full precommit result predates this correction; the targeted Settings checks above were rerun after it. Old errors remain in the instance's historical log. Earlier playerctld/MPRIS and portal warnings are separate from the corrected Settings parser failure; no logging category was suppressed. No Git commit was made.


## 16. Requested style refinements (2026-10-21)

Implemented the requested visual changes:

- Settings buttons now visibly morph their corner radius and width on hover/focus and contract on press, reusing the existing motion primitives. Primary tabs also share a moving morph selection background. Segmented controls use the same Settings button treatment.
- General and Shell no longer display internal variable/key names. Validation messages, store keys, editable-key rules and search metadata are retained.
- The outer Settings frame has no border. Normal desktop content has 24 px of outer padding; constrained surfaces use 12 px to retain usable content space. Main content, section cards, sidebar rows, footer actions, fields, sliders and tooltips also have more spacing/padding.
- Option descriptions use a neutral gray derived from the lightness of `Theme.fgDim`, so a tinted dynamic Theme cannot turn descriptions into colored text.
- Config has **Tree** and **Buttons** sidebar tabs. Both use `ConfigEditorStore.files` and the existing selection/dirty-draft confirmation route. The view choice is local UI state and does not change preferences, selected files or drafts.
- Button labels use short titles such as **Hyprland**, **Niri**, **Cava Underbar**, **Hypridle** and **MangoWM**. Unknown filenames use a readable basename; extensionless dotfiles retain nonempty labels. Full file IDs remain available in tooltips and the editor toolbar. Compact screens keep both style tabs alongside the file selector. Very short Config viewports hide the generic page subtitle and reduce the editor inset to preserve readable text.

Regression coverage now verifies hidden keys, neutral description colors under a deliberately tinted Theme, borderless frame/padding, both browser styles, short titles, pending dirty-file protection across style switches, and button morph/press/release through real pointer events. Existing tests remain intact. The search locator was updated for the field's new 38 px height; its behavior assertions were preserved.

| Follow-up check | Result |
| --- | --- |
| `node scripts/test_config_tree_model.js` (tree and short titles) | PASS |
| `bash scripts/test_settings_ink.sh` (desktop workflow and warm reload) | PASS |
| `INK_SIZE=640x480 INK_ACCENT='#d9a066' bash scripts/test_settings_ink.sh` | PASS |
| `INK_SIZE=current INK_ARTIFACT_DIR=/tmp/ink-settings-current bash scripts/test_settings_ink.sh --current` | PASS, Hyprland |
| `bash scripts/test_hikai_shell.sh` | PASS, all four scenarios |
| `python3 scripts/test_hikai_settings_ctl.py` | PASS, 17 tests |
| QML syntax, shell syntax and whitespace checks | PASS |
| Complete precommit after style refinements | PASS, `All checks passed!` |

Updated visual evidence: [General](/tmp/ink-settings-current/current-general.png), [Config buttons](/tmp/ink-settings-current/current-config-buttons.png), [button hover](/tmp/ink-settings-current/current-button-hover.png). No stores or backend formats changed. No commit was created.

## 17. Logo and accent morph navigation (2026-10-21)

- The upper-left Settings logo now uses the requested `󰮯` glyph.
- General, Shell, Config and Info share an accent selection background that morphs between tabs. Selected text stays black during hover and press; unselected hover fades to the neutral gray surface.
- General/Shell/Info section navigation and both Config browser styles now use moving accent selection backgrounds with black text. Config's Tree/Buttons selector uses the same selected and hover colors.
- Sidebar highlights resynchronize after the positioners finish layout, including nested Config tree groups. Selected delegates assign their targets synchronously, avoiding deferred callbacks into delegates destroyed during rapid search changes.

Regression coverage verifies the requested glyph, selected accent colors and black text, highlight alignment after search/layout changes, both Config styles and file switches, and real pointer hover on primary tabs and section navigation without changing selection. Screenshots wait for selection transitions to finish.

| Check after this refinement | Result |
| --- | --- |
| Desktop workflow with two warm reloads, 1920×1080 | PASS |
| Compact workflow, 640×480, alternate accent | PASS |
| Current Hyprland workflow with disposable settings fixtures | PASS |
| QML structural syntax, shell syntax and whitespace checks | PASS |
| `qs ipc -i khijgko5nt call shell ping` | PASS, `pong` |
| Running instance hot reload | `Configuration Loaded` at 11:46:18; no new Settings load error observed |

Visual evidence: [General](/tmp/ink-settings-current/current-general.png), [selected Shell section](/tmp/ink-settings-current/current-navigation-accent.png), [Config buttons](/tmp/ink-settings-current/current-config-buttons.png), [Config tree after file switch](/tmp/ink-settings-current/current-config-tree.png).

The complete precommit result in section 16 predates this refinement; the focused UI and syntax checks above were rerun. Niri and MangoWM were not physically exercised. No stores or backend formats changed, and no commit was created.

## 18. Slower morph timing (2026-10-21)

Settings navigation highlights and button corner morphs now use the existing `HAnimation.slow` tier (540 ms). Highlight trailing edges finish at approximately 621 ms with the existing 1.15 trail factor; segmented controls use the same timing. Desktop UI regression with warm reload, QML structural syntax and whitespace checks passed. The running instance loaded the update at 11:48:23. No commit was created; compact/current-compositor workflows and the complete precommit were not rerun for this timing-only adjustment.

## 19. Shared Theme morph duration (2026-10-21)

`Theme.qml` now owns `morphDuration` (540 ms). Primary tabs, section navigation, both Config browser styles, segmented controls and button corner morphs bind to `Theme.morphDuration`, so one value controls their duration. The Settings desktop regression with warm reload, QML structural syntax and whitespace checks passed. The running instance loaded the update at 11:51:02. No commit was created; the complete precommit and compact workflow were not rerun for this binding-only change.

## 20. Standard Theme corner radii (2026-10-21)

Settings controls now use `Theme.radius` directly, including buttons, selection backgrounds, cards, fields, logo, slider visuals, badges and tooltips. Removed local numeric radii, radius caps and hover-driven corner formulas. The existing panel opening transition still resolves to the standard `Theme.largeRadius`. Selection highlights also observe changes to their target's radius so live Shell radius previews update their corners. Accent selection movement, hover/press scaling and `Theme.morphDuration` remain active.

Updated regression assertions verify that Settings buttons follow the live Theme radius and preserve it during hover. Desktop, compact 640×480 and current Hyprland workflows passed, as did all four existing Hikai shell scenarios, QML structural syntax and whitespace checks. The running instance reloaded successfully at 11:53:28. No commit was created; the complete precommit was not rerun for this refinement.

## 21. Remove the custom morph duration (2026-10-21)

Removed `Theme.morphDuration` at the user's request. Settings selection backgrounds use the existing `HAnimation.slow` duration (540 ms), preserving the current speed and standard Theme radius bindings. QML structural syntax and whitespace checks passed. The initial desktop run failed at the Info hover pointer assertion; an unchanged rerun and the current Hyprland workflow both passed. The running instance reloaded successfully at 11:54:32. No commit was created; the complete precommit was not rerun.

## 22. Info sidebar navigation across both columns (2026-10-21)

Reproduced the reported failure by activating every Info sidebar entry: the original implementation failed at **User & Session**, the card on the right of the first grid row. Scroll position alone could only identify the first card at a shared vertical coordinate; lower cards could also be replaced by the bottom-of-scroll fallback.

Info now preserves the explicitly requested section until the scroll position changes or snapshot data is replaced. Navigation maps the card into scroll-content coordinates, cancels any running flick, clamps scrolling to the viewport and reanchors after grid layout changes. The selected card gets an accent border, making navigation within a shared row visible. Manual scrolling resumes section tracking. Optional-group filtering, Refresh, both responsive layouts and long-value tooltips remain intact.

Regression coverage activates every actual sidebar button or compact selector entry, verifies the selected section and highlighted card, checks that the destination is visible, and verifies tracking resumes after manual scrolling. The original right-column failure was confirmed before the production correction. The existing real tooltip hover assertion now permits at most four pointer-motion redeliveries while compositor/layout events settle; it still fails if the target is not hovered.

| Check | Result |
| --- | --- |
| Original desktop behavior with new navigation assertions | FAIL at User & Session, reproducing the bug |
| Corrected desktop workflow and warm reload | PASS |
| Compact 640×480 workflow and selector navigation | PASS |
| Current Hyprland workflow and selected right-column screenshot | PASS |
| QML structural syntax and whitespace checks | PASS |
| Running instance reload | Configuration Loaded at 12:00:47 |

Visual evidence: [selected User & Session card](/tmp/ink-settings-current/current-info.png). No backend/store semantics changed and no commit was created. The complete precommit and physical Niri/MangoWM sessions were not rerun for this correction.

## 23. Info block hover feedback (2026-10-21)

Info card highlights now follow pointer hover across each heading and body instead of the active sidebar section. The card background and accent border fade using the existing `HAnimation.buttonHoverDuration`; corners still use `Theme.radius`. Sidebar navigation and right-column selection remain functional without keeping the destination card illuminated.

The UI harness verifies that sidebar activation alone does not highlight a card, hovering a value highlights its containing block while preserving its tooltip, and moving the pointer away clears the highlight. Desktop, compact 640×480 and current Hyprland workflows passed, together with QML structural syntax and whitespace checks. The running instance reloaded at 12:03:41. Visual evidence: [Info block hover](/tmp/ink-settings-current/current-info-block-hover.png). No commit was created; the complete precommit was not rerun.

## 24. Minimum Taskbar/Dockbar icon size (2026-10-21)

The shared icon-size slider, QML draft validation, shell preference backend and shared pin-size controller now accept 24–72 px in steps of four. The existing 36 px default is retained. Both Taskbar and Dockbar already consume the same app-bar icon-size preference; no separate sizing path was added. The style reference now documents the updated range.

Regression coverage accepts 24 and 28 px, rejects values below 24 and off-step sizes without changing saved files, verifies saved shell sizes synchronize shared pins, exercises the actual slider's 24 px preview and Discard, and checks that the compact Dock's shared app content uses 24 px icons and a 41 px target height. The new backend checks reproduced the original rejection before the correction.

| Check | Result |
| --- | --- |
| Shell preference backend | PASS, 17 tests |
| Shared Taskbar pin controller | PASS, 9 tests |
| Settings workflow with warm reload and actual icon slider | PASS |
| Dock lifecycle and geometry harness | PASS |
| QML structural syntax and whitespace checks | PASS |
| Running instance reload | Configuration Loaded at 12:06:00 |

No user preferences were changed and no commit was created. The complete precommit and physical Niri/MangoWM sessions were not rerun for this change.

## 25. Info hover selects contextual navigation (2026-10-21)

Info's active sidebar section now follows the hovered card before falling back to explicit navigation or scroll tracking. The existing card hover state drives this binding, so moving the pointer between cards updates the shared sidebar accent without scrolling the viewport or introducing new UI state. Sidebar clicks retain their scroll-navigation behavior.

Added real-pointer coverage for hovering User & Session in the right column, verifying the corresponding sidebar selection and morph target, and asserting the content scroll position remains unchanged. The regression failed against the earlier implementation and passed after the correction. Desktop, compact 640×480 and current Hyprland workflows passed; QML structural syntax and whitespace checks also passed. The running instance loaded the update at 12:08:40. Visual evidence: [Info hover and matching sidebar selection](/tmp/ink-settings-current/current-info-sidebar-hover.png). No commit was created; the complete precommit was not rerun.

## 26. Info selection follows hover only (2026-10-21)

Removed Info's scroll-position and explicit-navigation fallbacks from `activeSection`. An Info section is active only while its card is hovered. Sidebar clicks still scroll to the requested card and responsive layout changes keep that destination aligned, but navigation without hover does not select a section. The shared section pill fades out when its target is no longer selected, while retaining its geometry for the next morph transition.

Updated regression expectations preserve sidebar navigation/visibility checks and verify no selection without card hover, clearing selection on pointer leave, and remaining unselected after scrolling to the bottom outside cards. Real right-column hover and matching sidebar morph checks remain intact. The previous implementation failed the new no-hover assertion; the corrected desktop, compact 640×480 and current Hyprland workflows passed. QML structural syntax and whitespace checks passed. The running instance loaded the update at 12:12:15. Visual evidence: [Info scrolled without hover or sidebar pill](/tmp/ink-settings-current/current-info-no-hover.png). No commit was created; the complete precommit was not rerun.

## 27. Retain the last Info selection (2026-10-21)

Info now keeps one active section updated by sidebar navigation or pointer entry into a card. That section controls both the card highlight and sidebar pill. Pointer leave and scrolling do not clear or change it; entering another card or selecting another sidebar item updates both. A snapshot refresh preserves the selection while its section remains available and clears it if the section disappears. Explicit scroll destinations remain separate from hover selection so hover does not move the viewport.

Updated regression expectations verify sidebar activation highlights each destination, the last hover selection survives pointer leave and scrolling to the bottom, and Refresh preserves a valid selection. Existing right-column hover, compact navigation, tooltip and morph checks remain in place. The previous implementation failed the restored sidebar-selection assertion. Desktop, compact 640×480 and current Hyprland workflows passed, together with QML structural syntax and whitespace checks. The running instance loaded the update at 12:15:57. No commit was created; the complete precommit was not rerun.

## 28. Restrained accent styling (2026-10-21)

Settings now uses neutral Theme colors for decorative borders, separators, section/tree headings, the logo, numeric value badges, validation text and footer status. Info cards retain their selected/hovered state with a gray surface and outline. Shared Settings buttons use neutral hover/press defaults instead of inheriting the accent surface from MorphButton.

Accent remains on selected navigation, active controls, focused inputs/text selection and enabled Apply/Save actions. Disabled primary actions are gray, and confirmation Discard no longer receives the primary accent treatment. Existing Theme radius bindings, morph timing, Info selection persistence, action guards and stores remain unchanged. The style guide documents these color roles.

Desktop and alternate-accent compact 640×480 workflows passed, as did all four existing Hikai shell scenarios, QML structural syntax and whitespace checks. The initial live Hyprland run timed out while opening the panel; an unchanged rerun passed the complete workflow. The running instance loaded the style update at 12:19:01. Reviewed screenshots: [General](/tmp/ink-settings-current/current-general.png), [Info selection](/tmp/ink-settings-current/current-info-sidebar-hover.png), [Config](/tmp/ink-settings-current/current-config-buttons.png). No commit was created; the complete precommit was not rerun.

## 29. Stable footer actions and unsaved-change UX (2026-10-21)

Shell footer actions now stay on one horizontal row at every supported width, with uniform button widths, a larger gap before Discard/Apply, and Apply fixed at the right. Compact surfaces place status above the same single action row. Tooltips describe Reload, preview-only Reset, rollback-only Discard and persistent Apply. Clean Shell status now says that changes are saved.

Reset and Discard require a centered modal that clearly names the affected Shell settings. Dirty Reload uses the same modal. These confirmations no longer replace or shift the normal footer actions. Reset still only previews defaults until Apply; Discard restores the saved Shell draft and live previews.

Escape with unsaved edits opens a modal listing the modified domains and offering Keep Editing, Discard & Close and Apply & Close. Keep Editing has initial focus, Enter follows that safe default, Escape cancels the modal, and editing focus is restored. Invalid values or Config conflicts disable Apply & Close with an explanation. Saving blocks dismissal and waits for all submitted General/Shell/Config operations. A failed save leaves the dialog and failed draft open; successfully saved pages remain saved. Retrying closes Settings only after no dirty drafts remain.

Regression coverage verifies all four footer buttons share one row within the footer, confirmed/cancelled Reset and Discard, safe default Enter, real Escape cancellation, invalid-draft/conflict guards, multi-domain persistence, a real backend revision conflict, retained failed text, and successful retry. Existing navigation, Info hover persistence and Config workflows remain covered. Popup resource discovery is confined to imperative test calls to avoid non-bindable-property warnings; dialog screenshots capture content and actions separately because the Quickshell proxy content item cannot be grabbed directly.

| Check | Result |
| --- | --- |
| Desktop workflow, 1920×1080, including warm reload | PASS |
| Compact workflow, 640×480 | PASS |
| Current Hyprland workflow | PASS |
| Existing Hikai shell harness | PASS, all four scenarios |
| QML structural syntax and whitespace checks | PASS |
| Running instance reload | Configuration Loaded at 12:30:18; no continuing load failure |

Visual evidence: [single-row compact footer](/tmp/ink-settings-artifacts/640x480-shell.png), [unsaved-change explanation](/tmp/ink-settings-current/current-unsaved-close.png), [dialog actions](/tmp/ink-settings-current/current-unsaved-close-actions.png), [save-conflict explanation](/tmp/ink-settings-current/current-close-save-error.png).

A transient load error occurred while the footer API and its panel caller were being updated; the completed files loaded successfully afterward. No logging category was suppressed. No backend persistence contract changed and no commit was created. Suggested commit: `feat(settings): improve footer actions and unsaved-change dialogs`. The complete precommit and physical Niri/MangoWM sessions were not rerun for this change.

## 30. Remove overlapping navigation outlines (2026-10-21)

Transparent Settings buttons now leave the shared selection pill responsible for their surface instead of painting a separate border. This removes the gray outline that shifted against the pill during hover scaling. The change covers contextual sidebars, both Config navigation styles, top tabs and segmented controls. Removed local focus-border overrides from Config tree rows and segmented controls; keyboard focus remains visible through an inset underline. Regular action buttons retain their borders. Theme radius and existing morph timing remain unchanged.

Desktop 1920×1080, compact 640×480 and current Hyprland workflows passed, including pointer navigation and keyboard actions. Reviewed the Config sidebar with the peach accent used in the reported example; its selected pill has one clean silhouette. Structural QML and whitespace checks passed. No commit was created; the complete precommit was not rerun.

## 31. Commit validation (2026-10-21)

The complete `scripts/precommit_check.sh` passed before the user-requested commit, including Settings warm reload, Dock and HakuMenu workflows, backend tests and script boundary checks. The initial sandboxed run could not create test sockets; rerunning with permission completed successfully. The supplied plan retains its original Markdown hard line breaks. Physical Niri/MangoWM sessions were not rerun.

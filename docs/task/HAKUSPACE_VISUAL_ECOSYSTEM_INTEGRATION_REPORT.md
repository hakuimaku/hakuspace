# HakuSpace visual ecosystem integration report

Historical V1 report. The external engine architecture below is superseded by
[the V2 internal-engine migration](HAKUSPACE_INTERNAL_ICON_ACCENT_V2_REPORT.md).

## V1.0 — Baseline audit (2026-10-16)

All six repositories started clean. The workspace contains sibling checkouts;
production defaults must still resolve under HOME, never under this workspace.

Canonical state: `src/core/lib/haku_theme.sh` loads
`~/.local/state/hakuspace/state/state.env`. `theme_ctl.sh` validates, saves,
renders and applies. `gen_style.sh` also saves state today.

Mutation/caller inventory:

- Classic `theme_rofi.sh` and `accent_color_picker.sh` → `theme_ctl set-accent`.
- Hikai `ThemeAccentPage.qml` → `theme_ctl set-accent`; IPC opens this UI.
- Compatibility `change_theme.sh --accent` → `theme_ctl set-accent`.
- `wallpaper_ctl.sh apply_accent_color` → gen_style + apply_style (bypass).
- `random_wallpaper.sh` → gen_style + apply_style (bypass).
- `scripts/state.sh` initializes font via gen_style --font (legacy persistence).
- `session_start.sh --early` restores the shell but currently does not reconcile
  appearance or icon accent.
- `opaque_theme.sh` reloads consumers only; it does not mutate accent.

Scope: archive setup/helpers/tests; appearance library/controller; theme
controller; both wallpaper callers; state initialization/session restore;
assets orchestration; renderer ownership; README/core theme docs and tests.
Core deployment flattens every src/core basename into ~/.local/bin, so new
scripts must work in both source and flat deployment layouts.

Upstream contracts verified from local code:

| Component | Build / install | Destination / safety |
| --- | --- | --- |
| Haku Cursor | make PALETTE; make verify; make install THEME=PALETTE | XDG_DATA_HOME/icons/Haku-Palette; installer removes target, so archive needs an ownership guard |
| Hikaide | python3 scripts/install_gtk_theme.py --dest ~/.themes | Recognized Hikaide replacement only; upstream preserves previous theme |
| Hikaide-Symbols | python3 scripts/build.py; python3 scripts/validate.py; scripts/install.sh [--replace] | ~/.icons/Hikaide-Symbols; upstream .hikaide-symbols ownership guard |
| icon-accent | copy executable + icon_accent.py together | ~/.local/bin; no source checkout at runtime |

Niri's installed `niri msg action --help` exposes no cursor setter. Mango's
CLI (`mango -h`) exposes no cursor setter; current configs contain no theme
selection. Use environment for their next session, without editing configs.
Hyprland can use best-effort `hyprctl setcursor` when its session is active.

Safety: refuse dirty source updates, unmanaged theme/cursor replacement and
non-managed icon-accent executables; never reset checkouts. Optional icon
failures must leave saved core state and rendered outputs intact. No cursor
rebuild or GTK CSS mutation on accent changes.

Implementation batches: V1.1 archive installer, V1.2 appearance controller,
V1.3 icon reconciliation, V1.4 canonical callers/renderer, V1.5 post-install,
V1.6 automated integration, V1.7 WM smoke, V1.8 documentation/cleanup.
Results and remaining manual checks follow below as work completes.

## Implemented architecture and batches

| Batch | Result |
| --- | --- |
| V1.1 | Modular upstream installer, safe cached sources/local overrides, managed updates, copied runtime executable/module, atomic metadata; fresh install and guard tests passed |
| V1.2 | Shared appearance contract; status/verify/apply; schema-aware gsettings; atomic cursor environment; guarded Hyprland live setter |
| V1.3 | Installed icon-accent reads only canonical state via haku_theme; warning/strict failure policy; set-accent/apply reconcile, font/size do not |
| V1.4 | Wallpaper controller and automation route through theme_ctl; initialization uses set-font; renderer no longer writes state |
| V1.5 | Assets post-install verify → activate → one theme apply/reconcile; early session startup also reconciles |
| V1.6 | Fresh/update, archive moved away, A/B, idempotence, missing executable, reinstall repair, real wallpaper extraction and unmanaged-install refusal passed in temporary HOME |
| V1.7 | Controller/environment smoke passed; interactive WM acceptance pending (see matrix) |
| V1.8 | Both READMEs, core theme/app docs and this report updated; upstream visual repos remain unchanged |

Runtime dependency chain:

```text
Classic / Hikai / CLI / wallpaper
  → theme_ctl set-accent
  → validate + canonical state.env
  → gen_style (read/render only) → apply_style (reload)
  → appearance_ctl sync-accent
  → installed ~/.local/bin/icon-accent + icon_accent.py
  → installed ~/.icons/Hikaide-Symbols
```

`theme_ctl apply` renders/reloads and reconciles even when canonical accent has
not changed. Optional sync errors never roll back saved state or core outputs.
`appearance_ctl apply` selects installed assets, without recoloring; this avoids
a second recolor in the assets orchestration. Installation metadata is never
loaded as theme state. No visual artwork or engine source was vendored.

The archive's palette default is centralized in `lib/common.sh`. Runtime theme
selection defaults are centralized in `haku_appearance.sh`. Both read optional
user `hakuspace/appearance.env` under XDG_CONFIG_HOME; a configured palette
there derives the cursor theme name at runtime. Environment overrides and
production HOME/XDG paths work without assuming sibling source checkouts.

## Files changed

HakuSpace:

- `src/core/lib/haku_appearance.sh` (new): appearance configuration/defaults.
- `src/core/backend/theme/appearance_ctl.sh` (new): activation, verification,
  status and optional icon sync.
- `src/core/backend/theme/theme_ctl.sh`: reconcile after set-accent/apply.
- `src/core/backend/theme/wallpaper_ctl.sh`: canonical mutation delegation.
- `src/core/theme/random_wallpaper.sh`: delegate image/video application and
  accent extraction to wallpaper_ctl, deleting the duplicate accent flow.
- `src/core/theme/gen_style.sh`: renderer-only API; locate shared library in
  both source and flat deployment layouts.
- `src/core/theme/apply_style.sh`: same source/flat shared-library resolution.
- `src/core/lib/haku_theme.sh`: document controller ownership.
- `src/core/sys/session_start.sh`: best-effort appearance/theme reconciliation.
- `scripts/state.sh`: initialize font via the canonical controller.
- `scripts/assets.sh`, `scripts/variables.sh`: safe archive update/override,
  updated dry run, post-install activation/reconciliation.
- `scripts/test_visual_ecosystem.py` (new): controller tests plus opt-in real
  upstream installation/integration acceptance.
- `scripts/precommit_check.sh`: include headless visual checks.
- `README.md`, `docs/core/theme.md`, `docs/core/app.md`, this report.

Archive:

- `setup.sh`: installation orchestration only.
- `lib/common.sh`, `lib/source_repo.sh`, `lib/install_cursor.sh`,
  `lib/install_gtk_theme.sh`, `lib/install_icons.sh`,
  `lib/install_icon_accent.sh`, `lib/verify_assets.sh` (new).
- `tests/test_install.py` (new), `.gitignore` (Python bytecode).
- `README.md`: Haku stack, ownership, overrides, install/update and test usage.

No source changes in haku-cursor, hikade-gtk-theme, hikaide-symbols or icon-accent.
Wallpaper artwork and the README artist credits table are preserved.

## Commands run and results

Commands below are relative to the sibling workspace unless noted.

| Command/check | Result |
| --- | --- |
| `python3 -m unittest discover -s hakuspace-archive/tests -v` | 5 passed; real local shallow clone, fast-forward update, dirty/divergent refusal, local override, unmanaged cursor/executable preservation |
| `HAKUSPACE_TEST_ASSET_REPOS="$PWD" python3 hakuspace/scripts/test_visual_ecosystem.py -v` | 10 passed: 9 headless controller tests + real installation acceptance scenario |
| `bash hakuspace/scripts/assets.sh --dry-run` | New stack and activation/reconciliation described correctly |
| Archive setup with four local source overrides and temporary HOME/XDG directories | Fresh install passed; upstream make palette/verify/install, GTK installer, icon build/validate/install, icon-accent --help all passed |
| Integration rerun through HakuSpace `scripts/assets.sh` | Managed update passed; one installed icon directory; metadata and independent regular executable/module verified |
| Archive test copy renamed to `archive.test-away`; theme commands run | A → B → A and same-A idempotence passed without any archive path at runtime |
| Reinstall Hikaide-Symbols with upstream `--replace`, then `theme_ctl apply` | Mandatory reconciliation passed; build accent returned to canonical #AC7994 |
| Remove installed icon-accent executable from PATH, then set accent | Core state and rendered Quickshell accent changed; warning emitted; restoring executable + apply repaired icons |
| Real wallpaper JPG → real get_accent_color.py → wallpaper_ctl → theme_ctl → real icon-accent | Canonical accent changed and installed editable accents matched |
| Classic Rofi frontend with simulated choices | Real frontend/controller routing passed; no frontend icon code |
| Hikai ThemeAccentPage.qml and facade/IPC audit | Uses the same theme_ctl set-accent; interactive UI acceptance remains manual |
| `cd hikaide-symbols && python3 scripts/build.py && python3 scripts/validate.py` | 1,551 icon names validated |
| `cd hikaide-symbols && PATH=<temporary-installed-bin>:$PATH python3 -m unittest discover -s tests -v` | All 10 passed, including external engine/byte-exact restore (initial run without tool had one skip; rerun resolved it) |
| `cd icon-accent && python3 -m unittest discover -s tests -v` | All 18 passed |
| `cd hakuspace && python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')` | Passed for all QML files |
| `cd hakuspace && bash scripts/precommit_check.sh` | Working-tree run stopped at existing untracked-file guard for three new source/test files; no source/index changes made to bypass it |
| Same precommit script on a temporary copy with all current files in its own Git index | Passed: QML, JS, offscreen Quickshell harnesses, existing Python tests, shell/Python syntax and core boundary guards |
| `bash -n` for archive setup/helpers | Passed; HakuSpace shell checks also covered by precommit |
| `git diff --check` and `git status --short` in changed repositories after each batch | Passed / reviewed |
| systemd `30-systemd-environment-d-generator` with isolated config | Emitted XCURSOR_THEME=Haku-Blue and XCURSOR_SIZE=24 |
| Actual gsettings activation with `GSETTINGS_BACKEND=keyfile` in isolated HOME | Completed without changing the host settings database |
| Native GTK3 probe on the available display | Could not initialize display (`GTK display unavailable`); not a visual acceptance pass |

The integration test runs actual upstream builds/installers, actual renderer and
icon-accent. It mocks application reload and desktop gsettings activation to
avoid touching the current desktop. The focused controller tests verify those
activation calls separately with command doubles. Installed SVG and backup
state bytes remain unchanged for repeated accents. An unmanaged icon theme
update is explicitly refused without changing its artwork.

## Remaining manual acceptance matrix

All cells are **pending**, not inferred from headless checks.

| Session | GTK Hikaide | Fresh icon lookup/accent | Haku cursor | Classic/Hikai accent | Restart persists |
| --- | --- | --- | --- | --- | --- |
| Hyprland | pending | pending | pending (including live setcursor) | pending | pending |
| Niri | pending | pending | pending (next-session environment) | pending | pending |
| MangoWM | pending | pending | pending (next-session environment) | pending | pending |

After deploying the changed core and installing the changed archive:

1. Log into each WM. Run `appearance_ctl.sh verify` and `status`; open a fresh
   GTK app and confirm the theme, icon artwork and cursor visually.
2. Change accent through Classic, then Hikai. After each change compare
   `theme_ctl.sh get accent` with
   `icon-accent --icons-dir ~/.icons status Hikaide-Symbols` (HEX case is
   immaterial). Reopen the GTK app to avoid an old icon cache.
3. Enable wallpaper-derived accent, change wallpaper from the UI and confirm
   the same canonical/installed accent equality.
4. Restart HakuSpace, then log out/in; accent must persist and icons reconcile.
5. For Niri/MangoWM confirm the session imports environment.d before starting
   the compositor; a session launcher that ignores the user environment may
   require its normal environment-import setup. No configs are guessed/rewritten.

Do not kill Thunar/Nautilus to force refresh. No live compositor session was
reconfigured by these tests.

## Known limitations and acceptance status

- **Not fully DONE under the requested Definition of Done** until the three
  interactive WM smoke rows pass. The execution environment exposes session
  variables but native GTK could not connect to that display.
- Production network clones were not fetched; the exact shallow-clone command
  was exercised against a local Git remote. Cached update/refusal paths were
  tested with real Git repositories.
- Shellcheck is not installed. Bash syntax and repository checks passed.
- New files remain unstaged; the working-tree precommit untracked guard will
  pass once they are added to Git. The tested tracked snapshot includes them.
- Custom scripts passing mutation arguments to gen_style must migrate to
  theme_ctl; renderer arguments now return an explanatory error.
- Existing independently installed Haku cursors without the archive marker are
  intentionally refused rather than overwritten; preserve/move them first.
- Upstream GTK updates retain backups. Custom icon artwork changed after an
  icon-accent backup can trigger the engine's checksum refusal after a future
  artwork update; no backup checks or user modifications are silently discarded.
- Cursor builds are static, GTK CSS is independent, and existing apps may cache
  icons. No watcher, recolor daemon, CSS injection or WM workspace refactor added.

## Final git status --short

### hakuspace

```text
 M README.md
 M docs/core/app.md
 M docs/core/theme.md
 M scripts/assets.sh
 M scripts/precommit_check.sh
 M scripts/state.sh
 M scripts/variables.sh
 M src/core/backend/theme/theme_ctl.sh
 M src/core/backend/theme/wallpaper_ctl.sh
 M src/core/lib/haku_theme.sh
 M src/core/sys/session_start.sh
 M src/core/theme/apply_style.sh
 M src/core/theme/gen_style.sh
 M src/core/theme/random_wallpaper.sh
?? docs/task/HAKUSPACE_VISUAL_ECOSYSTEM_INTEGRATION_REPORT.md
?? scripts/test_visual_ecosystem.py
?? src/core/backend/theme/appearance_ctl.sh
?? src/core/lib/haku_appearance.sh
```

### hakuspace-archive

```text
 M README.md
 M setup.sh
?? .gitignore
?? lib/
?? tests/
```

### haku-cursor

```text
(clean)
```

### hikade-gtk-theme

```text
(clean)
```

### hikaide-symbols

```text
(clean)
```

### icon-accent

```text
(clean)
```

# HakuSpace V2 — Internal icon accent engine

## V2.0 baseline (2026-10-16)

This migration builds on the uncommitted V1 integration in this workspace.
Existing user/V1 changes are preserved. The external repository remains intact.

Commands run before editing production code:

- `cd icon-accent && python3 -m unittest discover -s tests -v`:
  **18/18 passed**, saved in `/tmp/haku-v2-baseline-engine.log`.
- `cd hakuspace && python3 scripts/test_visual_ecosystem.py -v`:
  **9 passed, 1 opt-in integration test skipped**, saved in
  `/tmp/haku-v2-baseline-visual.log`.
- `cd hakuspace && bash scripts/precommit_check.sh`: stopped at the existing
  untracked-file guard for three V1 files, before running tests. Output saved
  in `/tmp/haku-v2-baseline-precommit.log`. This predates V2; full checks are
  run on the working tree with a temporary Git index, preserving the user's index.

Scope audited: all appearance_ctl callers (theme_ctl, assets.sh, session_start),
appearance contract/status/verify, archive orchestration/manifest/verification,
legacy installer checksum receipt, visual tests/precommit, README/core docs.
The engine and fixtures must follow flat deployment conventions; tests/fixtures
must not be installed under src/core. Backup location/format must stay unchanged.

## Port provenance and retirement

Source: `icon-accent/icon_accent.py`, commit
`7d55942bf6c7144cd988e0535a13a0ddf53cc678`.
The initial port changes only the module name and help description. All original
18 test bodies and two fixture files are copied without behavioral changes.

No LICENSE file or license declaration exists in the source checkout/commit.
No license has been invented or removed. The external repository is retained,
including its Git history and README, and has not been deleted, archived remotely
or released. A separate retirement/release can preserve this exact repository;
HakuSpace no longer needing it does not imply permission to delete it.

## Implementation

- `src/core/app/icon-accent/haku_icon_accent.py`: original standard-library-only
  engine, renamed, with HakuSpace help text. Source comparison confirms every
  other byte is unchanged. ColorScheme scoping, symbolic/static detection,
  symlink deduplication/refusal, XML validation, locks, atomic writes/modes,
  SHA256 backups, external edit refusal, restore/cache handling and CLI exit
  codes are retained.
- `tests/icon_accent/test_haku_icon_accent.py`, `fixtures/kde.svg` and
  `fixtures/symbolic.svg`: original 18 test bodies/fixtures are unchanged
  (verified by AST/byte comparisons). A 19th test constructs legacy-format
  state independently, restores its original bytes/permissions, then recolors.
- `haku_appearance.sh`: explicit `HAKU_ICON_THEME=system` and
  `HAKU_ICON_ACCENT_MODE=auto|on|off` contract, default Hikaide-Symbols/auto.
- `appearance_ctl.sh`: resolves the internal module in source and flat layouts;
  no external executable checks. `system` skips icon selection and sync; `off`
  skips recoloring; auto recolors only recognized managed Hikaide-Symbols.
  Explicit on mode uses the safe engine only for the configured user-owned
  theme. Other themes remain selectable from user/XDG/system icon locations.
  Configured missing icons warn normally and fail strict sync/verify. Inactive
  or unsupported integrations succeed even in strict mode. Engine safety errors
  are returned by sync-accent and never roll back canonical core state.
- `status` reports icon selection mode, accent mode, and capability state
  (`active`, `disabled`, `not-applicable`, `missing`, `error`); `verify` always
  checks the internal core module, but skips icon installation checks in system
  mode. Missing internal code is a broken deployment, not an optional dependency.
- `theme_ctl.sh` keeps its V1 orchestration unchanged: validate, save canonical
  state, render/apply, then appearance policy. It contains no Python/scanner logic.
- `scripts/precommit_check.sh`: runs internal engine safety tests and visual
  integration checks. `scripts/assets.sh` dry-run advertises three asset sources.
- Archive `setup.sh`, `lib/common.sh`, `lib/verify_assets.sh`: no accent-engine
  source, install step, availability check, or ICON_ACCENT metadata. The V1
  `lib/install_icon_accent.sh` is removed.
- Archive `lib/cleanup_legacy_icon_accent.sh`: installer-only cleanup. Requires
  two regular non-symlink files, a regular non-symlink receipt, successful hashes
  for both files, and a byte-exact receipt comparison including both exact paths.
  Only then are those two files and the receipt removed. Mismatched, forged,
  incomplete, unreadable or unmanaged installations are preserved. No backup
  state or cache checkout is deleted. Successful cleanup is naturally one-time
  because its receipt is removed; mismatches warn on later installer runs only.
- `scripts/test_visual_ecosystem.py`: uses real internal engine for all accent
  policy checks; no external command stubs or sibling-engine imports. Actual
  core deployment is exercised in Copy and Deep Symlink modes. Opt-in real
  installation depends only on this archive and the three visual source repos.
- Both READMEs and current core theme documentation describe the new ownership
  and configuration. The V1 report is explicitly preserved as historical.

Backup state remains exactly:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/icon-accent/<theme-and-path-hash>/
  state.json
  lock
  backup/...
```

No backup migration, engine rewrite, pip dependency, watcher, daemon, WM backend
change or SVG/CSS mutation in shell scripts was introduced.

## Validation commands and results

| Command/check | Result |
| --- | --- |
| Original `icon-accent` unittest suite before migration | 18/18 passed |
| Initial internal port unittest suite, before external integration removal | 18/18 passed |
| `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/icon_accent -v` in HakuSpace | 19/19 passed (18 original + legacy state compatibility) |
| `python3 scripts/test_visual_ecosystem.py -v` | 18 passed, optional full asset-install scenario skipped without its source setting |
| `HAKUSPACE_TEST_ASSET_REPOS=<sibling-workspace> python3 hakuspace/scripts/test_visual_ecosystem.py -v` | All 19 passed, no skips |
| `python3 -m unittest discover -s hakuspace-archive/tests -v` | 9/9 passed |
| `bash scripts/precommit_check.sh` with temporary Git index for current new files | All checks passed on the actual working tree, user index unchanged |
| Shell `bash -n` for archive setup/helpers | Passed |
| `bash hakuspace/scripts/assets.sh --dry-run` | Three-source stack and reconciliation described |
| `git diff --check` in both changed repos | Passed |
| Production search for external repository URL, old source env var, external executable lookup | No matches in either repo's active source/scripts/tests/current docs |
| Engine original-versus-port comparison | Identical apart from help description |
| AST comparison of original test methods and byte comparison of fixtures | All original 18 bodies and both fixtures preserved |

The precommit invocation uses `GIT_INDEX_FILE` pointing at a temporary index,
initialized from HEAD and populated with the current files. The existing guard
therefore sees new files as tracked while all tests read the real working tree.
The normal index is never staged/reset/committed. Plain precommit continues to
require adding these new files to Git, as expected from its existing guard.

Logs during this run: `/tmp/haku-v2-internal-parity.log`,
`/tmp/haku-v2-visual-integration.log`, `/tmp/haku-v2-install-final.log`,
`/tmp/haku-v2-precommit.log`. These are temporary validation artifacts, not runtime
dependencies.

### Required scenarios exercised

1. Real Hikaide-Symbols A → B → A, engine restore, then canonical re-sync.
2. Same accent twice: canonical state, SVG bytes, and backup state unchanged.
3. Archive checkout renamed away: runtime sync remains operational.
4. Upstream `install.sh --replace` resets icons; `theme_ctl apply` repairs accent.
5. Configured Hikaide-Symbols missing: core state changes with warning; verify
   fails; strict mode returns failure without undoing the saved accent.
6. System mode with no Hikaide-Symbols: verify succeeds, gsettings icon-theme is
   untouched, sync succeeds/no-ops even with strict mode enabled.
7. Other compatible theme + auto: selected normally, artwork unchanged.
8. Other compatible user theme + on: recolored by the internal engine.
9. Static theme + on: not-applicable/success under strict mode; bytes unchanged.
10. External edits and corrupted backups: actual sync error; artwork preserved;
    normal theme_ctl still saves/applies core state.
11. Unmanaged Hikaide-Symbols and off mode: no unexpected edits.
12. Missing core engine: explicit broken-deployment error and verify failure.
13. Source-tree resolver and actual Copy/Deep Symlink deployment. In Copy mode
    the temporary HakuSpace source is deleted before accent mutation succeeds.
14. Fresh asset installation writes no engine files or ICON_ACCENT metadata.
    A managed legacy pair/receipt is then seeded and removed on a real installer
    update; canonical icon state is reconciled afterward.
15. Real wallpaper extraction and Classic controller routing retained.
16. Cleanup preserves modified files, symlinks, unmanaged files, unrelated/forged
    receipts, and files after a partial checksum read failure. Safe cleanup and
    rerunning it are idempotent.

All writes occur in temporary HOME/XDG roots. App reload and gsettings calls use
local test doubles; recoloring, backup handling, renderers, deployment and
upstream installers are real. No user's running desktop was recolored or changed.

## Completion and limits

The V2 automated acceptance items pass. The external repository is no longer a
HakuSpace runtime/source/test dependency. It is deliberately retained, rather
than deleted or remotely archived. No release/tag/push was requested or performed.

Interactive GTK/compositor checks from the historical V1 matrix remain manual;
this migration does not claim a new Hyprland/Niri/MangoWM visual smoke pass.
Static/symbolic not-applicable handling retains the original engine's semantics,
including its original safety refusals. Status `active` indicates enabled/scanner
capability, not proof that every application has refreshed its cached icons.
Shellcheck is unavailable; Bash syntax and repository shell checks passed.

## Final git status --short

The statuses below include the existing V1 work as well as this V2 migration.

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
?? docs/task/HAKUSPACE_INTERNAL_ICON_ACCENT_V2_REPORT.md
?? docs/task/HAKUSPACE_VISUAL_ECOSYSTEM_INTEGRATION_REPORT.md
?? scripts/test_visual_ecosystem.py
?? src/core/app/icon-accent/
?? src/core/backend/theme/appearance_ctl.sh
?? src/core/lib/haku_appearance.sh
?? tests/
```

### hakuspace-archive

```text
 M README.md
 M setup.sh
?? .gitignore
?? lib/
?? tests/
```

### icon-accent

```text
(clean)
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

# Haku Cursor contract migration (2026-10-16)

## C0 audit before changes

The repositories now live directly under HOME. Both target repos and the
upstream cursor repo started clean; no AGENTS.md applies. Cursor upstream
commit inspected: `1e8a7e4` (local checkout, not a network refresh).

Assumptions found:

- Archive common defaulted to palette blue; metadata used CURSOR_NAME.
- Archive install guarded only XDG icons/Haku-Palette, then built a palette and
  installed with THEME=palette. Current upstream can install both styles through
  that selector, so an unguarded sibling could have been overwritten.
- Archive verify expected the obsolete XDG cursor destination.
- Runtime defaulted to Haku-Blue; legacy palette mapping already existed, and
  runtime searched XDG before HOME/.icons. Activation already used exact names.
- Visual tests assumed XDG Haku-Blue, including the legacy pink fixture.
- Both READMEs advertised palette-first configuration and the old install root.
- Historical V1/V2 reports retain their original results; they are not current
  configuration instructions. No icon-accent V2 or icon-theme refactor is needed.

Current upstream contract was read from Makefile, scripts/install.sh and tests:
make defaults to dark+light, named dark/light targets build one default style,
colour targets accept STYLE=dark|light|both, ANIM defaults to all, installation
uses HOME/.icons and exact built directory selectors are supported.

## Changes

Archive:

- `lib/common.sh`: explicit theme → deprecated palette fallback → Haku-Dark;
  one resolver maps exact names to upstream target/style. Metadata records
  HAKU_CURSOR_THEME, HAKU_CURSOR_PATH and revision; it is informational only.
- `lib/install_cursor.sh`: guard exactly HOME/.icons/selected-theme, build the
  required target/style, verify, require the exact built directory, install with
  THEME=selected-theme, verify destination and write the existing ownership marker.
  The exact-directory precondition prevents upstream's selector fallback.
- `lib/verify_assets.sh`: verify the same canonical HOME/.icons destination.
- `tests/test_install.py`: defaults/light/colours, legacy mapping/installation,
  explicit precedence, managed update, missing exact build, manifest/verification
  and sibling safety. Both variants are present in dist during sibling tests.
- `README.md`: theme-first examples, HOME/.icons, deprecated palette fallback.

HakuSpace:

- `src/core/lib/haku_appearance.sh`: Haku-Dark default; explicit theme wins over
  legacy palette, whose old dark-variant mapping is preserved without warnings.
- `src/core/backend/theme/appearance_ctl.sh`: cursor discovery checks HOME/.icons
  first. Generic XDG/system discovery remains a compatibility fallback; icon
  theme lookup and icon-accent logic are unchanged.
- `scripts/test_visual_ecosystem.py`: exact default/theme propagation assertions
  through status, verify, gsettings, environment.d and Hyprland, in Copy and
  Deep Symlink modes; optional Blue-Light precedence and legacy mapping tests.
  Real asset integration checks HOME/.icons and cursor manifest metadata.
- `README.md`: Haku-Dark, Haku-Light and optional colour variants documented.

No upstream code, artwork or animation changed. ANIM is not overridden. No WM
configuration rewrite, cursor/accent linkage, installed-theme migration/deletion,
source checkout reset or icon-accent refactor was introduced.

## Validation

| Check | Result |
| --- | --- |
| Upstream `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v` | 4 passed |
| Archive unittest discovery with current local upstream installer | 20 passed |
| Archive `bash -n setup.sh lib/*.sh` plus individual syntax check of each helper | Passed |
| HakuSpace `python3 scripts/test_visual_ecosystem.py -v` | 20 passed, opt-in real install skipped |
| HakuSpace opt-in visual suite against isolated copies of current source repos | All 21 passed, including actual cursor generation/verification/installation and managed update |
| HakuSpace root `python3 -m unittest discover -s tests -v` | Existing layout discovers 0 tests; no V2 test-layout change made |
| Explicit `python3 -m unittest discover -s tests/icon_accent -v` | 19 passed |
| Full QML syntax command from C15 | Passed |
| `bash scripts/precommit_check.sh` on the actual working tree | All checks passed, including the explicit icon-accent suite and visual suite |
| `git diff --check` in both target repos | Passed |
| Regression search for Blue/palette/XDG cursor assumptions | Every remaining hit reviewed: optional variants, deprecated fallback, historical reports, or a negative test rejecting XDG installation |

Archive tests build small fixtures but execute the **unchanged current upstream
install.sh**. They assert the build target/style, unchanged upstream animation
default, exact install selector and destination. Sibling tests retain both built
variants in dist and prove an unmanaged installed sibling stays byte-identical
with its symlink preserved, in both directions. An unmanaged selected target is
refused before building; dirty/divergent source protections remain covered.

The full asset scenario uses the actual generator, verifier and upstream
installer from a local clone of the current haku-cursor checkout. GTK/icon source
checkouts are copied from the existing local cache. Builds and installs occur
only under /tmp with temporary HOME/XDG directories. There is no network fetch,
no write to upstream/user installed assets, and no real desktop activation;
gsettings/app reload/Hyprland are mocked. This proves contract integration, not
new interactive WM visual acceptance.

## Compatibility and final state

- New installs default to HOME/.icons/Haku-Dark, size 24.
- Exact colour-light names propagate unchanged end-to-end.
- All eight legacy palette values retain their dark names for one compatibility
  cycle. Explicit HAKU_CURSOR_THEME takes precedence. No session warnings added.
- Existing XDG cursor installs are left intact and remain discoverable as a
  fallback. New installations always use HOME/.icons.
- Unmanaged selected themes still block installation; preserve/move one manually
  before replacing it. Sibling themes are never deleted or adopted.
- No files were staged or committed. Upstream haku-cursor remains clean.
- Interactive compositor rendering was not re-tested; the existing Niri/Mango
  next-session environment requirement is unchanged.

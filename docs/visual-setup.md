# Visual installation and development

HakuSpace installs Haku Cursor, Hikaide GTK and Hikaide-Symbols through
`scripts/setup.sh`. Normal users retain only installed assets: source repositories
are shallow-cloned at their latest default branch into private temporary staging,
built, validated and installed, then removed. Success, clone/build/install/verify
failure and trapped INT/TERM all clean that staging. No source checkout or source
cache is kept under HOME.

```bash
./scripts/setup.sh setup
./scripts/setup.sh status
./scripts/setup.sh verify
```

Staging uses a writable user-owned `$XDG_RUNTIME_DIR` when available, otherwise
`${TMPDIR:-/tmp}`. Cleanup only removes directories created by this invocation;
existing local repositories are not adopted or deleted. GTK, icons and cursor
files already installed under `~/.themes` and `~/.icons` remain available after
source cleanup. `hakuspace-archive` and `scripts/assets.sh` supply wallpapers only.

`update.sh` checks installed visual files after deploying dotfiles and skips complete
installations, including after a reboot. It asks before installing or repairing a
missing component and preserves configured development source overrides. GTK and
icon installations require both dark and light variants. These checks use installed
files rather than the deleted temporary sources or ownership metadata alone.
`./scripts/setup.sh verify <component>` performs this read-only component check.
To refresh installed assets explicitly, run `./scripts/setup.sh update [component]`;
this fetches current disposable sources even when assets are already installed.
There is no retained Git history or installed-revision manifest to compare.
`./scripts/setup.sh apply <component>` installs one component, using temporary
sources when no development source was configured.

## Installation, selection and activation

Installed assets and selected themes are separate states. Installing GTK/icons does
not silently replace Adwaita or a third-party choice. Setup asks separately whether
to activate `Hikaide` and `Hikaide-Symbols` for the current mode. Declining, including
noninteractive EOF, preserves that component's selected theme and native settings.
Later updates also require confirmation before replacing an external theme.

An already selected managed family follows the existing mode policy: Classic uses
the dark variants; Hikai follows its saved Light/Dark preference. Activation never
changes the shell backend or the saved Hikai preference. Unrelated GTK keys/comments
and custom CSS are preserved; no global GTK4 CSS override is created.

For assets already installed, these explicit commands activate without downloading:

```bash
./src/core/backend/theme/appearance_ctl.sh activate gtk
./src/core/backend/theme/appearance_ctl.sh activate symbols
```

`setup.sh status` reports component `installed=yes|no`, `gtk_theme_selected`,
`icon_theme_selected`, and `activation_pending` separately. Selection is read from
GSettings, with native GTK settings as the fallback when GSettings is unavailable.
A successful activation requires both settings application and readback of the
requested selection. Failures retain the installed assets and pending activation
intent; they do not report the batch as successfully applied.

The result distinguishes **installed**, **selected**, **applied**, and **session
pending**. Successful reconciliation prints the selected GTK/icon names and notes
that already running applications/session may cache styles and cursors. Reboot is
not the success criterion: settings synchronization and selection readback happen
before that message.

## Local development sources

Developers may provide their own source directories at independent absolute paths:

| Component | Source variable |
| --- | --- |
| `cursor` | `HAKU_CURSOR_SOURCE` |
| `gtk` | `HAKU_GTK_THEME_SOURCE` |
| `symbols` | `HAKU_ICON_THEME_SOURCE` |

```bash
HAKU_CURSOR_SOURCE="$HOME/src/haku-cursor" \
HAKU_GTK_THEME_SOURCE="/mnt/themes/hikade-gtk-theme" \
HAKU_ICON_THEME_SOURCE="$HOME/repos/hikaide-symbols" ./scripts/setup.sh setup

./scripts/setup.sh path symbols
./scripts/setup.sh apply cursor
./scripts/setup.sh apply gtk
./scripts/setup.sh apply symbols
./scripts/setup.sh apply all
```

Explicit and remembered development sources are used in place and **never deleted,
pulled, reset, stashed or switched to another branch** by HakuSpace. `setup` and
`apply` build their current contents, including dirty changes; non-Git source
directories are allowed. Explicit `setup.sh update` skips these overrides; developers
manage their own Git updates and run `apply` when ready. Each upstream retains
its own build/validation/install commands and managed destination guards.

Environment paths take precedence over remembered source intent. Successful
setup/apply remembers only explicit paths under
`~/.local/state/hakuspace/state/[system].visual-sources.json`, keyed by `cursor`,
`gtk` and `symbols`. Temporary source paths are never saved. Remove a remembered
key to return that component to disposable downloads. `status`, `path` and
`workspace` do not write that state. Without a retained development source, `path`
reports that none is configured. Legacy `appearance.env` is never executed.

Git metadata and installed assets are inspected live. No `assets/installed.env`
or other visual installation manifest is read or written. Installed assets are
marked for reconciliation through `[system].visual-reconcile.pending`, which also
retains explicitly confirmed GTK/icon activation intent. Successful source-core
appearance reconciliation clears it. If activation failed, a subsequent
`update` retries activation and returns without downloading/rebuilding sources;
`verify` also retries pending activation. The dotfile updater performs this
recovery once before considering component downloads and skips new downloads in
that recovery pass. Run `scripts/setup.sh update` again to explicitly fetch
new sources afterward. Light/Dark/Classic selection, XDG discovery and stateless
icon accents remain independent of the disposable source lifetime.

## VS Code multi-root workspace

Workspace generation is a development tool, not part of normal installation.
Configure retained Git source paths first, then run:

```bash
./scripts/setup.sh workspace
./scripts/setup.sh workspace /custom/path/HakuSpace.code-workspace
```

The default output is `~/HakuSpace.code-workspace`. It uses the four actual Git
root paths and prints a `code <workspace-file>` command without executing it.
Missing development sources are reported without downloading anything. Existing
workspace settings and extra folders are preserved; differing or invalid files
must be edited manually or moved aside before regeneration.

The workspace groups independent projects for editing and search without coupling
their Git or update lifecycles. `install.sh` offers optional visual installation
and wallpapers as separate steps and does not generate a development workspace.

Former `hakuspace/ecosystem/<repo>` directories are only detected and warned about;
they are never moved, reused or deleted automatically. Review/back up local work
before handling old repositories manually.

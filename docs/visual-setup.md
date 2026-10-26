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

`update.sh` updates HakuSpace dotfiles without invoking visual installation or
pulling/building/copying visual projects. A separate explicit
`./scripts/setup.sh update` fetches and installs current disposable sources again;
there is no retained Git history or installed-revision manifest to compare.
`./scripts/setup.sh apply <component>` installs just that component, using temporary
sources when no development source was configured.

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
marked for activation through `[system].visual-reconcile.pending`; successful
source-core appearance reconciliation clears it. If activation failed, a subsequent
`update` retries activation and returns without downloading/rebuilding sources;
`verify` also retries pending activation. Run `update` again to explicitly fetch
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

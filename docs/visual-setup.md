# Visual source setup and VS Code workspace

HakuSpace orchestrates Haku Cursor, Hikaide GTK and Hikaide-Symbols through
`scripts/setup.sh`. Each source remains an independent repository at its own
absolute path. No common parent, nested workspace, submodule or repository move
is required. `hakuspace-archive` and `scripts/assets.sh` supply wallpapers only.

| Component | Explicit source | Fallback clone destination |
| --- | --- | --- |
| `cursor` | `HAKU_CURSOR_SOURCE` | `~/haku-cursor` |
| `gtk` | `HAKU_GTK_THEME_SOURCE` | `~/hikade-gtk-theme` |
| `symbols` | `HAKU_ICON_THEME_SOURCE` | `~/hikaide-symbols` |

Environment paths take precedence over remembered source intent, then fallbacks.
Paths are normalized to absolute paths independently; HakuSpace never searches
other directories to discover or relocate existing clones.

```bash
HAKU_CURSOR_SOURCE="$HOME/src/haku-cursor" \
HAKU_GTK_THEME_SOURCE="/mnt/themes/hikade-gtk-theme" \
HAKU_ICON_THEME_SOURCE="$HOME/repos/hikaide-symbols" ./scripts/setup.sh setup

./scripts/setup.sh status
./scripts/setup.sh path symbols
./scripts/setup.sh update
./scripts/setup.sh apply cursor
./scripts/setup.sh apply gtk
./scripts/setup.sh apply symbols
./scripts/setup.sh apply all
./scripts/setup.sh verify
```

`setup` full-clones missing fallback sources and fast-forwards clean managed
checkouts with `git pull --ff-only`, then installs current sources. A dirty
managed source is installed only with a warning during this explicit full setup;
it is never pulled. `update` builds only newly cloned or changed managed sources.
Unchanged sources skip builds and installed outputs are verified live. If a build
fails after a successful pull, fix it and explicitly run `apply <component>`;
installed revisions are not cached to infer another automatic build.

Dirty repositories and explicit/remembered source overrides skip both automatic
pull and installation. `apply` builds current local contents, including dirty
changes, without pulling. Non-Git source directories are allowed for explicit
setup/apply. Detached HEAD or missing upstreams are reported and skipped; divergent
pulls, wrong origins and unsafe managed destinations fail without repair. Other
components are still checked. No automatic reset, stash, branch switch or source
deletion occurs. Each upstream retains its own build/validation/install logic and
managed installation guards.

Only explicit source intent is remembered, after successful setup/apply, under
`~/.local/state/hakuspace/state/[system].visual-sources.json`, keyed by `cursor`,
`gtk` and `symbols`. Remembered paths retain override safety. Removing a key
returns that component to its fallback. Environment overrides always win.
`status`, `path` and `workspace` never change that state. The legacy
`~/.config/hakuspace/appearance.env` is never executed.

Git revision, dirty status, origin and installed asset presence are derived live.
No `assets/installed.env` or other visual installation manifest is read or written;
pre-existing legacy files are left unused. Successful installation marks the
central recovery flag `[system].visual-reconcile.pending`. Appearance reconciliation
uses current source core once per batch; success removes the flag. A later
`setup`, `update` or `verify` retries pending activation. An unchanged `update`
or `verify` retries without rebuilding repositories. Light/Dark/Classic selection,
XDG Symbols discovery and stateless icon accent behavior are unchanged.

`install.sh` offers visual setup and wallpapers separately, with optional workspace
generation. `update.sh` first updates/re-executes HakuSpace, then checks visual
sources before package/config deployment. Visual failures do not block that other
work; the final summary and exit status report the incomplete visual update.
HakuSpace Stable/Latest selection does not pin visual upstream revisions.

## VS Code multi-root workspace

```bash
./scripts/setup.sh workspace
./scripts/setup.sh workspace /custom/path/HakuSpace.code-workspace
```

The default output is `~/HakuSpace.code-workspace`. HakuSpace verifies all four
repositories and uses their actual absolute paths, including independently located
sources and explicit overrides. The command prints `code <workspace-file>` but
never calls VS Code or requires it to be installed.

Existing workspace files are validated without rewriting settings or additional
folders. If required folders are missing, JSON cannot be parsed, or the destination
is a symlink, the file is preserved and the command reports how to resolve it.
Add the required roots manually, or move the custom file aside and rerun. Workspace
generation failure does not fail the full installer.

## Former nested clones

Existing `hakuspace/ecosystem/<repo>` directories are detected and warned about.
They are never adopted, moved or deleted automatically. The old manager, nested
README and parent ignore entries are retired, so those local directories may now
appear as untracked entries in parent Git. Review/back up any development work
before handling them manually; do not add them as embedded repositories.

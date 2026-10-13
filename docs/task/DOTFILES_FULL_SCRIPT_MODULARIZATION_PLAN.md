# HakuSpace Full Dotfiles Script Modularization Plan

## 0. Objective

Refactor the dotfiles management tooling so that:

1. `install.sh` and `update.sh` become thin orchestration scripts.
2. Every real operation currently performed directly inside them is moved into an executable module under `scripts/`.
3. `scripts/functions.sh` contains only genuinely small generic helpers.
4. Large/domain-specific functions currently in `functions.sh` become dedicated scripts or focused libraries.
5. Every useful operation can be executed manually without running the full installer.
6. Automatic `install.sh` / `update.sh` compose the exact same modules used manually.
7. Existing Deep Symlink semantics are preserved.
8. Legacy Copy deployment behavior is preserved, not redesigned.
9. Configuration mappings are defined once and reused by link, unlink, doctor, install, update, and rollback.

The target principle is:

```text
install.sh / update.sh
        │
        │ orchestration only
        ▼
 scripts/*.sh modules
        │
        ├── shared registry
        ├── shared runtime context
        └── small generic libraries
```

---

# 1. Current problems confirmed from repository

Current approximate sizes:

```text
install.sh               ~456 lines
update.sh                ~285 lines
scripts/functions.sh     ~626 lines
doctor.sh                ~169 lines
rollback.sh              ~255 lines
```

`functions.sh` currently mixes unrelated responsibilities:

```text
logging / UI
filesystem helpers
backup
copy deployment
deep symlink deployment
deploy mode detection
generic deploy dispatcher
src/core deployment
package installation
WM selection
deploy-mode selection
archive repository handling
hakucfg bootstrap/versioning
local state bootstrap
```

This makes `functions.sh` effectively another application rather than a helper library.

There is also duplicated config deployment logic in:

```text
install.sh
update.sh
doctor.sh
rollback.sh
determine_deploy_mode()
```

This must be replaced by one source of truth.

---

# 2. Target repository structure

Keep convenient user-facing commands at repository root:

```text
install.sh
update.sh
link.sh
unlink.sh
packages.sh
doctor.sh
rollback.sh
```

All implementation for the new architecture lives under `scripts/`.

Recommended structure:

```text
scripts/
├── variables.sh
├── functions.sh
├── runtime.sh
├── filesystem.sh
├── registry.sh
│
├── select_wm.sh
├── deploy_mode.sh
├── dependencies.sh
├── packages.sh
├── directories.sh
├── repo_update.sh
│
├── link.sh
├── unlink.sh
├── once_configs.sh
├── legacy_copy.sh
├── core.sh
│
├── nixos.sh
├── assets.sh
├── state.sh
├── hakucfg.sh
├── shell_setup.sh
├── display_manager.sh
├── desktop_defaults.sh
├── reload.sh
│
└── doctor.sh
```

Do not create tiny scripts just for the sake of file count.

A module should represent one coherent domain or lifecycle responsibility.

---

# 3. Root scripts become entrypoints only

## `install.sh`

Target responsibility:

```text
initialize runtime
choose WM
choose deploy mode
call install-profile modules
print final result
```

It must NOT directly:

```text
run yay
run cp
run ln
loop through configs
loop through package files
modify NixOS files
clone asset repositories
initialize hakucfg
initialize HakuSpace state
call chsh
call systemctl
call gsettings
call xdg-mime
```

Target size should ideally be roughly 50–100 lines.

## `update.sh`

Target responsibility:

```text
initialize runtime
run repository update module
re-exec if updater changed
select WM
detect deploy mode
call update-profile modules
print final result
```

It must contain no deployment implementation.

Target size should also be roughly 50–100 lines.

## Root convenience commands

Keep:

```bash
./link.sh niri
./unlink.sh niri
./packages.sh niri
./doctor.sh
```

but these root files should be tiny wrappers:

```text
resolve HAKU_DIR
exec scripts/<command>.sh "$@"
```

This preserves the simple CLI while keeping all implementation in `scripts/`.

---

# 4. Runtime context must be solved before module extraction

This is mandatory before splitting the scripts.

Currently `variables.sh` creates:

```text
BACKUP_TS
BACKUP_DIR
```

when sourced.

That is unsafe after modularization because each subprocess could receive a different timestamp.

Introduce:

```text
scripts/runtime.sh
```

The top-level command creates one run context:

```text
HAKUSPACE_RUN_ID
BACKUP_DIR
HAKUSPACE_DEPLOY_MODE
selected WM list where applicable
```

Then exports it for child modules.

Conceptually:

```text
install.sh
  creates Backup_2026-...
  exports BACKUP_DIR
       ↓
dependencies.sh
link.sh
core.sh
state.sh
...
all see the SAME backup directory
```

Standalone commands such as:

```bash
./link.sh niri
```

may create their own runtime context if none was inherited.

Acceptance:

```text
one top-level install/update invocation
=
one shared backup directory
```

---

# 5. `variables.sh` becomes static configuration only

`variables.sh` should contain stable paths/constants such as:

```text
SOURCE_DIR
HOME_SRC_DIR
SOURCE_CONFIG
SOURCE_CORE
DEST_CONFIG
DEST_BIN
NIX_DIR
package-list paths
archive URL
hakucfg source/destination
```

Move out:

```text
runtime timestamp generation
WM selection state
deployment policy arrays where appropriate
complex mappings
```

Those belong in runtime/registry modules.

---

# 6. `functions.sh` must become genuinely small

After refactor, `functions.sh` should contain only generic presentation/control helpers.

Recommended remaining functions:

```text
shorten_path
log_info
log_ok
log_warn
log_error
log_backup
log_copy
log_skip
log_symlink

print_divider
step_title
print_header

ask_yes_no
die
run_module   # optional generic orchestrator helper
```

Possibly `require_command()` if genuinely generic.

It should NOT know anything about:

```text
Hyprland
Niri
Mango
Labwc
hakucfg
src/core
yay package groups
Deep Symlink mappings
ONCE_CONFIGS
NixOS
archive repository
state files
deployment mode heuristics
```

A good final target is roughly 80–150 lines rather than 626 lines.

Do not enforce an arbitrary line count at the expense of clarity.

---

# 7. Move filesystem primitives into `filesystem.sh`

The following are useful shared primitives but do not belong in `functions.sh`:

```text
ensure_dir
backup_item
backup_dir
copy_file
copy_dir_content
```

Move them into:

```text
scripts/filesystem.sh
```

This is a sourced utility library, not a user-facing workflow.

It must remain policy-neutral.

It should not know which configs HakuSpace manages.

---

# 8. Central registry: `registry.sh`

This becomes the single source of truth for managed targets.

It must describe:

```text
normal configs
special configs
WM-specific configs
ONCE_CONFIGS
core scripts
home dotfiles
special destination mappings
module aliases
package-group mappings if useful
```

Preserve auto-discovery where sensible.

Do not manually enumerate every normal `.config` directory when the repository can safely discover them.

Explicit mappings are still required for special cases.

Current special behavior includes:

```text
hypr/
niri/
mango/
labwc/
gtk-3.0/gtk.css
.nanorc
.zshrc
src/core -> ~/.local/bin
```

Hypr requires special handling because:

```text
hypr/config
hypr/hyprland.lua
```

are WM-specific while:

```text
hypridle.conf
hyprlock.conf
hyprlock_tiny.conf
```

are deployed independently today.

The registry must represent that distinction.

---

# 9. Registry must replace duplicated path knowledge

The following scripts must use the registry rather than their own config lists:

```text
scripts/link.sh
scripts/unlink.sh
scripts/doctor.sh
install.sh/update orchestration
deploy-mode detection
rollback.sh managed destination discovery
```

This also fixes the current architectural problem where rollback maintains another manually synchronized destination list.

Do not rewrite rollback logic yet.

Only replace its managed-path discovery with registry queries after the registry is stable.

---

# 10. `select_wm.sh`

Move the current large `select_window_manager()` function out of `functions.sh`.

Implement:

```text
scripts/select_wm.sh
```

It owns:

```text
interactive WM menu
WM validation
ALL selection
canonical WM names
```

Supported canonical values:

```text
hyprland
niri
mango
labwc
```

The script should have a machine-readable mode so `install.sh` and `update.sh` can consume its result safely.

For example:

```bash
scripts/select_wm.sh --interactive
scripts/select_wm.sh --validate niri
```

Do not encode package file paths directly in the selector.

WM → package/config mapping belongs in the registry.

---

# 11. `deploy_mode.sh`

Move BOTH current responsibilities out of `functions.sh`:

```text
select_deploy_mode()
determine_deploy_mode()
```

into:

```text
scripts/deploy_mode.sh
```

Supported operations:

```bash
scripts/deploy_mode.sh select
scripts/deploy_mode.sh detect
```

`select`:

```text
used during first install
returns symlink or copy
```

`detect`:

```text
used during update/doctor
inspects registered managed targets
returns symlink or copy
handles mixed state
```

The current 130+ line `determine_deploy_mode()` should disappear from `functions.sh`.

The new detector must use `registry.sh`.

---

# 12. `dependencies.sh`

Move current Install Block 1 to:

```text
scripts/dependencies.sh
```

Responsibilities:

```text
detect Arch/pacman
check yay
optionally bootstrap yay
check git
check curl
report unsupported distro path
```

Do not mix package-list installation into this module.

Dependencies are installer prerequisites.

Package groups belong in `packages.sh`.

---

# 13. `packages.sh`

Move all package-list behavior from install/update/functions into:

```text
scripts/packages.sh
```

Use existing files:

```text
pkg-core.txt
pkg-service.txt
pkg-optional.txt
pkg-hyprland.txt
pkg-niri.txt
pkg-mango.txt
pkg-labwc.txt
```

Manual API:

```bash
./packages.sh core
./packages.sh service
./packages.sh optional
./packages.sh niri
./packages.sh hyprland
./packages.sh mango
./packages.sh labwc
./packages.sh --all
./packages.sh --list
```

Allow multiple groups if convenient:

```bash
./packages.sh core service niri
```

Package names must never be duplicated in shell source.

Keep current:

```text
yay -S --needed --noconfirm
```

semantics for this refactor.

## Automatic profiles

Installer profile:

```text
selected WM package groups
core
service
optional
```

Updater profile:

```text
selected WM package groups
core
service
```

This preserves current install/update package policy.

The difference between install and update belongs in orchestration/profile resolution, not duplicated package code.

---

# 14. `directories.sh`

Move Install Block 3 directory creation into:

```text
scripts/directories.sh
```

Manage the existing expected directories:

```text
~/.config
~/.icons
~/.themes
~/Pictures/Wallpapers
~/Pictures/Screenshots
```

Also include any truly required parent directories currently created implicitly by later modules if doing so reduces assumptions.

The module must be idempotent.

---

# 15. `link.sh`

This is the new Symlink-mode primitive.

Implementation lives at:

```text
scripts/link.sh
```

Root `link.sh` is a wrapper.

Support:

```bash
./link.sh <module>
./link.sh <module1> <module2>
./link.sh --all
./link.sh --list
```

It always means Deep Symlink deployment.

It must NOT:

```text
ask for deploy mode
run Copy deployment
install packages
seed hakucfg
seed state
copy ONCE_CONFIGS
```

Preserve Deep Symlinking:

```text
destination directories remain real directories
tracked files become symlinks
runtime/app-generated files remain local
```

`--all` means:

```text
all targets registered as symlink-managed
```

including special registered targets.

Explicitly exclude:

```text
ONCE_CONFIGS
hakucfg
state
legacy copy-only data
```

---

# 16. `unlink.sh`

Implementation lives in:

```text
scripts/unlink.sh
```

Root wrapper remains convenient.

Supported:

```bash
./unlink.sh <module>
./unlink.sh --all
./unlink.sh --list
```

It removes only symlinks that can be proven to belong to the selected registered module.

Never recursively delete a config directory.

Never remove:

```text
real user files
foreign symlinks
app-generated files
ONCE_CONFIGS
hakucfg
state
```

Empty directories may be pruned with `rmdir`.

Must be idempotent.

---

# 17. Symlink primitive extraction

Current:

```text
deploy_symlink_recursive()
```

should no longer live in `functions.sh`.

Its behavior becomes private implementation of `scripts/link.sh` or a small source-only helper dedicated to the link module.

Do not expose a generic:

```text
deploy_config_item()
```

that silently switches between Copy and Symlink.

That abstraction currently hides too much policy.

New architecture should make mode explicit.

---

# 18. Legacy Copy deployment

Copy mode is intentionally old and should NOT be redesigned.

However its code must still leave `install.sh` / `update.sh`.

Create:

```text
scripts/legacy_copy.sh
```

Move the existing Copy deployment behavior into this module with minimal semantic changes.

Treat this as:

```text
MOVE / ISOLATE
not
REWRITE / MODERNIZE
```

It may reuse filesystem backup/copy primitives.

Do not attempt to make Copy mode symmetric with `link.sh`.

Do not add `unlink` semantics for Copy mode.

---

# 19. `once_configs.sh`

Extract the Install-only ONCE_CONFIG behavior.

Current ONCE_CONFIGS include:

```text
Thunar
xfce4
mpv
btop
cava
mimeapps.list
```

Module:

```text
scripts/once_configs.sh
```

Responsibilities:

```text
initial copy only
preserve existing semantics
never symlink
never update automatically
```

Used by `install.sh`.

Not used by normal `update.sh`.

---

# 20. `core.sh`

Move current:

```text
deploy_hakuspace_scripts()
```

into:

```text
scripts/core.sh
```

Responsibilities:

```text
deploy src/core flatly to ~/.local/bin
skip README.md
make shell/python scripts executable
detect duplicate basenames
support explicit symlink/copy mode
```

Manual usage may support:

```bash
scripts/core.sh --mode symlink
scripts/core.sh --mode copy
```

`./link.sh core` may internally delegate to:

```text
core.sh --mode symlink
```

if `core` is registered as a manual link module.

Do not duplicate the flat-basename algorithm.

---

# 21. `repo_update.sh`

Move Update Block 0 Git logic into:

```text
scripts/repo_update.sh
```

Own:

```text
LATEST / main
STABLE / latest tag
SKIP
git fetch/pull/checkout
```

Preserve current updater self-reexecution behavior.

Recommended contract:

```text
repo_update.sh performs repository update
returns a documented special status if update.sh itself changed
update.sh then execs itself
```

The parent orchestrator should contain only the few lines required to react to that signal.

Do not duplicate Git update logic in `update.sh`.

---

# 22. `nixos.sh`

Move all NixOS behavior from both install and update into:

```text
scripts/nixos.sh
```

Use subcommands rather than multiple NixOS scripts:

```bash
scripts/nixos.sh install
scripts/nixos.sh update
scripts/nixos.sh rebuild
scripts/nixos.sh status
```

Preserve current modes:

```text
offline hakuspace-config.nix
online flake template
skip
```

Preserve current update detection:

```text
Hakuspace Flake
local hakuspace-config.nix
no recognized configuration
```

Do not redesign NixOS support during this refactor.

Move the current long inline `sed`/copy/rebuild logic here.

---

# 23. `assets.sh`

Move:

```text
deploy_assets_from_archive_repo()
```

out of `functions.sh`.

Create:

```text
scripts/assets.sh
```

Responsibilities:

```text
clone hakuspace-archive
pull existing repo
handle invalid existing directory
run archive setup.sh
```

Install profile calls it.

Current update flow does not update archive assets, so do not silently add that behavior unless intentionally decided later.

---

# 24. `state.sh`

Move:

```text
check_state_dir()
```

and related state initialization from install/update into:

```text
scripts/state.sh
```

Responsibilities:

```text
seed required ~/.local/state/hakuspace files if missing
initialize style state if missing
initialize opaque theme state if missing
```

This combines operations belonging to the same HakuSpace runtime-state domain.

Supported concepts:

```bash
scripts/state.sh init
scripts/state.sh check
```

`check` must be read-only.

`init` may create missing state.

Doctor uses `check`, never `init`.

---

# 25. `hakucfg.sh`

Move:

```text
check_control_dir()
```

from `functions.sh` into:

```text
scripts/hakucfg.sh
```

Responsibilities:

```text
seed required ~/hakucfg templates if missing
create required subdirectories
set required executable bits
check setting.sh version
offer/update setting.sh according to current behavior
```

Also centralize the current hardcoded `required_files` list here or in the shared registry.

Do not keep this list hidden inside a generic helper function.

Suggested interface:

```bash
scripts/hakucfg.sh sync
scripts/hakucfg.sh check
```

`check` is strictly read-only.

---

# 26. `shell_setup.sh`

Move the default Fish setup out of `install.sh`.

Responsibilities:

```text
detect fish
ensure Fish appears in /etc/shells
change user's default shell when required
```

This is install-only behavior.

Do not mix it with shell dotfile deployment.

---

# 27. `display_manager.sh`

Move current LY logic out of Install Block 7.

Responsibilities:

```text
detect ly
ask/select tty when required
enable ly@ttyN
disable getty@ttyN
```

Keep current safety warning.

Do not place generic systemd service management in `functions.sh`.

---

# 28. `desktop_defaults.sh`

Move current small desktop preference operations into one coherent module:

```text
GNOME color-scheme prefer-dark
Thunar default for inode/directory
```

This is preferable to two 5-line scripts.

Run during installation.

Do not add new desktop defaults during this refactor.

---

# 29. `reload.sh`

Move updater runtime reload behavior into:

```text
scripts/reload.sh
```

Initially support:

```bash
scripts/reload.sh waybar
```

using existing:

```text
~/.local/bin/waybar_manager.sh --reload
```

Future reload targets can be added later.

Do not turn this into a generic process manager now.

---

# 30. `doctor.sh` becomes a module too

Move actual Doctor implementation to:

```text
scripts/doctor.sh
```

Root:

```text
doctor.sh
```

becomes a wrapper.

Doctor must become completely read-only.

Remove the current behavior where Doctor ends by calling mutating:

```text
check_state_dir
check_control_dir
```

Instead call:

```text
state.sh check
hakucfg.sh check
```

or equivalent read-only inspection.

Doctor should use the registry for managed configs.

Detect:

```text
healthy managed link
missing link
broken link
foreign link
real file replacing expected link
missing source
partial module
not-installed optional module
state issues
hakucfg issues
```

A manually omitted module is not necessarily an error.

A partially installed/broken managed module is an error.

Doctor remediation should point to the narrow command:

```text
./link.sh quickshell
./link.sh core
./packages.sh niri
```

instead of always saying:

```text
./update.sh
```

---

# 31. Rollback integration

Do NOT rewrite rollback's restore engine in this project.

It is safety-critical.

However current:

```text
build_managed_destinations()
```

duplicates knowledge already found elsewhere.

After registry/link/doctor have stabilized, migrate ONLY destination discovery to the shared registry.

Keep unchanged as much as possible:

```text
backup selection
clear logic
restore algorithm
rollback backup creation
```

This prevents future path drift without expanding the refactor blast radius.

---

# 32. Automatic install profile

The full installer should stop asking whether to execute every normal block individually.

After the user selects core choices such as WM and deployment mode, the standard install profile runs its modules in order.

Recommended flow:

```text
install.sh
 │
 ├─ runtime.sh
 ├─ select_wm.sh
 ├─ deploy_mode.sh select
 │
 ├─ dependencies.sh
 ├─ packages.sh        [install profile]
 ├─ directories.sh
 ├─ nixos.sh install   [only when relevant]
 │
 ├─ once_configs.sh
 │
 ├─ symlink mode:
 │    ├─ link.sh resolved-common-modules
 │    ├─ link.sh selected-WM-modules
 │    └─ core.sh --mode symlink
 │
 ├─ copy mode:
 │    └─ legacy_copy.sh install ...
 │
 ├─ assets.sh
 ├─ state.sh init
 ├─ hakucfg.sh sync
 ├─ shell_setup.sh
 ├─ nixos.sh rebuild   [when relevant/current policy]
 ├─ display_manager.sh
 ├─ desktop_defaults.sh
 │
 └─ doctor.sh selected-profile
```

Interactive prompts may remain where they represent genuine user/system choices:

```text
WM
deploy mode
NixOS mode
TTY/display manager decisions
potentially destructive overwrite decisions
```

Routine module execution should not require a separate Yes/No prompt for every step.

Provide skip flags later if useful:

```text
--skip-packages
--skip-assets
...
```

but do not make advanced CLI design a blocker for the first refactor.

---

# 33. Automatic update profile

Recommended flow:

```text
update.sh
 │
 ├─ runtime.sh
 ├─ repo_update.sh
 ├─ re-exec if updater changed
 │
 ├─ select_wm.sh
 ├─ deploy_mode.sh detect
 │
 ├─ packages.sh        [update profile]
 │
 ├─ symlink mode:
 │    ├─ link.sh resolved-common-modules
 │    ├─ link.sh selected-WM-modules
 │    └─ core.sh --mode symlink
 │
 ├─ copy mode:
 │    └─ legacy_copy.sh update ...
 │
 ├─ nixos.sh update
 ├─ state.sh init
 ├─ hakucfg.sh sync
 ├─ reload.sh waybar
 │
 └─ doctor.sh selected-profile
```

Do not run `once_configs.sh` during update.

Do not introduce install-only behavior into update merely because a module exists.

---

# 34. Lifecycle classification

Every module should have a clear lifecycle instead of being called arbitrarily.

| Module | Install | Update | Manual |
|---|---:|---:|---:|
| dependencies | yes | no/diagnostic only | yes |
| packages | yes | yes | yes |
| directories | yes | as needed | yes |
| repo_update | no | yes | yes |
| link | yes in symlink mode | yes | yes |
| unlink | no | no | yes |
| legacy_copy | yes in copy mode | yes | internal/legacy |
| once_configs | yes | no | optional |
| core | yes | yes | yes |
| nixos | yes | yes | yes |
| assets | yes | no currently | yes |
| state | yes | yes | yes |
| hakucfg | yes | yes | yes |
| shell_setup | yes | no | yes |
| display_manager | yes | no | yes |
| desktop_defaults | yes | no | yes |
| reload | no | yes | yes |
| doctor | yes | yes | yes |

This table becomes the source for orchestration design.

---

# 35. No hidden cross-module mutations

Modules must receive their inputs explicitly through:

```text
CLI arguments
exported runtime context
shared read-only registry/constants
```

Avoid architecture where Module A sources Module B and unexpectedly executes it.

Operational modules should normally be invoked as commands:

```bash
"$HAKU_DIR/scripts/packages.sh" ...
```

Shared libraries may be sourced:

```text
variables.sh
functions.sh
filesystem.sh
registry.sh
runtime.sh
```

This distinction must remain clear.

---

# 36. Exit-code contract

All modules need predictable exit semantics.

Default:

```text
0 = success / nothing needed
non-zero = actual failure
```

Do not consider:

```text
already linked
already initialized
nothing to reload
optional component absent
```

fatal errors.

If `repo_update.sh` requires a special status to request re-exec, document that status explicitly and handle it only in `update.sh`.

---

# 37. Idempotency contract

The following must be safe:

```bash
./link.sh niri
./link.sh niri

./link.sh --all
./link.sh --all

scripts/state.sh init
scripts/state.sh init

scripts/hakucfg.sh sync
scripts/hakucfg.sh sync

scripts/directories.sh
scripts/directories.sh
```

Repeated full:

```bash
./install.sh
```

should not blindly destroy existing files, although installer prompts/policies may still apply.

---

# 38. Batch implementation plan

Do NOT ask Gemini to refactor everything in one pass.

## Batch A — foundations only

Create/refactor:

```text
scripts/runtime.sh
scripts/filesystem.sh
scripts/registry.sh
scripts/functions.sh
scripts/variables.sh
```

Move no high-level behavior yet unless necessary.

Goals:

```text
shared run context
shared registry
functions.sh slim foundation
no user-visible behavior change
```

Run full baseline afterward.

---

## Batch B — selection and deploy primitives

Create:

```text
scripts/select_wm.sh
scripts/deploy_mode.sh
scripts/link.sh
scripts/unlink.sh
scripts/core.sh
scripts/legacy_copy.sh
scripts/once_configs.sh
```

Add root wrappers:

```text
link.sh
unlink.sh
```

Do NOT change install/update orchestration yet.

Test all modules standalone using temporary HOME.

---

## Batch C — packages/system modules

Create:

```text
scripts/dependencies.sh
scripts/packages.sh
scripts/directories.sh
scripts/assets.sh
scripts/nixos.sh
```

Add root:

```text
packages.sh
```

Still avoid install/update cutover until these work independently.

---

## Batch D — state/user/system finishing modules

Create:

```text
scripts/state.sh
scripts/hakucfg.sh
scripts/shell_setup.sh
scripts/display_manager.sh
scripts/desktop_defaults.sh
scripts/reload.sh
```

Remove their old implementations/functions only after standalone tests pass.

---

## Batch E — Doctor

Move Doctor implementation into:

```text
scripts/doctor.sh
```

Convert root `doctor.sh` to wrapper.

Make Doctor read-only.

Use registry everywhere.

Test partial/manual installations.

---

## Batch F — install.sh cutover

Replace direct Install Blocks with module calls.

Do this incrementally, one block at a time.

After each extraction compare old vs new behavior.

Final `install.sh` must contain orchestration only.

---

## Batch G — update.sh cutover

Move:

```text
repository update
package update
config deployment
core update
NixOS update
state
hakucfg
reload
```

to modules.

Preserve updater re-exec behavior.

Final `update.sh` becomes orchestration only.

---

## Batch H — rollback registry integration

Change only managed-target discovery to use `registry.sh`.

Do not refactor restore behavior.

Perform physical rollback regression tests.

---

## Batch I — documentation

Only after commands are stable update:

```text
README.md
docs/management.md
docs/vietnamese/VN_management.md
```

Document:

```text
automatic installation
automatic update
manual package installation
manual config linking
manual unlinking
doctor
legacy Copy behavior
Deep Symlink behavior
ONCE_CONFIGS
hakucfg/state lifecycle
```

---

# 39. Manual installation guide target

README should eventually support a user doing something equivalent to:

```bash
git clone ...
cd hakuspace

./packages.sh core
./packages.sh niri

./link.sh quickshell
./link.sh kitty
./link.sh niri
./link.sh core

scripts/state.sh init
scripts/hakucfg.sh sync

./doctor.sh
```

And full installation remains:

```bash
./install.sh
```

Manual users should never need to open `install.sh` and copy shell commands from it.

---

# 40. Required test strategy

Create a shell-management test harness using a temporary HOME.

Do not test against the developer's real `$HOME`.

At minimum verify:

```text
shared BACKUP_DIR across modules

registry list correctness

WM selection/validation

deploy-mode detection:
  pure symlink
  pure copy
  mixed

link:
  first run
  second run
  --all
  nested files
  correct symlink
  foreign symlink
  broken symlink
  real file
  generated extra files

unlink:
  normal
  repeated
  --all
  foreign files preserved
  generated files preserved

ONCE_CONFIGS:
  copy on install
  no update/link/unlink

core:
  flat deployment
  basename collision

packages:
  each group
  multi-group
  install profile
  update profile
  --all

state:
  first init
  repeat init
  check read-only

hakucfg:
  missing templates
  existing custom files preserved
  setting version logic
  check read-only

legacy Copy:
  install smoke
  update smoke

doctor:
  healthy
  missing optional
  partial module
  wrong target
  broken link
  real-file replacement
  zero filesystem writes

NixOS:
  syntax/unit logic where possible without real rebuild

repo update:
  skip
  latest/stable behavior via controlled test/mocks where possible

install orchestration
update orchestration
rollback regression
```

Stub external commands such as:

```text
yay
sudo
systemctl
chsh
nixos-rebuild
gsettings
xdg-mime
```

where physical execution would modify the machine.

---

# 41. Final architecture invariants

Before calling the project DONE, all must be true:

```text
install.sh contains no config deployment implementation
update.sh contains no config deployment implementation

install.sh/update.sh contain no package parsing loops

functions.sh contains no HakuSpace domain workflows

determine_deploy_mode() no longer exists inside functions.sh

select_window_manager() no longer exists inside functions.sh

deploy_assets_from_archive_repo() no longer exists inside functions.sh

check_control_dir() no longer exists inside functions.sh

check_state_dir() no longer exists inside functions.sh

link/unlink/doctor/rollback use the same managed-target registry

one install/update run uses one backup context

Deep Symlink behavior remains unchanged

ONCE_CONFIGS remain real copied files

hakucfg remains user-controlled

state remains local mutable state

Copy deployment remains legacy and behavior-compatible

manual modules and automatic installer use the same implementation
```

Useful grep-style guardrail:

```text
install.sh/update.sh should not directly contain:
  yay -S
  ln -s
  cp -f
  git pull
  git checkout
  nixos-rebuild
  systemctl enable
  gsettings set
  xdg-mime default
```

Those operations belong to modules.

---

# 42. Final validation

Run at minimum:

```bash
git diff --check

bash -n install.sh
bash -n update.sh
bash -n link.sh
bash -n unlink.sh
bash -n packages.sh
bash -n doctor.sh
bash -n rollback.sh

find scripts -type f -name '*.sh' -print0 |
  xargs -0 -n1 bash -n

scripts/precommit_check.sh
```

Also show:

```bash
git status --short
git diff --stat
```

Run the temporary-HOME management test suite before physical install/update smoke testing.

---

# 43. Explicit non-goals

Do NOT:

```text
redesign HakuSpace configs
replace Deep Symlink with directory symlinks
modernize Copy mode
add new package managers
redesign NixOS support
rewrite rollback restore logic
refactor Quickshell/HakuSpace UI
touch notification/WM backend code
change package contents
change ONCE_CONFIG policy without explicit reason
invent a generic framework unnecessarily
```

This task is specifically about turning the current management system into composable modules while preserving behavior.

---

# 44. Definition of success

The intended final mental model is:

```text
                    install.sh
                         │
                         ▼
              ┌─────────────────────┐
              │ install profile     │
              └─────────────────────┘
                 │ │ │ │ │ │ │
                 ▼ ▼ ▼ ▼ ▼ ▼ ▼
               scripts/*.sh


                    update.sh
                         │
                         ▼
              ┌─────────────────────┐
              │ update profile      │
              └─────────────────────┘
                 │ │ │ │ │ │
                 ▼ ▼ ▼ ▼ ▼ ▼
               scripts/*.sh


Manual:

./link.sh niri       ───► scripts/link.sh
./packages.sh niri   ───► scripts/packages.sh
./doctor.sh          ───► scripts/doctor.sh
```

There must be no separate "automatic implementation" and "manual implementation".

The modules ARE the implementation.

`install.sh` and `update.sh` only decide which modules to run and in what order.
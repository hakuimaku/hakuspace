# How Are My Dotfiles Managed?

See the Vietnamese version: [Quản lý Dotfiles](./vietnamese/VN_management.md).

This document explains the architecture and tooling behind HakuSpace's modular dotfiles management.

---

## 1. Modular Architecture

HakuSpace uses a modular, composable CLI architecture. The top-level scripts (`install.sh` and `update.sh`) are thin orchestrators that execute dedicated modules under `scripts/`.

Every operational task can be performed either automatically via the orchestrators or manually using standalone CLI commands.

```text
install.sh / update.sh
        │
        │ orchestration only
        ▼
   scripts/*.sh
        │
        ├── registry.sh       (Single source of truth for managed targets)
        ├── runtime.sh        (Shared execution ID & backup context)
        └── filesystem.sh     (Policy-neutral file & backup primitives)
```

### Shared Runtime Context
Whenever `install.sh`, `update.sh`, or any standalone tool runs, a shared runtime context (`scripts/runtime.sh`) establishes a single `BACKUP_DIR` for that entire execution. Child processes automatically reuse this shared backup directory, preventing fragmented backup folders.

### Install and update logs

`./install.sh` and `./update.sh` automatically record terminal output in the
repository's `log/` directory, regardless of the current working directory. The
log path is printed at startup. Each run creates a separate private file named
`install-YYYY-MM-DD_HH-MM-SS.<random>.log` or
`update-YYYY-MM-DD_HH-MM-SS.<random>.log`; the directory is ignored by Git.

Logging uses `script` from util-linux to preserve interactive menus and capture
both output streams, including prompts written directly to the terminal. It
records output only, so password input with terminal echo disabled is excluded.
When input is piped, echo is disabled to avoid recording queued input. The
recorder preserves the script's exit status and records it in the log footer.
An updater re-exec after Git pull continues in the same log. Logs remain available
after success or failure and are not automatically deleted.

### Migration validity and recovery

The v26.11 migration retains its receipt at
`${XDG_STATE_HOME:-$HOME/.local/state}/hakuspace/migrations/v26.11.json`.
The recorded menu step describes conversion history. A historical `applied` step
does not prove that `~/hakucfg/config/hakumenu-general.json` still exists or is valid.
`scripts/migrate.sh --status` reports that history alongside `menu_destination`
and `completion_eligible`. Destination states distinguish `valid`, `missing`,
`malformed`, `schema-invalid`, `invalid` (including duplicate keys or unsafe paths),
and `not-required` when neither a prior conversion nor legacy input requires a menu.
Status inspection exits successfully when it can report state; callers must inspect
`completion_eligible` rather than treating status-command success as completion.

`--plan` is read-only. A missing destination before the first conversion is expected;
a missing destination after a recorded conversion, invalid JSON, or conflicting
input blocks the plan. `--apply` preserves valid post-conversion edits, including
their formatting and stable IDs. It never executes the legacy shell menu. JSON uses
the same bounded parser and schema as the General Menu backend: duplicate object
keys are rejected at every nesting level rather than merged or silently discarded.
Invalid inputs remain untouched; validation failure does not require creating a new
backup of those inputs, and existing backups remain available.

`--complete` rechecks both migration steps, legacy cleanup and current destination
validity. It refuses missing or invalid destinations and records a failed overall
status while retaining successful conversion history. It never recreates a missing
menu or overwrites a modified menu to match a stored checksum. `--audit`, also used
by Doctor, checks the current menu, receipt history and residual legacy artifacts:

| Exit | Audit result |
| --- | --- |
| `0` | Verified `applied`/`skipped`, or `not-required` when there is no legacy menu, destination or receipt. |
| `1` | Failed/incomplete migration, invalid destination or residual owned artifacts. |
| `2` | `unverified`: valid destination but missing receipt. |
| `3` | `pending-finalization`: recorded steps and destination are valid, awaiting the final completion gate. |

Audit is read-only. Status also exposes `receipt_present` separately from its
default pending state. Doctor treats exits `2` and `3` as explicit migration notes
while checking deployment health; it does not print “Everything is in order” for
those states. A clean deployment can still return Doctor exit `0` with a migration
note, allowing fresh installs without migration history and the updater's normal
pre-finalization check. That exit code alone does not verify migration completion.
These migration checks do not replace the updater's package, deployment and
diagnostic gates.

If the menu disappears, restore a known-good JSON backup when available, or manually
reconstruct it from the retained legacy input. For malformed JSON or duplicate keys,
review and repair the affected file explicitly; the migrator does not choose which
user action to discard. If both a first-time legacy menu and an existing custom JSON
conflict, reconcile them manually. Only after verifying the desired JSON, the user
may rename the legacy script to a retained `.saved` file to retire conversion of that
input. Do not delete the receipt to force conversion over user data.

After repair, inspect the plan and rerun the updater:

```bash
./scripts/migrate.sh --status
./scripts/migrate.sh --plan --to v26.11
python3 -B src/core/backend/user/general_menu_ctl.py check
./update.sh
```

Backups use the shared `BACKUP_DIR` printed by the updater, normally
`~/.backup/Backup_<run-id>/`, with original paths relative to HOME. Existing backups
are never replaced with different content. Interrupted copies are staged before
publication so retry does not encounter a newly published partial backup. A collision
with an older backup requires review; keep both copies rather than deleting either
blindly. A conversion published before an interrupted receipt write is adopted on
retry without rewriting its JSON or replacing the original pre-conversion backup.
A fresh updater run normally allocates a new backup directory.
Before removing a legacy original, migration flushes the backup file and its
directory entry, including ancestor directories through HOME so newly created backup
directories are durable too. Symlink backups flush their directory entries. Reused
matching backups are synced again on retry. Any sync error stops cleanup and leaves
the original in place.

Migration receipts support an absolute external `XDG_STATE_HOME`. The root and
HakuSpace migration directories must belong to the current user, must not be writable
by other users, and must be writable/searchable for migration writes. Symlink traversal
and `..` components are rejected. Inspection creates no directories; unrelated state
files are preserved. This applies to migration receipts; other HakuSpace state retains
its existing location. Legacy cleanup and backup destinations remain confined to HOME.

Recovery proceeds forward through the existing stages; it does not automatically
roll back packages or all deployed configs. A deployed configuration alone does not
mean the update completed. Failures retain their exit status, backup location and run
log; the updater records completion only after its required checks pass. A failed
updater re-exec retains its exit status, with the backup path printed before re-exec.
GTK/icon activation requires successful GSettings readback separately from
installed-file checks. Native `settings.ini` fallback is available for inspection,
but cannot confirm activation when GSettings reads fail or return invalid values;
existing applications can still require a restart or a new session to refresh caches.

---

## 2. Deployment Modes

HakuSpace supports two deployment strategies:

### Mode 1: Deep Symlink (Recommended & Default)
Managed via `./link.sh` and `scripts/link.sh`.
- **Directory preservation**: Destination directories (e.g. `~/.config/quickshell`) remain real directories rather than directory symlinks.
- **File symlinks**: Only individual tracked files are symlinked to `src/home/`.
- **Isolation**: Application caches, logs, and untracked runtime files stay local in your home directory and will never pollute the Git repository.
- **Instant sync**: Edits made to tracked files in `~/.config` immediately reflect in the repository.

### Mode 2: Legacy Copy (Classic)
Managed via `scripts/legacy_copy.sh`.
- Direct file copy from repository to user home.
- Safe and decoupled from the Git repository, but changes made in `~/.config` will not sync back to the repo automatically.
- Maintained for compatibility without altering legacy behavior.

`update.sh` and `doctor.sh` automatically detect whether your machine is in Symlink or Copy mode using `scripts/deploy_mode.sh`.

---

## 3. Special Targets & Lifecycles

### `ONCE_CONFIGS` (Install-only Copy)
Certain applications (Thunar, xfce4, mpv, btop, cava, mimeapps.list) frequently rewrite their configuration files with runtime state.
- These configs are **always copied** during initial installation via `scripts/once_configs.sh`.
- They are **never symlinked** and **never overwritten** during `./update.sh`.

### `~/hakucfg` (User Custom Space)
All personal customizations (autostarts, environment variables, theme overrides) belong in `~/hakucfg/`.
- Managed by `scripts/hakucfg.sh`.
- Quickshell-specific configuration lives in `~/hakucfg/hikai/hikai-shell.json`. Sync moves the legacy root file when the destination is absent; an existing destination takes precedence and the legacy file is retained. Shared Classic/Hikai files keep their shared paths.
- Preserved by default: missing templates are seeded, and version-mismatched `setting.sh` is only replaced after user confirmation (with an automatic backup).

### `~/.local/state/hakuspace` (Runtime State)
Stores generated style variables, themes, and runtime tokens.
- Initialized via `scripts/state.sh init`.
- Inspectable in read-only mode via `scripts/state.sh check`.

---

## 4. Root CLI Commands

| Command | Purpose |
|---|---|
| `./install.sh` | Full automatic installation profile |
| `./update.sh` | Full automatic update profile |
| `./link.sh [modules]` | Deep Symlink specific modules or all configs |
| `./unlink.sh [modules]` | Safely remove tracked symlinks |
| `./packages.sh [groups]` | Install pacman/yay package groups |
| `./doctor.sh` | Read-only integrity diagnostic |
| `./rollback.sh` | Restore configuration from previous backups |

---

## 5. Manual / Modular Workflow

You never need to copy-paste commands out of `install.sh` to configure a customized setup. You can run individual modules independently (for the complete step-by-step installation and Quickshell-only flows, see the [Installation Guide in README.md](../README.md#method-2---manual--modular-installation)):

### Install Packages
```bash
./packages.sh core
./packages.sh service
./packages.sh niri
./packages.sh --list
```

### Link Configurations
```bash
# Link individual components
./link.sh quickshell
./link.sh kitty
./link.sh niri
./link.sh core

# Link all registered base configs
./link.sh --all

# View available module names
./link.sh --list
```

### Unlink Configurations
`./unlink.sh` only removes symlinks verified to belong to HakuSpace. It will **never** delete real files, foreign symlinks, or application data:
```bash
./unlink.sh quickshell
./unlink.sh niri
./unlink.sh core
./unlink.sh --all
```

### Initialize State & User Space
```bash
scripts/state.sh init
scripts/hakucfg.sh sync
```

### Run Diagnostics
`./doctor.sh` is strictly read-only and will never alter your filesystem. It scans for broken links, missing configs, or overwritten real files and provides exact remediation commands:
```bash
./doctor.sh
```

---

## 6. Uninstalling HakuSpace

HakuSpace does not use a destructive one-shot uninstaller. The safest removal path depends on the deployment mode you selected during installation.

> [!IMPORTANT]
> `./unlink.sh` is for **Deep Symlink mode only**. It removes only symlinks verified to belong to HakuSpace and preserves real files, foreign symlinks, and application-generated data. Do **not** delete everything in `~/.local/bin` or entire config directories manually.

### 1. Restore an Older Configuration (Recommended When Available)
If you want to restore configuration files that existed before a HakuSpace install/update, use a suitable backup:

```bash
cd ~/hakuspace
./rollback.sh
```

Choose the backup you actually want to restore (the newest backup may be from a recent update rather than your pre-HakuSpace state). `rollback.sh` restores managed configuration destinations only; it does not uninstall packages or revert system-level choices.

### 2. Remove HakuSpace Symlinks
For a **Symlink mode** installation, unlink individual modules or all common links plus your Window Manager module(s):

```bash
# Individual modules
./unlink.sh quickshell
./unlink.sh niri
./unlink.sh core

# All common links + specific WM(s)
./unlink.sh --all niri
./unlink.sh --all hyprland niri mango labwc
```

Use `./unlink.sh --list` to inspect available module names.

For a **Copy mode** installation, `unlink.sh` does not remove copied files. Use `./rollback.sh` when an appropriate backup exists, or review copied configs manually instead of deleting whole directories.

### 3. Clean Up Runtime & User Data
The runtime state directory is generated by HakuSpace and can be safely removed:

```bash
rm -rf ~/.local/state/hakuspace
rm -rf ~/.local/share/hakuspace
```

- **`~/hakucfg`** contains your personal customizations and is intentionally not removed automatically. Keep it if you may reinstall later, or remove it manually (`rm -rf ~/hakucfg`) only after backing up your changes.
- **`ONCE_CONFIGS`** (`Thunar`, `xfce4`, `mpv`, `btop`, `cava`, `mimeapps.list`) are real copied files. Prefer restoring them from a backup or reviewing them individually.

### 4. Packages & System Settings
Package removal is manual because packages may be shared with other workflows. Inspect package groups using the repository helper before removing anything:

```bash
./packages.sh --list
./packages.sh --dry-run core service niri
```

Also review and restore any system-level choices made during installation:
- Default login shell (e.g., Fish)
- Display manager / TTY service configuration (e.g., Ly)
- Desktop defaults (dark color preference, Thunar file manager association)
- NixOS integration under `/etc/nixos`

### 5. Optional Assets Cleanup
If you installed `hakuspace-archive`, remove the checkout:

```bash
rm -rf ~/hakuspace-archive
```

Remove only the HakuSpace assets you recognize inside `~/.icons`, `~/.themes`, or `~/Pictures/Wallpapers` (do not delete those entire directories).

### 6. Remove the Repository (LAST)
Once all other uninstallation steps are complete and verified:

```bash
rm -rf ~/hakuspace
```

Keep your `~/.backup/Backup_*` and `Rollback_Backup_*` directories until you are completely sure you no longer need them.

---
**Next:** [Core Libraries](core/lib.md) ➡️

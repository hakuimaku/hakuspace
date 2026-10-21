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

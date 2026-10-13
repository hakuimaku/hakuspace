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
- Missing templates are seeded during setup, while user-modified files are strictly preserved.
- `setting.sh` versions are checked against repository updates.

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

You never need to copy-paste commands out of `install.sh` to configure a customized setup. You can run individual modules independently:

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
**Next:** [Core Libraries](core/lib.md) ➡️

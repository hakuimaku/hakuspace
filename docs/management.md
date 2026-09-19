# How Are My Dotfiles Managed?

See the Vietnamese version: [Management](./vietnamese/VN_management.md).

This document explains how HakuSpace deploys and manages dotfiles safely in your home directory. We use a **Hybrid Deployment Mechanism** that gives you the best of both worlds.

## 1. Core Architecture

The repository stores the BASE configuration layout under `src/home/`:

```text
Repository                         Your home
-----------                        ---------
src/home/.config/*       ------->  ~/.config/*
src/core/*               ------->  ~/.local/bin/*
src/home/hakucfg/*       --copy->  ~/hakucfg/*
```

When you install HakuSpace, you get to choose between two deployment modes for `.config` and `core` scripts:

### Mode 1: Symlink (Recommended)
This mode uses **Deep Symlinking** (similar to GNU Stow).
Instead of linking an entire directory (like `~/.config/hypr`), it creates real directories and only symlinks the individual files inside them.

- **Pros:** 
  - When apps dump cache, state, or log files into their config directories, those junk files stay on your machine and don't pollute the Git repository.
  - Edits you make to the symlinked files instantly reflect in the Git repository.
- **Cons:** 
  - If you create a brand new file in `~/.config`, you must manually move it to the repository and run `update.sh` to link it.

### Mode 2: Copy (Classic)
This mode simply copies files directly from the repository to your home directory.

- **Pros:** Dead simple.
- **Cons:** Edits made in `~/.config` will NOT update the Git repository. You have to manually copy them back to save your changes.

Your choice is saved in `~/.local/state/hakuspace/deploy_mode` so `update.sh` and `rollback.sh` remember what to do later.

## 2. Special Rules

Not everything is symlinked. To prevent apps from destroying your repository, some configs follow strict rules:

### `ONCE_CONFIGS` (Always Copied)
Apps like Thunar, xfce4, mpv, and btop tend to aggressively overwrite their config files when you use their GUI.
To prevent them from breaking symlinks or messing up the Git repository, these configs are **ALWAYS** copied as real files, regardless of your deployment mode. Furthermore, `update.sh` will **skip** updating them to protect your personal tweaks.

### `hakucfg` (Your Custom Space)
HakuSpace is designed to avoid overwriting your personal settings. The `~/hakucfg/` directory is meant for your own environment variables, auto-starts, and custom scripts. It is safely deployed using the Copy mechanism and left alone during updates.

## 3. The Management Scripts

We provide three main scripts to manage your setup:

### `install.sh`
The initial setup. It asks for your preferred Window Manager and deployment mode (Symlink or Copy), then deploys the configurations.

### `update.sh`
When you pull new changes from GitHub, run `update.sh`. It automatically reads your deployment mode and syncs the changes to your home directory. It skips `ONCE_CONFIGS` to protect your local tweaks.

### `rollback.sh`
Safety first! Before any file or directory is overwritten by HakuSpace, it gets backed up to `~/.backup/Backup_<timestamp>`.
If an update breaks your system, run `rollback.sh`.
- It intelligently scans your current `~/.config` and `~/.local/bin`.
- It safely removes HakuSpace symlinks to prevent accidental dereferencing (which could wipe out files in the Git repo).
- It restores your old files precisely where they belong.

### `doctor.sh`
If things act weird, run `./doctor.sh`.
If you chose Symlink mode, the doctor will scan your `~/.config` and `~/.local/bin` to find:
- **Broken symlinks:** Files that were deleted or paths that changed.
- **Overwritten files:** If you accidentally opened a symlinked config in a text editor and saved over it (turning it into a real file), the doctor will warn you and tell you to run `update.sh` to restore the symlink.

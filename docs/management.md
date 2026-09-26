# How Are My Dotfiles Managed?

See the Vietnamese version: [Management](./vietnamese/VN_management.md).

This doc explains how HakuSpace sets up your dotfiles safely. We use a **Hybrid Deployment** system, meaning you get to choose how your files are handled!

## 1. How It Works

The repo stores the core configs under `src/home/`:

```text
Repository                         Your home
-----------                        ---------
src/home/.config/*       ------->  ~/.config/*
src/core/*               ------->  ~/.local/bin/*
src/home/hakucfg/*       --copy->  ~/hakucfg/*
```

When you install, you pick between two modes for your `.config` and `core` scripts:

### Mode 1: Symlink (Recommended)
This uses **Deep Symlinking** (kinda like GNU Stow).
Instead of linking a whole folder (like `~/.config/hypr`), it makes real folders and only symlinks the files inside.

- **Pros:** 
  - App junk (cache, logs, states) stays on your machine and won't pollute the Git repo.
  - Any edits you make in `~/.config` instantly sync to the Git repo.
- **Cons:** 
  - If you create a brand new file in `~/.config`, you gotta manually move it to the repo and run `update.sh` to link it up.

### Mode 2: Copy (Classic)
Just straight up copies files from the repo to your home folder.

- **Pros:** Super simple and safe.
- **Cons:** Your edits in `~/.config` won't update the Git repo. You have to manually copy them back to save your changes.

Your deployment mode isn't saved to a configuration file; instead, `update.sh` heuristically scans your `~/.config` to detect whether you are primarily using symlinks or copies, and automatically syncs new changes using the same method.

## 2. Special Rules

Not everything is symlinked. To stop apps from breaking your repo, we have some strict rules:

### `ONCE_CONFIGS` (Always Copied)
Apps like Thunar, xfce4, mpv, btop, cava, and mimeapps.list often overwrite their configs during normal use.
To stop them from breaking symlinks, these are **ALWAYS** copied as real files, no matter what mode you picked. Also, `update.sh` will **skip** updating them to protect your personal tweaks!

### `hakucfg` (Your Custom Space)
HakuSpace won't touch your personal stuff. `~/hakucfg/` is for your own environment variables, autostarts, and custom scripts. 

**Important Developer Note:** `~/hakucfg/` is NOT copied blindly as a whole directory. Instead, the `check_control_dir()` function in `scripts/functions.sh` maintains a hardcoded `required_files` array (like `setting.sh`, WM configs, and menu scripts). It iterates through this array and copies files from `src/home/hakucfg/` ONLY if they are completely missing on the user's machine (except for `setting.sh`, which uses a specific version-check to handle upgrades). If you add a new template file to `src/home/hakucfg/`, you **must** remember to manually add it to the `required_files` array; otherwise, existing users will never receive it during updates!

## 3. The Scripts

We got three main scripts to manage your setup:

### `install.sh`
The first-time setup. It asks for your Window Manager and deploy mode (Symlink or Copy), then sets everything up.

### `update.sh`
Run this when you pull new changes from GitHub. It automatically checks your deploy mode and syncs the changes to your home directory (skipping `ONCE_CONFIGS` of course!).

### `rollback.sh`
Safety first! Before HakuSpace overwrites anything, it backs it up to `~/.backup/Backup_<timestamp>`.
If an update breaks things, just run `rollback.sh`:
- It scans your `~/.config` and `~/.local/bin`.
- It safely removes HakuSpace symlinks so it doesn't accidentally wipe repo files.
- It restores your old files exactly where they were.

### `doctor.sh`
If things act weird, run `./doctor.sh`.
If you're in Symlink mode, the doctor scans your configs to find:
- **Broken symlinks:** Deleted files or changed paths.
- **Overwritten files:** If you accidentally saved over a symlink (turning it into a real file), the doctor will warn you and tell you to run `update.sh` to fix it.

---
**Next:** [Core Libraries](core/lib.md) ➡️

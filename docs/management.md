# How Are My Dotfiles Managed?

See the Vietnamese version: [Management](./vietnamese/VN_management.md).

This document supplements [Architecture](architecture.md) by explaining how dotfiles are deployed and managed safely in the home directory.

The repository is the source of versioned default configurations. The home directory contains independent copies, together with your files and application-generated data.

## 1. Core Model

The repository stores the BASE configuration layout under `src/home/`:

```text
Repository                         Your home
-----------                        ---------
src/home/.config/*       --copy--> ~/.config/*
src/home/.local/bin/*    --copy--> ~/.local/bin/*

src/home/hakucfg/*       --copy--> ~/hakucfg/*
```

Every configuration file in the home directory is an independent copy and can be edited without changing the repository. This copy-based approach avoids symbolic-link conflicts and means you do not need detailed Git knowledge to pull repository updates safely. To provide more room for personal customization, HakuSpace uses `~/hakucfg/` for your personal settings.

- **BASE**: configuration files and scripts shipped by HakuSpace. They are maintained in the repository and may be overwritten during an update. Personal changes should go in `~/hakucfg/` instead.
- **CUSTOM**: your settings in `~/hakucfg/`. These settings belong to you and are not normally overwritten. `install.sh` and `update.sh` create missing custom files so the control configuration is available immediately.

Do not edit HakuSpace-managed files directly under `~/.config` or `~/.local/bin` if you want changes to survive future updates. Put supported customizations in `~/hakucfg/` instead.

## 2. Deployment and Management

The three scripts have different roles:

- `install.sh` is the initial installation flow. It selects a window manager, installs packages, creates required directories, deploys configuration and `~/.local/bin` scripts, optionally deploys assets, and performs system setup.
- `update.sh` updates the repository before deployment. It can use `LATEST` to pull the `main` branch, `STABLE` to check out the newest tag, or `SKIP` to keep the current repository revision. It then updates packages, configuration, and `~/.local/bin` according to your choices.
- `rollback.sh` does not reinstall packages or repeat system setup. It restores only HakuSpace-managed dotfiles from a selected backup.

### Once-only Configuration: `ONCE_CONFIGS`

- These configurations are intended to be deployed only during the first installation.
- They are intended for configurations that HakuSpace does not frequently change but that you may need to customize. Those changes are preserved across `update.sh` and `rollback.sh`.
- Running `install.sh` again deploys these configurations again, so `install.sh` should normally be used once or only when these configurations genuinely need to be reinstalled.
- They include:
  - `~/.config/Thunar`
  - `~/.config/xfce4`
  - `~/.config/mpv`
  - `~/.config/btop`
  - `~/.config/cava`

> `mimeapps.list` follows the same once-only behavior, but it is a file and is therefore not included in the `ONCE_CONFIGS` array.

### General Configuration Deployment

This includes files and directories under `src/home/.config` that are not part of `ONCE_CONFIGS`, `SKIP_CONFIGS`, or a special deployment path. When you confirm deployment:

- `install.sh` and `update.sh` copy the base configuration into `~/.config`.
- If a destination already exists, the script backs it up before copying the new configuration.
- `update.sh` does not deploy configuration when you skip the configuration-update step.
- General configurations are managed per directory or file. Your files outside the repository source list are not removed by the scripts.

The two scripts also copy `src/home/.local/bin` into `~/.local/bin` and apply executable permissions after copying. This is a direct BASE deployment, so deployed files should not be edited directly when the changes need to survive an update.

### Special Configuration Deployment

Some configurations do not go through the general configuration loop:

- **Window managers**: you can select Hyprland, Niri, Mango, Labwc, or all of them. `install.sh` and `update.sh` deploy only the selected window managers. Hyprland copies `config/` into `~/.config/hypr/config` and copies `hyprland.lua` separately; the other window managers copy into their corresponding directories.
- **Shared Hyprland files**: `hypridle.conf`, `hyprlock.conf`, and `hyprlock_tiny.conf` are copied separately into `~/.config/hypr`. They are shared by all window-manager setups, but their default path is under `~/.config/hypr`. Copying the whole `hypr` directory would either overwrite the Hyprland configuration or leave unrelated Hyprland files looking like unnecessary bloat when you use another window manager, so these files are handled separately.
- **GTK**: `gtk-3.0/gtk.css` is copied separately. It provides the GTK3 application and Thunar theme and is handled specially so the file manager's bookmarks are not lost.
- **Individual files**: `starship.toml` and `.nanorc` are copied explicitly to their destinations. They require `copy_file` rather than the directory-copy path.
- **`mimeapps.list`**: it is deployed only by `install.sh` and is not overwritten by `update.sh`. It behaves like an `ONCE_CONFIGS` entry, but it is a file and is not included in that array.
- **`~/hakucfg`**: at the end of `install.sh` and `update.sh`, `check_control_dir` creates the directory and any missing custom files from `src/home/hakucfg`. `setting.sh` is updated only when its version differs and you agree; that update can overwrite custom changes in the file. Other existing custom files are not replaced automatically.
- **NixOS**: `install.sh` deploys NixOS configuration files from `nix/`, specifically `hakuspace-control.nix`. This is a basic NixOS configuration file that contains only the programs and packages needed for HakuSpace. It does not deploy other NixOS configuration files, as HakuSpace does not want to interfere with your system. HakuSpace configuration files and scripts are still managed by copy rather than Home Manager, because dotfiles are not managed by symbolic links.

## 3. Backup Storage

The scripts store backups under `~/.backup/` using these forms:

```text
~/.backup/Backup_<YYYY-MM-DD_HH-MM-SS>/
~/.backup/Rollback_Backup_<YYYY-MM-DD_HH-MM-SS>/
```

### During Install or Update

- Each script run uses one `Backup_<timestamp>` directory for that run.
- Before overwriting an existing file or directory, `backup_item` moves the current item into the backup while preserving its relative path from the home directory. A backup can therefore contain `.config/...`, `.local/bin/...`, or `.nanorc`.
- Backups are created before changes are made, so `rollback.sh` can use them to restore an earlier state.

### During Rollback

- `rollback.sh` lists only directories whose names begin with `Backup_`, newest first. It does not use unrelated directories under `~/.backup`.
- Before restoring, existing HakuSpace-managed files and directories are moved into `Rollback_Backup_<timestamp>`. This is a safety copy of the state before rollback; the script currently does not include `Rollback_Backup_*` in its automatic selection list.
- The script restores only managed destinations such as general configuration, known window-manager paths, `~/.local/bin`, and `~/.nanorc`. Files outside that list are preserved.
- When restoring `.config` or `.local`, the script processes managed children rather than replacing the container directory as a whole. `ONCE_CONFIGS` are always skipped.
- Rollback does not restore packages, assets, the shell, system services, or NixOS configuration. Those changes must be handled separately.

Do not delete backups immediately after an update or rollback. Check the configuration and applications first; once the new state is known to work, old backups can be removed manually to reclaim disk space.

## 4. Conclusion

The central design principle is simple: `src/home/` is the reproducible source of BASE configuration, the home directory contains deployed copies, `~/hakucfg` contains your CUSTOM settings, and `~/.backup/` provides recovery points around copy operations.

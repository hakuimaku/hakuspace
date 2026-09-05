# HakuSpace Dotfiles Copy Management

> AI generated content. Maybe inaccurate or incomplete. But I've reviewed it & ensured it is accurate.

See Vietnamese translation: [VN_dotfiles-copy-management.md](./vietnamese/VN_dotfiles-copy-management.md)

This document explains how HakuSpace installs, updates, and rolls back user configuration files. HakuSpace uses a **copy-based deployment model**. It does not use GNU Stow, symbolic links, Git worktrees, or a live synchronization process.

This is the detailed companion to the [HakuSpace Architecture](architecture.md) document.

The repository is the source of versioned defaults. The user's home directory contains independent copies of those defaults, together with user-owned files and application-generated state.

## 1. Core Model

The repository keeps the base home-directory layout under `src/home/`:

```text
Repository                         User home
-----------                        ---------
src/home/.config/*       --copy--> ~/.config/*
src/home/.local/bin/*    --copy--> ~/.local/bin/*
src/home/.nanorc         --copy--> ~/.nanorc
src/home/hakuspace-control/*
                           --copy--> ~/hakuspace-control/*
```

A copied file has its own inode and can be edited independently from the repository source. Editing a deployed file does not edit the Git checkout. Likewise, editing a repository file does not change the active desktop configuration until an install or update operation copies it again.

The model has two important ownership areas:

- **Base configuration**: versioned defaults in `src/home/`. These are maintained by the repository and may be replaced by a later install or update.
- **Custom configuration**: user-specific settings in `~/hakuspace-control/`. The base configuration is designed to load or refer to this directory so personal settings can survive changes to the base configuration.

This is a deliberate boundary. A configuration should be customized in `~/hakuspace-control/` when the corresponding base file supports that override. Direct edits to a deployed base file under `~/.config` or `~/.local/bin` can be overwritten by a later deployment.

## 2. What Counts as a Managed Destination

The installer and updater deploy a defined set of destinations. They do not own the whole home directory.

### Configuration destinations

Entries under `src/home/.config/` are copied to matching entries under `~/.config/`, with special handling for window-manager directories:

- General application directories and files are copied to matching paths under `~/.config/`.
- `hypr/`, `niri/`, `mango/`, and `labwc/` are deployed through dedicated branches because the selected window manager determines which parts are copied.
- Hyprland can deploy `hypr/config` and `hyprland.lua` separately.
- `hypridle.conf`, `hyprlock.conf`, and `hyprlock_tiny.conf` are always copied regardless of the selected window manager because they are core configuration files for `hypridle` and `hyprlock`. Their default configuration location matches Hyprland's `~/.config/hypr/`, so they require special handling.
- `gtk-3.0/gtk.css` is deployed as a specific file. The existing `gtk-3.0` directory is backed up with `backup_dir` before that file is copied.
- `starship.toml`, `mimeapps.list`, and other top-level configuration files are copied to matching paths.

### Local scripts

`src/home/.local/bin/` is copied to `~/.local/bin/`. The installer and updater copy the directory contents and then apply executable permissions to the deployed scripts where required.

### Other files

The installer and updater also deploy `src/home/.nanorc` to `~/.nanorc`.

### Files outside this boundary

The scripts do not intentionally manage every file under `~/.config` or `~/.local`. For example, an application directory that is not part of the repository's deployment list remains user-owned. Rollback follows the same boundary: it clears managed destinations only and preserves unrelated siblings.

## 3. Shared Copy and Backup Helpers

The common behavior lives in `scripts/functions.sh` and the paths live in `scripts/variables.sh`.

### `copy_file`

`copy_file SOURCE DESTINATION` performs these operations:

1. Verify that the source is a regular file.
2. If the destination already exists and backup is not disabled, call `backup_item`.
3. Create the destination's parent directory if necessary.
4. Copy the source over the destination with `cp -f`.
5. Log the copy operation.

The optional third argument disables the helper's automatic backup. This is used when a caller has already backed up a directory or when rollback has already cleared its managed destinations.

### `copy_dir_content`

`copy_dir_content SOURCE_DIR DESTINATION_DIR` performs these operations:

1. Verify that the source directory exists.
2. If the destination exists and backup is not disabled, call `backup_item`.
3. Create the destination directory if necessary.
4. Copy the contents of the source directory into the destination with `cp -rf SOURCE_DIR/. DESTINATION_DIR/`.
5. Log the copy operation.

The important detail is that this is a **content merge after backup**, not an in-place synchronization algorithm. During normal install/update operations, the existing destination is moved away first when it exists, so the copied directory starts clean. During rollback, destinations are cleared explicitly before restore for the same reason.

### `backup_item`

`backup_item TARGET` moves an existing target into the current backup directory while preserving its path relative to `$HOME`:

```text
$HOME/.config/kitty
    -> $HOME/.backup/Backup_YYYY-MM-DD_HH-MM-SS/.config/kitty
```

The helper uses `mv`, not `cp`, so the original destination is removed as part of the backup operation. If permissions require it, the helper uses `sudo` and restores ownership of the backup path to the current user when possible.

### `backup_dir`

`backup_dir TARGET_DIRECTORY` makes a copied backup of a directory instead of moving it. This is used by the explicit GTK theme deployment before replacing `gtk-3.0/gtk.css`. It is different from `backup_item`, which normally moves a destination out of the way.

## 4. Backup Storage

Backups are stored below:

```text
~/.backup/
```

A normal installer or updater backup has this form:

```text
~/.backup/Backup_YYYY-MM-DD_HH-MM-SS/
├── .config/
│   ├── application-name/
│   └── another-config
├── .local/
│   └── bin/
├── .nanorc
└── ...
```

The backup contains the destinations that were moved or copied before a deployment operation. It is therefore a recovery point for the files affected by that run. It should not be interpreted as a complete image of the user's home directory unless the operation actually backed up every relevant path.

Backup names are timestamped to make them sortable. `rollback.sh` lists them in reverse lexical order, which places the newest timestamp first when the timestamp format is unchanged.

## 5. `install.sh`: First-Time Deployment

`install.sh` is the broad setup entry point. In addition to configuration deployment, it can install packages, create directories, deploy assets, initialize `hakuspace-control`, and perform system-specific setup.

The dotfiles-related flow is:

1. **Load repository paths and helpers** from `scripts/variables.sh` and `scripts/functions.sh`.
2. **Select window managers**. The choice determines which WM package list and configuration branch are used.
3. **Create required directories**, including `~/.config`, theme directories, and wallpaper directories.
4. **Deploy general configuration directories** from `src/home/.config/`, except directories handled by the once-only or window-manager rules.
5. **Deploy explicit WM files and directories** for the selected WMs.
6. **Deploy once-only configuration directories** such as Thunar, XFCE, MPV, and btop. These are intended to be initialized once and protected from later updater overwrites.
7. **Deploy individual files**, including the GTK stylesheet, Starship configuration, `.nanorc`, and `mimeapps.list`.
8. **Deploy local scripts** from `src/home/.local/bin/` to `~/.local/bin/`.
9. **Run later setup steps**, such as initializing `~/hakuspace-control` and optional system services.

For normal destinations, the copy helpers back up an existing target before copying. The result is an independent deployed copy in the home directory and a recovery copy in `~/.backup/`.

First installation can therefore preserve files that were already present before HakuSpace was installed. However, users should review which prompts they accept because installation also performs package and system setup beyond dotfiles deployment.

## 6. `update.sh`: Repository and Configuration Update

`update.sh` updates an existing HakuSpace installation. It can first change the repository revision, then deploy newer configuration files.

### Repository update phase

The user can choose:

- **Latest**: switch to the main branch and pull from the remote.
- **Stable**: fetch tags and check out the newest available release tag.
- **Skip**: keep the current repository revision.

If the updater itself changed as part of the repository update, it re-executes the updated script so the remaining operation uses the new logic.

### Configuration update phase

The updater then:

1. Selects the window manager configuration to update.
2. Copies general managed configuration directories.
3. Skips `ONCE_CONFIGS`, preserving local changes in those directories after first installation.
4. Deploys the selected WM configuration and shared WM files.
5. Backs up and deploys the GTK stylesheet.
6. Updates `starship.toml` and `.nanorc`.
7. Copies the managed local scripts to `~/.local/bin/`.
8. Optionally performs NixOS configuration updates and rebuilds.

A normal update can overwrite direct edits to managed base files because those files are intentionally controlled by the repository. Custom settings should be moved to `~/hakuspace-control` or another supported user-owned location before updating.

Each update creates a separate timestamped backup under `~/.backup/`. This allows a later rollback to select the state that existed before a particular update.

## 7. `rollback.sh`: Selective Cleanup and Restore

Rollback is not implemented as a blind copy over the current home directory. Its purpose is to return managed destinations to the state recorded in a selected backup while avoiding unrelated user files.

### Selection phase

`rollback.sh`:

1. Loads the same path and helper definitions used by the installer and updater.
2. Finds directories matching `~/.backup/Backup_*`.
3. Sorts them newest first.
4. Automatically selects the only backup when there is one, or prompts the user when there are multiple backups.
5. Requires confirmation before changing the home directory.

### Managed-destination phase

After confirmation, rollback builds a list of destinations that the installer and updater can manage. This includes repository-backed configuration entries, special WM paths, `~/.local/bin`, and `~/.nanorc`.

The directories listed in `ONCE_CONFIGS` are a special exception. They are initialized by `install.sh` during first-time setup, then intentionally skipped by normal updates. Rollback skips them as well: it does not move the current copy into the rollback safety backup and does not restore the corresponding copy from the selected backup. This preserves user changes made after the first installation. For example, a rollback must not replace the current `~/.config/Thunar` with an older Thunar configuration.

Each existing managed destination is moved into a new safety directory:

```text
~/.backup/Rollback_Backup_YYYY-MM-DD_HH-MM-SS/
```

This is the state that existed immediately before rollback. Keeping it makes the rollback reversible if the selected backup was not the desired one.

Unrelated entries are not added to this list. For example:

```text
~/.config/unrelated-app/
~/.local/share/
```

are not removed merely because rollback is running. A sibling directory under `~/.config` or `~/.local` is affected only when it is one of the explicitly managed destinations.

### Restore phase

Rollback then walks the selected backup. For `.config` and `.local`, it restores their immediate children into `$HOME` so the container directories themselves are not removed or replaced. Other top-level backup entries, such as `.nanorc`, are restored directly.

The selected backup is copied into the home directory with backup disabled because the current managed destinations have already been moved to the rollback safety directory. This avoids duplicate backup operations and keeps the log understandable.

### Important consequence

A selected backup represents the previous state captured by one install or update operation. If a managed destination is absent from that backup, rollback does not recreate it. Since rollback clears the managed destination list before restoring, that destination can remain absent afterward. This is intentional: it prevents stale files from surviving a rollback, but it also means users should select the backup that matches the desired deployment state.

## 8. Example Lifecycle

Assume the current system contains:

```text
~/.config/kitty/kitty.conf       # managed
~/.config/my-unrelated-app/      # unrelated
~/.local/bin/haku.sh             # managed
```

An update changes `kitty.conf` and deploys a new script. Before copying, the old managed destinations are stored under a timestamped `Backup_*` directory.

If the update is undesirable, rollback works conceptually like this:

```text
1. Select ~/.backup/Backup_...
2. Move current managed kitty and local/bin destinations to ~/.backup/Rollback_Backup_...
3. Leave ~/.config/my-unrelated-app untouched
4. Restore the selected backup's .config and .local children
5. Restore files such as .nanorc when present
```

The repository remains unchanged throughout this process. Rollback changes only the deployed copies in the user's home directory.

## 9. Customization Rules

Use these rules to avoid losing personal changes:

- Treat `src/home/` as versioned base input, not as the live configuration directory.
- Put supported personal overrides in `~/hakuspace-control`.
- Expect direct edits to managed files under `~/.config` and `~/.local/bin` to be replaced by install or update.
- Review `ONCE_CONFIGS` behavior. They are initialized by the first installation and skipped by both normal updates and rollback. Their current user-owned state is intentionally preserved.
- Keep important backups under `~/.backup/` until the corresponding update has been verified.
- Do not manually rename backup directories if you rely on timestamp sorting.
- After restoring WM configuration, reload the relevant window manager or restart affected applications.

## 10. Advantages and Trade-Offs

### Advantages

- Uses ordinary files and standard shell tools.
- Does not require symlink knowledge or a special dotfiles manager.
- Keeps repository defaults portable and easy to inspect.
- Creates timestamped recovery points before managed deployments.
- Allows unrelated user configuration to coexist in the same home directories.
- Makes the base/custom boundary explicit.

### Trade-offs

- Copying consumes more disk space than symlinks.
- Deployed files can drift from repository files between updates.
- Direct edits to managed files can be overwritten.
- Backup directories require periodic cleanup and enough disk space.
- A backup is operation-specific, not automatically a full-home snapshot.
- The deployment rules must be kept in sync with rollback's managed-destination list when new managed paths are added.

The central design principle is simple: `src/home/` is the reproducible source of base configuration, the home directory contains deployed copies, `~/hakuspace-control` contains user-owned customization, and `~/.backup/` provides recovery points around copy operations.

# Directory Structure & Architecture Specification

This document describes the `hakuspace` repository layout and its copy-based dotfiles management model.

```text
hakuspace (root)
├── assets/
│   └── browser/                # Custom userChrome.css & newtab.html for Firefox
│
├── docs/                       # Documentation for my dots
├── nix/                        # Declarative Nix configuration
├── scripts/                    # Helper libraries for the shell entry points
├── install.sh                  # First-time setup and config deployment
├── update.sh                   # Repository, package, and config update
├── rollback.sh                 # Restore a selected backup
│
└── src/                        # Core configuration modules, searching for my dotfiles here
    ├── home/                   # Simulation of the home directory structure for dotfiles
    │   ├── hakuspace-control/  # Base templates for user custom settings
    │   ├── .config/            # Base application configuration files
    │   └── .local/             # Base local files and scripts
    │
    └── packages/               # Package lists to install
```

---

## Dotfiles Management Model: Copy, Not Stow

Hakuspace does **not** manage dotfiles with Stow, Git worktrees, or symbolic links. The repository is the source of `base` configuration, and `install.sh`/`update.sh` copy that configuration into the user's home directory.

```text
Git repository (base)
    src/home/.config/*           --copy-->  ~/.config/*
    src/home/.local/bin/*        --copy-->  ~/.local/bin/*
    src/home/hakuspace-control/* --copy-->  ~/hakuspace-control/*

User-specific custom configuration
    ~/hakuspace-control/
```

### Base and Custom

* **Base**: Files under `src/home/` are the versioned defaults shipped by the repository. They define the common structure and behavior. Users should avoid editing them directly because `update.sh` can copy newer base files over the deployed files.
* **Custom**: `~/hakuspace-control/` is the user's persistent customization area. Window-manager configs and scripts in the base configuration are designed to load or reference files from this directory, such as `hyprland-custom.lua`, `niri-custom.kdl`, `mango-custom.conf`, `hypridle.conf`, and `dockbar_pin_apps`.
* **Deployment**: On first install, missing custom-control files can be created from the repository defaults. During later updates, the control directory is checked and version changes may be offered for update; accepting that update can overwrite the selected control file, so custom changes should be kept in mind before confirming.
* **No automatic reverse sync**: Editing `~/.config` or `~/hakuspace-control` does not update the Git repository. To publish a new base default, it must be copied or edited deliberately in `src/home/` and committed separately.

This separation allows the repository to receive base improvements while keeping personal settings in `~/hakuspace-control`. It also makes the intended editing location explicit: customize files in `~/hakuspace-control`, and treat files in `src/home/` as managed defaults.

### Install, Update, and Rollback Flow

1. **`install.sh`** installs selected packages, creates required directories, backs up existing files, and copies the selected base configuration from `src/home/` into `$HOME`. It also deploys the selected window-manager configuration and local scripts.
2. **`update.sh`** can update the repository first, then backs up and copies managed base files again. This is why direct edits to deployed base files may be overwritten. Configurations marked as `ONCE_CONFIGS` (for example Thunar, XFCE, MPV, and btop) are skipped by later updates to preserve local changes.
3. **`rollback.sh`** lists `~/Backup_*` directories created by installation or update, saves the current state to a `~/Rollback_Backup_*` safety directory, then copies the selected backup back into `$HOME`. Rollback is file restoration, not a return to a symlink-based setup.

Backups preserve the previous deployed state before a copy operation. They are therefore the recovery mechanism for an update that produces an unwanted result, while `~/hakuspace-control` remains the primary place for personal customization.

### Advantages

* **Simple deployment**: Works with ordinary files and standard copy operations; no Stow knowledge or symlink debugging is required.
* **Stable personal overrides**: Custom settings live outside the repository and can be kept while the base configuration evolves.
* **Predictable rollback**: Each install/update can retain a complete backup of the previous home-directory state.
* **Portable repository**: The Git repository can be copied to another machine without depending on a particular symlink layout.
* **Explicit update boundary**: The distinction between managed base files and user-owned custom files is visible in both the directory structure and the configuration includes.

### Disadvantages and Trade-offs

* **Updates can overwrite edits**: Changes made directly to deployed base files, such as files under `~/.config`, can be lost when `update.sh` copies the repository version over them.
* **Configuration drift is possible**: The deployed home directory can differ from `src/home/`, and those local changes are not automatically detected or committed back to Git.
* **More disk usage and I/O**: Copying creates independent file copies instead of sharing one inode through a symlink.
* **Backup management is required**: Frequent updates can create multiple `Backup_*` directories that need to be retained or cleaned up deliberately.
* **Custom boundaries must be respected**: A user must know whether a setting belongs in `~/hakuspace-control`, a once-only config, or the base tree. Editing the wrong location can lead to an unexpected overwrite.
* **No live repository changes**: Editing a file in the Git checkout does not immediately affect the running configuration; the relevant install/update flow must be run again.

The copy model is intentional: `src/home/` provides reproducible defaults, while `~/hakuspace-control` provides the user-owned customization layer. It favors controlled deployments and rollback over the live synchronization commonly associated with symlink-based Git dotfiles managers.

---

## Detailed Directory Breakdown

### Root Execution Scripts (`/`)

* **`install.sh`**: The primary first-time setup script. It handles environment detection, package installation, backups, and copying configuration from `src/` into the home directory.
* **`update.sh`**: The update script. It can pull the latest repository changes, update packages, back up the current state, copy managed base configuration, and check `~/hakuspace-control`.
* **`rollback.sh`**: The restore script. It restores a selected `~/Backup_*` snapshot and first saves the current state as a safety backup.

### 1. `scripts/` (Core Helper Libraries)

This directory acts strictly as an internal backend for `install.sh` and `update.sh`. It contains no executable entry points.

* **`functions.sh`**: Contains reusable Bash functions.
* **`variables.sh`**: Defines global variables and paths used throughout the scripts.

### 2. `src/` (Dotfiles & Package Manifests)

The primary search target and storage location for all managed user configurations.

* **`src/home/`**: Simulates the home directory structure for the base files copied to a user's home. Contains:
    * **`hakuspace-control/`**: Default templates for the user-owned `~/hakuspace-control` customization directory.
    * **`.config/`**: Base configuration files for various applications.
    * **`.local/`**: Base local binaries and scripts.
* **`~/hakuspace-control/`**: The deployed custom configuration directory. It is outside the Git repository and is intended for per-user settings.
* **`src/packages/`**: Contains package lists for installation:
    * `pkg-core.txt`: Core packages required for my setup.
    * `pkg-service.txt`: Service packages: brightnessctl, bluetooth, btop, etc.
    * `pkg-optional.txt`: Optional packages: Browser, Terminal Decorations, Screen Recording, etc.
    * `pkg-hyprland.txt`, `pkg-niri.txt`, `pkg-mangowc.txt`, `pkg-labwc.txt`: Window Manager specific packages.


### 3. `assets/` (Templates & UI Customizations)

Stores static assets, browser modifications, and central state templates.

* **`assets/browser/`**: Custom web assets including `userChrome.css` for Firefox UI mods and `newtab.html` for clock homepages (put it in the `~/Documents/` directory).

### 4. `docs/` (Documentation)

* Contains documentation for my dots.
* `Fedora_Guide.md`: Fedora installation guide.
* `architecture.md`: This document, detailing the repository structure and architecture.

### 5. `nix/` (Nix Declarative Module)

* Contains NixOS declarative configuration files for system setup and package management.
* `hakuspace-control.nix`: Main NixOS configuration file.
* `flakes.nix`: Flake configuration online remote helper.
* `flake.nix.template`: Template for creating new Nix flakes for the first time installation NixOS.

```
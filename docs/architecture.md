# HakuSpace Architecture

See Vietnamese translation: [Kiến trúc HakuSpace](VN_architecture.md)

This document is the high-level entry point for the HakuSpace repository. It describes the repository layout, ownership boundaries, and the responsibilities of the main scripts.

For the complete explanation of copy-based deployment, backup helpers, managed destinations, and rollback behavior, see [Dotfiles Copy Management](dotfiles-copy-management.md).

## Repository Layout

```text
hakuspace (root)
├── assets/                    # Static assets, including Firefox customizations
├── docs/                      # Architecture, setup, and dotfiles documentation
├── nix/                       # NixOS configurations and flake templates
├── scripts/                   # Shared shell variables and helper functions
├── install.sh                # First-time setup and configuration deployment
├── update.sh                 # Repository, package, and configuration updates
├── rollback.sh              # Restore a selected configuration backup
└── src/
    ├── home/                 # Versioned home-directory configuration templates
    │   ├── .config/           # Application and window-manager defaults
    │   ├── .local/bin/        # Managed user scripts
    │   ├── hakuspace-control/ # Default custom-control templates
    │   └── .nanorc            # Nano configuration
    └── packages/              # Package lists grouped by purpose and WM
```

## Configuration Ownership

HakuSpace uses ordinary copied files. It does not use Stow, symbolic links, Git worktrees, or live synchronization.

```text
Repository source                  Deployed user configuration
-----------------                  ---------------------------
src/home/.config/*        --copy--> ~/.config/*
src/home/.local/bin/*     --copy--> ~/.local/bin/*
src/home/.nanorc          --copy--> ~/.nanorc
src/home/hakuspace-control/*
                           --copy--> ~/hakuspace-control/*
```

- `src/home/` contains versioned base defaults. Later installation or update operations may replace deployed copies of these files.
- `~/hakuspace-control/` is the primary location for user-specific settings supported by the configuration templates.
- `~/.config` and `~/.local` may contain unrelated user or application files. HakuSpace manages only the destinations deployed by its scripts.
- Editing a deployed file does not update the repository. Editing a repository file does not affect the running session until it is deployed.

See [Dotfiles Copy Management](dotfiles-copy-management.md) for copy semantics, backup structure, customization rules, and detailed script behavior.

## Main Script Responsibilities

### `install.sh`

The first-time setup entry point. It can install dependencies and packages, create required directories, deploy base configuration and selected window-manager files, initialize once-only configurations, deploy scripts, initialize `~/hakuspace-control`, and perform optional system setup.

Existing managed destinations are backed up under `~/.backup/` before they are copied over.

### `update.sh`

The maintenance entry point. It can update the repository to the latest or stable revision, then redeploy managed configuration and scripts. It preserves configuration listed in `ONCE_CONFIGS` during normal updates, while direct edits to other managed base files may be overwritten.

Each deployment creates a timestamped `~/.backup/Backup_*` recovery point for the destinations affected by that operation.

### `rollback.sh`

The recovery entry point. It lets the user select a previous `~/.backup/Backup_*` directory, moves currently managed destinations into a `~/.backup/Rollback_Backup_*` safety directory, and restores the selected backup.

Rollback clears only destinations known to the installer and updater. Unrelated files and directories in `~/.config` and `~/.local` are preserved.

## Deployment Flow

```text
Repository defaults
        │
        ▼
install.sh / update.sh
        │
        ├── backup existing managed destinations
        └── copy selected configuration into $HOME
                    │
                    ▼
              ~/.backup/Backup_*

Selected backup
        │
        ▼
rollback.sh
        │
        ├── move current managed destinations aside
        └── restore selected files and directories
                    │
                    ▼
          ~/.backup/Rollback_Backup_*
```

The repository remains unchanged during deployment and rollback. These scripts manage independent copies in the user's home directory.

## Documentation Map

- [Dotfiles Copy Management](dotfiles-copy-management.md): detailed copy semantics, helper functions, backup structure, install/update/rollback behavior, examples, and trade-offs.
- [Fedora Guide](Fedora_Guide.md): Fedora-specific setup guidance.
- [Project source](../src/): versioned configuration templates and package manifests.

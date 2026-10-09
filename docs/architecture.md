# How Does HakuSpace Work?

See the Vietnamese version: [VN_architecture](vietnamese/VN_architecture.md).

This is an overview for *you* and *AI* to understand what my dotfiles contain and how they are deployed onto your machine.

## Repository Layout

```text
hakuspace (root)
├── assets/                    # External assets; not copied to your machine
├── docs/                      # Project documentation
├── nix/                       # NixOS configuration and flake templates
│
├── scripts/                   # Helper scripts
├── install.sh                 # First-time dotfiles installation script
├── update.sh                  # Dotfiles update script
├── rollback.sh                # Restore dotfiles from a backup
│
└── src/
    ├── home/                  # Main directory containing dotfiles
    │   ├── .config/           # Configuration files for ~/.config
    │   ├── .local/bin/        # Scripts that make up HakuSpace in ~/.local/bin
    │   └── hakucfg/           # Templates for HakuSpace's custom configuration
    │
    └── packages/              # Package lists grouped for installation
```

## How Are the Dotfiles Managed?

HakuSpace uses ordinary copied files. It does not use Stow, symbolic links, Git worktrees, or a live synchronization mechanism.

- `src/home/` recreates the layout of your home directory and contains the configurations and scripts. This is the BASE configuration.
- `~/hakucfg/` is where you put your personal configuration files. In the repository, it is a template that can be deployed to your machine. This is the CUSTOM configuration.
- Editing a deployed copy does not change the repository. Conversely, editing a repository file does not affect the current session until you run `install.sh` or `update.sh`.

## How Do I Use These Dotfiles?

### `install.sh`

- This is the script for the first dotfiles installation. You can run it again later, but doing so is not recommended.
- What does it do?
  - Installs the required packages.
  - Creates the required directories.
  - Copies configuration files and scripts from the repository to your machine.
  - Initializes the once-only configurations, `ONCE_CONFIGS`.
  - Initializes `~/hakucfg` if it does not already exist.
  - Performs optional system setup steps for the first HakuSpace session.
- The script also creates backups of files that will be overwritten during installation. You can find the timestamped backups under `~/.backup/`.

### `update.sh`

- This is the script for updating the dotfiles.
- What does it do?
  - Updates the repository to the latest or stable version.
  - Copies configuration files and scripts from the repository to your machine.
  - Preserves configurations in `ONCE_CONFIGS`; other managed files may be overwritten.
- The script also creates backups of files that will be overwritten during the update. You can find the timestamped backups under `~/.backup/`.

### `rollback.sh`

- This is the script for restoring dotfiles from a backup.
- What does it do?
  - Moves current managed files into `~/.backup/Rollback_Backup_*`.
  - Restores the selected files and directories from the chosen backup.
- It restores only files and directories managed by `install.sh` and `update.sh`. Other files under `~/.config` and `~/.local` are preserved.

Continue reading: [Management](management.md) to understand how dotfiles are deployed and managed safely in your home directory.

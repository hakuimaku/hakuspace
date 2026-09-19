# How Does HakuSpace Work?

See the Vietnamese version: [VN_architecture](./vietnamese/VN_architecture.md).

Here is a quick overview for *you* to understand what's in my dotfiles and how they get installed on your machine.

## Repo Layout

```text
hakuspace (root)
├── assets/                    # External assets; not copied to your machine
├── docs/                      # Docs and guides
├── nix/                       # NixOS config and flake templates
│
├── scripts/                   # Helper scripts
├── install.sh                 # First-time install script
├── update.sh                  # Update script
├── rollback.sh                # Restore from a backup script
├── doctor.sh                  # Checks for broken symlinks and issues
│
└── src/
    ├── core/                  # HakuSpace scripts; linked/copied to ~/.local/bin
    ├── home/                  # Main directory with all the dotfiles
    │   ├── .config/           # Config files for ~/.config
    │   ├── .local/            # Local configurations and state for ~/.local
    │   ├── .themes/           # Custom themes for ~/.themes
    │   └── hakucfg/           # Templates for your personal configs
    │
    └── packages/              # Package lists for installation
```

## How Are Dotfiles Managed?

HakuSpace uses a **Hybrid System**: you can choose between **Deep Symlinking** or **Classic Copying**.
(It doesn't use Stow or Git worktrees).

- `src/home/` acts like your home directory. This is the BASE config.
- `~/hakucfg/` is where you put your personal stuff. It acts as a template in the repo. This is the CUSTOM config.
- Depending on your choice during `install.sh`, your configs are either symlinked (edits sync instantly) or copied (edits stay local).

## How Do I Use These Dotfiles?

### `install.sh` (First-time Setup)
- This is the main script to get everything running. Here is its step-by-step logic:
  - **Phase 1: Prompting:** Asks for your Distro, preferred Window Manager, and deployment mode (Symlink or Copy).
  - **Phase 2: Backup:** Scans your system and safely moves any conflicting files to `~/.backup/Backup_<timestamp>`.
  - **Phase 3: Dependencies:** Reads the text files in `src/packages/` and installs the required packages using your package manager.
  - **Phase 4: Deployment:** 
    - Links or copies everything from `src/home/.config/` and `src/core/` to your machine.
    - Handles the `ONCE_CONFIGS` group (always copied, never symlinked).
    - Initializes your custom `~/hakucfg` space from the template.
  - **Phase 5: Post-install:** Fixes script permissions, sets Fish as default shell, and clears old caches.

### `update.sh` (Applying Updates)
- Run this whenever you pull fresh code from GitHub.
  - **Phase 1: Mode Detection:** Reads `~/.local/state/hakuspace/deploy_mode` to remember if you chose Symlink or Copy.
  - **Phase 2: Backup:** Just like install, it creates a safety net in `~/.backup/` before touching anything.
  - **Phase 3: Smart Sync:** 
    - Redeploys all configs and scripts based on your mode.
    - Intelligently **Skips** the `ONCE_CONFIGS` to preserve your GUI tweaks (like Thunar or btop settings).
    - Ignores your `~/hakucfg/` completely so your personal stuff stays safe.

### `rollback.sh` (The Undo Button)
- Run this if an update breaks your system.
  - **Phase 1: Selection:** Lists all available backups in `~/.backup/` and lets you pick one (defaults to the newest).
  - **Phase 2: Safe Cleanup:** 
    - Carefully removes current HakuSpace symlinks. This prevents accidental dereferencing which could wipe out files inside the Git repo.
  - **Phase 3: Restoration:** Copies all files from the chosen backup back to their exact original locations in `~/.config` and `~/.local/bin`.

### `doctor.sh` (The Health Checker)
- A diagnostic tool, incredibly useful if you chose Symlink mode.
  - **Broken Symlinks Scan:** Checks your `~/.config` and `~/.local/bin` for symlinks that point to nowhere (because the target file was deleted or moved), and highlights them in red.
  - **Overwritten Files Scan:** Detects files that should be symlinks managed by HakuSpace, but were somehow turned into real files (usually because your text editor broke the symlink when saving). The doctor points them out and tells you to run `update.sh` to fix them.

## Dive Deeper (Table of Contents)

To fully understand how HakuSpace works under the hood, read through our detailed documentation in the following order:

1. **[Management](management.md)**: Understand the Hybrid Deployment system (Symlink vs Copy) and how your configurations are safely deployed.
2. **[Core Libraries](core/lib.md)**: The foundational state management and Window Manager abstraction scripts.
3. **[Theming Engine](core/theme.md)**: How HakuSpace magically extracts colors from your wallpaper and applies them live.
4. **[System Management](core/sys.md)**: The scripts controlling lock screens, smart idle prevention, and safe session exits.
5. **[Utilities](core/util.md)**: Your daily toolbelt (screenshots, nightlight, desktop widgets).
6. **[Haku Menu](core/menu.md)**: The modular, multi-tabbed Rofi launcher.
7. **[Mini-Apps](core/app.md)**: The custom native apps built for HakuSpace (Dockbar, Desktop Icons, Cava Underbar).

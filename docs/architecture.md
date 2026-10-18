# How Does HakuSpace Work?

See the Vietnamese version: [VN_architecture](./vietnamese/VN_architecture.md).

Here is a quick overview for *you* to understand what's in my dotfiles and how they get installed on your machine.

## Repo Layout

```text
hakuspace (root)
├── assets/                    # External assets; not copied to your machine
├── docs/                      # Docs and guides
├── nix/                       # NixOS config and flake templates
├── scripts/                   # Helper modules for the installer/updater
├── tests/                     # Automated test suites
│
├── install.sh                 # First-time install script
├── update.sh                  # Update script
├── link.sh                    # Link specific config modules
├── unlink.sh                  # Safely remove HakuSpace symlinks
├── packages.sh                # Install specific package groups
├── rollback.sh                # Restore from a backup script
├── doctor.sh                  # Checks for broken symlinks and issues
│
└── src/
    ├── core/                  # HakuSpace scripts; linked/copied flat to ~/.local/bin
    ├── home/                  # Main directory with all the dotfiles
    │   ├── .config/           # Config files for ~/.config (quickshell, hypr, niri, waybar, ...)
    │   ├── .local/            # Local configurations and state for ~/.local
    │   ├── .themes/           # Custom themes for ~/.themes
    │   └── hakucfg/           # Templates for your personal configs
    │
    └── packages/              # Package lists for installation
```

## Two Desktop Shells: `Hikai` & `Classic`

HakuSpace comes with two desktop shell modes that you can switch between anytime without losing your theme or settings:

- **Hikai (Quickshell):** The modern, all-in-one desktop shell built natively with Quickshell (`src/home/.config/quickshell/hakuspace`). It handles your Top Bar, Dashboard, Sidebar, Notification Center, Haku Menu, Wallpaper Picker, OSDs, and even a built-in Settings & Config Editor—all in one place.
- **Classic (Waybar + Rofi + SwayNC):** The original script-powered setup. It stays right there as a rock-solid classic experience or fallback whenever you want it (just press `SUPER + ESCAPE` or run `haku_backend.sh --toggle`).

To make both shells work together without duplicating logic, the scripts inside `src/core/` are split into three simple layers (even though they all get deployed flat into `~/.local/bin`):
- **`facade/`**: The familiar commands bound to your hotkeys (like `record.sh` or `wallpaper_select.sh`). They check which shell you're using and route the action automatically.
- **`frontend/classic/`**: Opens the Rofi menus when you're in Classic mode.
- **`backend/`**: The actual brain (`*_ctl.sh`, `*.py`) that does the heavy lifting behind the scenes for both Hikai and Classic.

## How Are Dotfiles Managed?

HakuSpace uses a **Hybrid System**: you can choose between **Deep Symlinking** or **Classic Copying**.
(It doesn't use Stow or Git worktrees).

- `src/home/` acts like your home directory. This is the BASE config.
- `~/hakucfg/` is where you put your personal stuff. It acts as a template in the repo. This is the CUSTOM config.
- Depending on your choice during `install.sh`, your configs are either symlinked (edits sync instantly) or copied (edits stay local).

## How Do I Use These Dotfiles?

### `install.sh` (First-time Setup)
- This is the main script to get everything running. The automatic installer is Arch/yay-focused. Under the hood, it coordinates the helper scripts in `scripts/` step by step:
  - **Phase 1: Selection & Preparation:** Asks for your preferred Window Manager(s) (Hyprland, Niri, MangoWM, or Labwc) and deployment mode (Symlink or Copy).
  - **Phase 2: Dependencies & Packages:** Checks for `yay`, reads the text files in `src/packages/`, and installs the package groups for your selected WMs. (NixOS-specific integration in step 4.1 is detected separately when `nixos-rebuild` is present; Fedora and NixOS setups are currently legacy/unsupported).
  - **Phase 3: Deployment:**
    - Creates base directories and links or copies everything from `src/home/.config/` and `src/core/` to your machine (using `scripts/registry.sh` as the single list of targets).
    - Handles the `ONCE_CONFIGS` group (always copied, never symlinked).
    - Initializes your custom `~/hakucfg` space from the template.
  - **Phase 4: Post-install:** Installs optional themes/icons/wallpapers (`scripts/assets.sh`), initializes state, syncs `~/hakucfg`, and configures your shell and display manager.

### `update.sh` (Applying Updates)
- Run this whenever you pull fresh code from GitHub.
  - **Phase 1: Repository Update:** Prompts you to choose between LATEST (`main` branch) or STABLE (latest tag) to update the repository.
  - **Phase 2: Backup & Mode Detection:** Creates a safety net in `~/.backup/` before touching anything. It then heuristically scans your currently deployed files to determine whether you are using Symlink or Copy mode.
  - **Phase 3: Smart Sync:**
    - Redeploys all configs and scripts based on your mode.
    - Intelligently **Skips** the `ONCE_CONFIGS` to preserve your GUI tweaks (like Thunar or btop settings).
    - **`~/hakucfg` is preserved by default:** Missing template files are seeded, and version-mismatched `setting.sh` is only replaced after user confirmation (with an automatic backup).
    - Note: explicitly skips `OPTIONAL` packages; they are only offered during initial installation.

### `link.sh`, `unlink.sh` & `packages.sh` (Modular Controls)
- Don't want to run the full installer? You can manage individual pieces whenever you want:
  - **`packages.sh`:** Install only the package groups you care about (e.g., `./packages.sh core niri`).
  - **`link.sh`:** Link just a single module (e.g., `./link.sh quickshell core`) or everything (`./link.sh --all`).
  - **`unlink.sh`:** Cleanly removes symlinks that belong to HakuSpace without ever deleting your real files or app data.

### `rollback.sh` (The Undo Button)
- Run this if an update breaks your system.
  - **Phase 1: Selection:** Lists all available backups in `~/.backup/` and lets you pick one (defaults to the newest).
  - **Phase 2: Safe Cleanup:**
    - Carefully removes current HakuSpace symlinks. This prevents accidental dereferencing which could wipe out files inside the Git repo.
  - **Phase 3: Restoration:** Copies all files from the chosen backup back to their exact original locations in `~/.config` and `~/.local/bin`.

### `doctor.sh` (The Health Checker)
- A read-only diagnostic tool, incredibly useful if you chose Symlink mode.
  - **Broken Symlinks Scan:** Checks your `~/.config` and `~/.local/bin` for symlinks that point to nowhere (because the target file was deleted or moved), and highlights them in red.
  - **Overwritten Files Scan:** Detects files that should be symlinks managed by HakuSpace, but were somehow turned into real files (usually because your text editor broke the symlink when saving). The doctor points them out and tells you the exact command to fix them.

## Dive Deeper (Table of Contents)

To fully understand how HakuSpace works under the hood, read through our detailed documentation in the following order:

1. **[Management](management.md)**: Understand the Hybrid Deployment system (Symlink vs Copy), modular install, and how to safely uninstall.
2. **[Core Libraries](core/lib.md)**: The foundational state management, backend helpers, and Window Manager abstraction scripts.
3. **[Theming Engine](core/theme.md)**: How HakuSpace magically extracts colors from your wallpaper and syncs them across your apps and icons.
4. **[System Management](core/sys.md)**: The scripts controlling lock screens, smart idle prevention, and safe session exits.
5. **[Utilities](core/util.md)**: Your daily toolbelt (screenshots, screen recording, nightlight, desktop widgets).
6. **[Haku Menu](core/menu.md)**: The central command hub across both Classic Rofi and Hikai Quickshell.
7. **[Mini-Apps](core/app.md)**: The custom native apps built for HakuSpace (Taskbar, Desktop Icons, Rounded Screen, Edge Trigger, Cava Underbar).
8. **[NixOS Integration](nixos.md)**: Details on the Offline and Online Flake modes for NixOS users.

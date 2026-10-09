# Directory Structure & Architecture Specification

This document provides a detailed breakdown of the `hakuspace` repository layout, explaining the exact responsibility and scope of each directory and core execution script.

```text
hakuspace (root)
├── assets/
│   ├── browser/             # Custom userChrome.css & newtab.html for Firefox
│   └── hakuspace-control/   # Templates for hakuspace-control
│
├── docs/                    # Documentation for my dots
├── nix/                     # Declarative Nix configuration
├── scripts/                 # Helper libraries for install.sh and update.sh
│
└── src/                     # Core configuration modules, searching for my dotfiles here
    ├── common/              # Common configurations shared across all environments
    ├── wm/                  # Window manager configurations (Hyprland, Niri, Mangowc, Labwc)
    └── packages/            # Package lists to install
```

---

## Detailed Directory Breakdown

### Root Execution Scripts (`/`)

* **`install.sh`**: The primary installation script, use this for first-time setup. Handles environment detection, package installation, setup configuration from `src/`, and deploying initial control templates from `assets/`.
* **`update.sh`**: The update script. Pulls the latest repository changes, updates configurations and ensures hakuspace-control templates are current.

### 1. `scripts/` (Core Helper Libraries)

This directory acts strictly as an internal backend for `install.sh` and `update.sh`. It contains no executable entry points.

* **`functions.sh`**: Contains reusable Bash functions.
* **`variables.sh`**: Defines global variables and paths used throughout the scripts.

### 2. `src/` (Dotfiles & Package Manifests)

The primary search target and storage location for all managed user configurations.

* **`src/common/`**: Houses all application dotfiles that remain uniform regardless of the chosen Window Manager (e.g., Zsh, Kitty, Waybar, Hypridle, Hyprlock, etc.).
* **`src/wm/`**: Holds isolated configuration profiles dedicated to specific Wayland compositors and Window Managers (`hyprland/`, `niri/`, `mangowc/`, `labwc/`).
* **`src/packages/`**: Contains package lists for installation:
    * `pkg-core.txt`: Core packages required for my setup.
    * `pkg-service.txt`: Service packages: brightnessctl, bluetooth, btop, etc.
    * `pkg-optional.txt`: Optional packages: Browser, Terminal Decorations, Screen Recording, etc.
    * `pkg-hyprland.txt`, `pkg-niri.txt`, `pkg-mangowc.txt`, `pkg-labwc.txt`: Window Manager specific packages.


### 3. `assets/` (Templates & UI Customizations)

Stores static assets, browser modifications, and central state templates.

* **`assets/browser/`**: Custom web assets including `userChrome.css` for Firefox UI mods and `newtab.html` for clock homepages (put it in the `~/Documents/` directory).
* **`assets/hakuspace-control/`**: Template files for the Hakuspace Control Center. These serve as the baseline configuration state deployed to the runtime environment.

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
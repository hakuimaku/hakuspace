# Directory Structure & Architecture Specification

This document provides a detailed breakdown of the `hakuspace` repository layout, explaining the exact responsibility and scope of each directory and core execution script.

```text
hakuspace (root)
├── assets/
│   └── browser/                # Custom userChrome.css & newtab.html for Firefox
│
├── docs/                       # Documentation for my dots
├── nix/                        # Declarative Nix configuration
├── scripts/                    # Helper libraries for install.sh and update.sh
│
└── src/                        # Core configuration modules, searching for my dotfiles here
    ├── home/                   # Simulation of the home directory structure for dotfiles
    │   ├── hakuspace-control/  # Templates for hakuspace-control
    │   ├── .config/            # hakuspace configuration files (dotfiles)
    │   └── .local/             # hakuspace local files (bin)
    │
    └── packages/               # Package lists to install
```

---

## Detailed Directory Breakdown

### Root Execution Scripts (`/`)

* **`install.sh`**: The primary installation script, use this for first-time setup. Handles environment detection, package installation, setup configuration from `src/`.
* **`update.sh`**: The update script. Pulls the latest repository changes, updates configurations and ensures hakuspace-control templates are current.

### 1. `scripts/` (Core Helper Libraries)

This directory acts strictly as an internal backend for `install.sh` and `update.sh`. It contains no executable entry points.

* **`functions.sh`**: Contains reusable Bash functions.
* **`variables.sh`**: Defines global variables and paths used throughout the scripts.

### 2. `src/` (Dotfiles & Package Manifests)

The primary search target and storage location for all managed user configurations.

* **`src/home/`**: Simulates the home directory structure for dotfiles. Contains:
    * **`hakuspace-control/`**: Template files for the Hakuspace Control Center.
    * **`.config/`**: Configuration files for various applications.
    * **`.local/`**: Local binaries and scripts.
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
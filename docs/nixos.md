# NixOS Integration

> [!WARNING]
> **Do not use this right now!** I haven't tested HakuSpace on NixOS (or Fedora) for a long time, and my current development is focused **only on Arch Linux**. Installing on NixOS right now will almost certainly break your experience!

The sections below document the retained legacy implementation. The current `install.sh` stops at the Arch dependency gate on NixOS, so these flows should not be treated as currently supported installer behavior. Instead of just deploying dotfiles, the integration was designed to connect directly with your NixOS system configuration through two deployment modes.

The NixOS configuration templates are stored in the `nix/` directory at the root of the repo.

## 1. Offline Mode (Local Config)
If your system uses a traditional `/etc/nixos/configuration.nix` setup without Flakes:
- The retained `scripts/nixos.sh` install flow was designed to prompt for Offline Mode.
- It copies `nix/hakuspace-config.nix` into `/etc/nixos/hakuspace-config.nix`.
- It then attempts to automatically inject `./hakuspace-config.nix` into the `imports = [ ... ];` block of your `/etc/nixos/configuration.nix` using `sed`.
- You can manually run `sudo nixos-rebuild switch` to apply the changes.
- During `update.sh` (Block 4), it was designed to detect this setup and ask if you want to overwrite `hakuspace-config.nix` with the latest version from the repo and rebuild.

## 2. Online Mode (Flakes)
If your system uses a Flake-based setup (`/etc/nixos/flake.nix`):
- The retained `scripts/nixos.sh` install flow was designed to prompt for Online Remote Mode.
- It copies `nix/flake.nix.example` to `/etc/nixos/flake.nix` (Warning: This will overwrite an existing `flake.nix`, so it prompts you first).
- This template relies on the `hakuspace` flake input, pulling NixOS modules directly from this GitHub repository.
- During `update.sh`, if it detects the `hakuspace.nixosModules.default` pattern in your `flake.nix`, it was designed to prompt to run `sudo nix flake update` and rebuild the system automatically.

## Notes
- These deployment blocks are located in step 4.1 of `install.sh` and block 4 of `update.sh`, but are not reached on stock NixOS systems due to the earlier Arch dependency check.
- The `.nix` files inside `nix/myown/` are personal files used by the author and are not deployed by the generic installers.

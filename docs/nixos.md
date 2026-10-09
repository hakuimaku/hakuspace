# NixOS Integration

HakuSpace offers native support for NixOS. Instead of just installing dotfiles, it integrates directly with your NixOS system configuration through two distinct deployment modes.

The NixOS configuration templates are stored in the `nix/` directory at the root of the repo.

## 1. Offline Mode (Local Config)
If your system uses a traditional `/etc/nixos/configuration.nix` setup without Flakes:
- `install.sh` will prompt you for Offline Mode.
- It copies `nix/hakuspace-config.nix` into `/etc/nixos/hakuspace-config.nix`.
- It then attempts to automatically inject `./hakuspace-config.nix` into the `imports = [ ... ];` block of your `/etc/nixos/configuration.nix` using `sed`.
- You can manually run `sudo nixos-rebuild switch` to apply the changes.
- During `update.sh` (Block 4), it will detect this setup and ask if you want to overwrite `hakuspace-config.nix` with the latest version from the repo and rebuild.

## 2. Online Mode (Flakes)
If your system uses a Flake-based setup (`/etc/nixos/flake.nix`):
- `install.sh` will prompt you for Online Remote Mode.
- It copies `nix/flake.nix.example` to `/etc/nixos/flake.nix` (Warning: This will overwrite an existing `flake.nix`, so it prompts you first).
- This template relies on the `hakuspace` flake input, pulling NixOS modules directly from this GitHub repository.
- During `update.sh`, if it detects the `hakuspace.nixosModules.default` pattern in your `flake.nix`, it will prompt to run `sudo nix flake update` and rebuild the system automatically.

## Notes
- These deployment blocks are handled in Phase 3.1 of `install.sh` and Phase 4 of `update.sh`.
- The `.nix` files inside `nix/myown/` are personal files used by the author and are not deployed by the generic installers.

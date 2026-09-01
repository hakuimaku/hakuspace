{
  description = "Haku Space -- Hyprland / Niri / MangoWM / Labwc dotfiles";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  /*
    A flake at the REPOSITORY ROOT, which is what `github:hakuimaku/hakuspace`
    resolves to. nix/flake.nix stays exactly as it was, so anyone already using
    `github:hakuimaku/hakuspace?dir=nix` keeps working -- but the plain URL
    errors with "flake.nix does not exist" today, and a root flake is also the
    only place a derivation can see src/ and assets/. A flake's source is the
    directory containing it, so nix/package.nix reaching up to ../src would be
    reaching outside the flake.
  */
  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules = {
        default = ./nix/hakuspace-config.nix;
        hakuspace = ./nix/hakuspace-config.nix;
      };

      /*
        The declarative half, for people who would rather not run install.sh.

        hakuspace-config.nix installs PACKAGES and system services; it has
        never placed a single dotfile. That is fine on a machine managed with
        install.sh, and it is the one gap on a machine managed entirely by Nix,
        where an imperatively-copied ~/.config is exactly the state a rebuild
        cannot reproduce.

        packages.hakuspace turns the tree into a derivation with its scripts'
        dependencies wrapped onto PATH, and homeModules.hakuspace links it into
        ~/.config. The config files are installed UNMODIFIED, so both routes
        produce the same desktop and neither forks the configs from the other.
      */
      packages = forAllSystems (pkgs: rec {
        default = hakuspace;
        hakuspace = pkgs.callPackage ./nix/package.nix { };
      });

      homeModules = {
        default = self.homeModules.hakuspace;
        hakuspace =
          { pkgs, lib, ... }:
          {
            imports = [ ./nix/home-module.nix ];
            programs.hakuspace.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.hakuspace;
          };
      };

      # Older spelling; home-manager accepts either.
      homeManagerModules = self.homeModules;
    };
}

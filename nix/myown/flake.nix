{
  description = "System Configuration powered by Hakuspace NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    hakuspace = {
      url = "github:hakuimaku/hakuspace?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fcitx5-lotus = {
      url = "github:LotusInputMethod/fcitx5-lotus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, zen-browser, fcitx5-lotus, hakuspace, ... }@inputs: {
    nixosConfigurations = {
    nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          unstable = import nixpkgs-unstable {
            system = "x86_64-linux";
          };
        };
        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          hakuspace.nixosModules.default

          ({ pkgs, ... }: {
            environment.systemPackages = [
            zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
            ];
          })
        ];
      };
    };
  };
}

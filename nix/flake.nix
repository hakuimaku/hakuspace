{
  description = "Hakuspace NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules = {
	  default = ./hakuspace-config.nix;
	  hakuspace = ./hakuspace-config.nix;
	};
  };
}
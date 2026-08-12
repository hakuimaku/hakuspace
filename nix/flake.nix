{
	description = "Hakuspace NixOS Configuration";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs, ... }: {
		nixosModules = {
			default = ./hakuspace-config.nix;
			hakuspace = ./hakuspace-config.nix;
		};
	};
}
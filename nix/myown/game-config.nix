{ config, pkgs, inputs, ... }:

let
  aagl = import (builtins.fetchTarball {
    url = "https://github.com/ezKEa/aagl-gtk-on-nix/archive/release-26.05.tar.gz";
    sha256 = "sha256:1m3fzyasjl3xsvz31rz6j8g415632i6s58h7sc2lpav0irl6bw1c";
  });
in

{
  imports =
    [
      #./cachix.nix # Game
      aagl.module # Game
    ];

  environment.systemPackages = with pkgs; [
    prismlauncher
    modrinth-app
  ];

  nix.settings = aagl.nixConfig; # Set up Cachix
  programs.honkers-railway-launcher.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}

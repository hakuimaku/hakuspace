# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./game-config.nix
      inputs.fcitx5-lotus.nixosModules.fcitx5-lotus # lotus
    ];

  # ==========================================================
  # Nixpkgs unstable for hypridle by flake input
  # ==========================================================
  nixpkgs.overlays = [
    (final: prev: {
      hypridle =
        inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.hypridle;
    })
  ];
  
  # ==========================================================
  # System packages
  # ==========================================================
  environment.systemPackages = with pkgs; [
    localsend
    onlyoffice-desktopeditors
  ];

  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      nerd-fonts.monofur
      corefonts
      vista-fonts
    ];
  };

  # ==========================================================
  # Services
  # ==========================================================
  # Display manager
  services.displayManager.ly.enable = true;

  # Cloudflare
  services.cloudflare-warp.enable = true;

  # lotus
  services.fcitx5-lotus = {
    enable = true;
    users = [ "hakuimaku" ];
  };

  # Input method
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-bamboo
      fcitx5-gtk
      qt6Packages.fcitx5-qt
      qt6Packages.fcitx5-unikey
    ];
  };

  # ==========================================================
  # Disk
  # ==========================================================
  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/Data" =
    {
      device = "/dev/disk/by-uuid/524697E34697C5DF";
      fsType = "ntfs-3g";
      options = [ "defaults" "nofail" ];
    };

  # ==========================================================
  # System configuration
  # ==========================================================
  
  # Hardware graphic
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # Bootloader setup via GRUB
  boot.loader.systemd-boot.enable = false;
  boot.loader.limine.enable = false;

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    backgroundColor = "#000000";
    splashImage = null;
    fontSize = 32;
    font = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Ho_Chi_Minh";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN";
    LC_IDENTIFICATION = "vi_VN";
    LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN";
    LC_NAME = "vi_VN";
    LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN";
    LC_TELEPHONE = "vi_VN";
    LC_TIME = "vi_VN";
  };
  
  # Pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."hakuimaku" = {
    isNormalUser = true;
    description = "hakuimaku";
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
    packages = with pkgs; [];
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  hardware.bluetooth.settings = {
    General = {
      Experimental = true;
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}

#       __          __                                  
#      / /_  ____ _/ /____  ___________  ____ _________ 
#     / __ \/ __ `/ //_/ / / / ___/ __ \/ __ `/ ___/ _ \
#    / / / / /_/ / ,< / /_/ (__  ) /_/ / /_/ / /__/  __/
#   /_/ /_/\__,_/_/|_|\__,_/____/ .___/\__,_/\___/\___/ 
#                              /_/                      
#   NixOS configuration file for hakuspace

{ config, pkgs, lib, ... }:

let
  cfg = config.hakuspace;
in
{
  # Options ================================================
  options.hakuspace = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Hakuspace NixOS base configuration";
    };

    enableFishShell = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Fish with Starship and Hakuspace default configuration and set as default shell";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Experimental features
      nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
          
      # Hardware Graphics for Wayland Compositors
      hardware.graphics.enable = lib.mkDefault true;

      # Clean temporary files on boot
      boot.tmp.cleanOnBoot = lib.mkDefault true;

      # Programs ================================================
      nixpkgs.config.allowUnfree = lib.mkDefault true;
      programs.firefox.enable = lib.mkDefault true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Thunar File Manager
      programs.xfconf.enable = lib.mkDefault true;
      programs.thunar.enable = lib.mkDefault true;
      programs.thunar.plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
      services.udisks2.enable = lib.mkDefault true;
      services.gvfs.enable = lib.mkDefault true;
      services.tumbler.enable = lib.mkDefault true;

      # Nano Editor
      programs.nano = {
        enable = lib.mkDefault true;
        syntaxHighlight = true;
        nanorc = ''
          set tabsize 2
          set tabstospaces
          set mouse
        '';
      };

      # Desktop Environment / Window Manager
      programs.hyprland.enable = lib.mkDefault true;
      programs.niri.enable = lib.mkDefault true;
      programs.mangowc.enable = lib.mkDefault true;
      programs.labwc.enable = lib.mkDefault true;

      # Polkit Authentication Agent
      security.polkit.enable = lib.mkDefault true;

      # Packages ================================================
      environment.systemPackages = with pkgs; [
        # Common Utilities
        gsettings-desktop-schemas
        glib
        pulseaudio
        libnotify
        networkmanagerapplet
        playerctl
        file
        go
        ffmpeg

        # Core packages
        git
        rofi
        waybar
        kitty
        swaynotificationcenter
        fastfetch
        awww
        mpvpaper
        hyprlock
        hypridle
        hyprpicker
        hyprsunset
        gammastep
        jq
        imagemagick
        wlr-randr
        wl-clipboard
        cliphist
        grim
        slurp
        mpv
        imv
        nwg-look
        xdg-utils
        mate-polkit
        xhost
        xwayland-satellite
        file-roller
        p7zip
        unrar
        unzip
        zip
        rofi-emoji
        wl-screenrec
        wget
        cava
        tty-clock
        lavat
        chafa
        pipes
        cmatrix
        brightnessctl
        ncdu
        gparted
        btop
        pavucontrol
        vscode

        # Script python needed
        (pkgs.symlinkJoin {
          name = "python3-path-env";
          paths = [ (python3.withPackages (ps: with ps; [ colorthief pygobject3 ])) ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/python3 \
              --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" [ pango.out harfbuzz gtk3 gtk-layer-shell gdk-pixbuf librsvg atk cairo glib gobject-introspection ]}" \
              --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pango harfbuzz gtk3 gdk-pixbuf librsvg atk cairo glib ]}"
          '';
        })
        gobject-introspection
        gtk3
        gtk-layer-shell
        pango
        harfbuzz
        librsvg
        gdk-pixbuf
        atk
        cairo
      ];

      environment.variables.GSETTINGS_SCHEMA_DIR =
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/"
        + "${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

      fonts = {
        fontconfig.enable = lib.mkDefault true;
        packages = with pkgs; [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          nerd-fonts.jetbrains-mono
        ];
      };

      xdg.portal = {
        enable = lib.mkDefault true;
        extraPortals = [
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-wlr 
          pkgs.xdg-desktop-portal-gnome
        ];

        config = lib.mkDefault {
          hyprland.default = [ "hyprland" "gtk" ];
          niri.default = [ "gnome" "gtk" ];
          mango.default = [ "wlr" "gtk" ];
          labwc.default = [ "wlr" "gtk" ];
        };
      };
    }

    # Fish Shell & Starship Configuration Block
    (lib.mkIf cfg.enableFishShell {
      programs.fish.enable =  true;
      programs.starship.enable = true;
      users.defaultUserShell = pkgs.fish;

      environment.systemPackages = with pkgs; [
        eza
        lazygit
        zoxide
        direnv
      ];
    })
  ]);
}
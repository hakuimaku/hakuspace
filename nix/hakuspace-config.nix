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

        enableDefaultShell = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Set Zsh as default user shell";
        };
    };

    config = lib.mkIf cfg.enable {
        # Experimental features
        nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
        
        # Hardware Graphics for Wayland Compositors
        hardware.graphics.enable = lib.mkDefault true;

        # Programs ================================================
        nixpkgs.config.allowUnfree = lib.mkDefault true;
        programs.firefox.enable = lib.mkDefault true;

        # Zsh Shell
        programs.zsh.enable = lib.mkDefault true;
        environment.shells = with pkgs; [ zsh ];
        users.defaultUserShell = lib.mkIf cfg.enableDefaultShell (lib.mkForce pkgs.zsh);

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
        security.polkit.enable = lib.mkDefault true;

        # Nano Editor
        programs.nano = {
            enable = lib.mkDefault true;
            syntaxHighlight = true;
            nanorc = ''
                set tabsize 4
                set tabstospaces
                set mouse
            '';
        };

        # Desktop Environment / Window Manager
        programs.hyprland.enable = lib.mkDefault true;

        # Packages ================================================
        environment.systemPackages = with pkgs; [
            (python3.withPackages (ps: with ps; [
                colorthief
                pygobject3
            ]))
            gtk3
            pango
            gdk-pixbuf
            atk
            harfbuzz
            gobject-introspection
            gtk-layer-shell
            glib
            libnotify
            file
            git
            vscode
            waybar
            rofi
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
            sway-audio-idle-inhibit
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
            mangowc
            labwc
        ];

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
    };
}
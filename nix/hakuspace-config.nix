#       __          __                                  
#      / /_  ____ _/ /____  ___________  ____ _________ 
#     / __ \/ __ `/ //_/ / / / ___/ __ \/ __ `/ ___/ _ \
#    / / / / /_/ / ,< / /_/ (__  ) /_/ / /_/ / /__/  __/
#   /_/ /_/\__,_/_/|_|\__,_/____/ .___/\__,_/\___/\___/ 
#                              /_/                      
#   NixOS configuration file for hakuspace

{ config, pkgs, ... }:

{
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    
    # Programs ================================================
    nixpkgs.config.allowUnfree = true;
    programs.firefox.enable = true;

    # Zsh Shell
    programs.zsh.enable = true;
    users.defaultUserShell = pkgs.zsh;

    # Thunar File Manager
    programs.xfconf.enable = true;
    programs.thunar.enable = true;
    programs.thunar.plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
    ];
    services.udisks2.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    security.polkit.enable = true;

    # Nano Editor
    programs.nano = {
        enable = true;
        syntaxHighlight = true;
        nanorc = ''
            set tabsize 4
            set tabstospaces
            set mouse
        '';
    };

    # Hyprland and Niri
    programs.hyprland.enable = true;
    #programs.niri.enable = true;

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
        fontconfig.enable = true;
        packages = with pkgs; [
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
            nerd-fonts.jetbrains-mono
        ];
    };

    xdg.portal = {
        enable = true;
        extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr 
        pkgs.xdg-desktop-portal-gnome
        ];

        config = {
            hyprland = {
                default = [ "hyprland" "gtk" ];
            };
            niri = {
                default = [ "gnome" "gtk" ];
            };
            mango = {
                default = [ "wlr" "gtk" ];
            };
            labwc = {
                default = [ "wlr" "gtk" ];
            };
        };
    };
}

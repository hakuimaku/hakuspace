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

        enableZshShell = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Zsh with Hakuspace default configuration and set as default shell";
        };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
        {
        # Experimental features
        nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
            
        # Hardware Graphics for Wayland Compositors
        hardware.graphics.enable = lib.mkDefault true;

        # Programs ================================================
        nixpkgs.config.allowUnfree = lib.mkDefault true;
        programs.firefox.enable = lib.mkDefault true;
        services.power-profiles-daemon.enable = lib.mkDefault true;
        services.displayManager.ly.enable = lib.mkDefault true;

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
        programs.mango.enable = lib.mkDefault true;
        programs.labwc.enable = lib.mkDefault true;

        # Polkit Authentication Agent
        security.polkit.enable = lib.mkDefault true;

        # Packages ================================================
        environment.systemPackages = with pkgs; [
            (python3.withPackages (ps: with ps; [
                colorthief
                pygobject3
            ]))
            gtk3
            pango
            gobject-introspection
            gtk-layer-shell
            glib
            libnotify
            playerctl
            file
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
            vscode
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
        }

        # Zsh Shell Configuration Block
        (lib.mkIf cfg.enableZshShell {
            environment.shells = with pkgs; [ zsh ];
            users.defaultUserShell = lib.mkForce pkgs.zsh;
            
            programs.zsh = {
                enable = true;
                enableCompletion = true;
                autosuggestions.enable = true;
                syntaxHighlighting.enable = true;
                
                histSize = 100000;
                histFile = "$HOME/.zsh_history";
                
                setOptions = [
                    "APPEND_HISTORY"
                    "INC_APPEND_HISTORY"
                    "HIST_IGNORE_DUPS"
                    "HIST_IGNORE_ALL_DUPS"
                    "HIST_REDUCE_BLANKS"
                    "HIST_VERIFY"
                ];
                
                shellAliases = {
                    haku = "~/.local/bin/haku.sh";
                    menu = "~/.local/bin/hakumenu.sh";
                    openconfig = "~/.local/bin/open_config.sh";
                    nix-clean = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3 && sudo nix-store --gc";
                    nix-switch = "sudo nixos-rebuild switch";
                    nix-dir = "cd /etc/nixos";
                };
                
                ohMyZsh = {
                    enable = true;
                    theme = "agnoster";
                    plugins = [ "git" ];
                };
                
                interactiveShellInit = ''
                    export CASE_SENSITIVE="true"
                    export HYPHEN_INSENSITIVE="true"
                    export DISABLE_LS_COLORS="false"
                    export DISABLE_AUTO_TITLE="true"
                    export ENABLE_CORRECTION="true"
                    export DISABLE_MAGIC_FUNCTIONS="false"
                    export COMPLETION_WAITING_DOTS="true"
                    export DISABLE_UNTRACKED_FILES_DIRTY="false"
                    export HIST_STAMPS="yyyy-mm-dd"
                    export SAVEHIST=100000
                    
                    export PATH="$HOME/.local/bin:$HOME/.dotnet:$HOME/.dotnet/tools:$HOME/go/bin:$HOME/.cargo/bin:$PATH"
                    export GTK_USE_PORTAL=1
                    export MOZ_ENABLE_WAYLAND=1
                    export QT_QPA_PLATFORMTHEME=qt6ct
                    export DOTNET_ROOT=$HOME/.dotnet
                    
                    export AGNOSTER_DIR_BG="blue"
                    export AGNOSTER_GIT_DIRTY_BG="black"
                    export AGNOSTER_GIT_DIRTY_FG="white"
                    export AGNOSTER_CONTEXT_BG="#010101"
                    export AGNOSTER_CONTEXT_FG="blue"
                    export AGNOSTER_DIR_FG="#010101"
                '';
            };
        })
    ]);
}
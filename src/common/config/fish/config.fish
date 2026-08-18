if status is-interactive
    # Starship custom prompt
    command -v starship &> /dev/null && starship init fish | source

    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # Better ls
    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    # Path
    fish_add_path ~/.local/bin
    fish_add_path ~/.cargo/bin
    fish_add_path ~/go/bin

    # Env
    set -gx GTK_USE_PORTAL 1
    set -gx MOZ_ENABLE_WAYLAND 1
    set -gx QT_QPA_PLATFORMTHEME qt6ct
    set -gx DOTNET_ROOT $HOME/.dotnet

    # Abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    abbr c 'clear'
    abbr h 'history'
    abbr haku '~/.local/bin/haku.sh'
    abbr menu '~/.local/bin/hakumenu.sh'
    abbr openconfig '~/.local/bin/open_config.sh'
    abbr pacsize 'expac -H M "%m\t%n" $(\pacman -Qeq) | sort -h -r'
    abbr pacsizefull 'expac -H M "%m\t%n" | sort -h -r'
    abbr nc 'sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3 && sudo nix-store --gc'
    abbr nrb 'sudo nixos-rebuild switch'
    abbr nd 'cd /etc/nixos'
end
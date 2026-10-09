# Zsh Wiki: https://github.com/ohmyzsh/ohmyzsh/wiki

# Make completion case-sensitive (A ≠ a)
CASE_SENSITIVE="true"

# Treat hyphens and underscores as equivalent in completion ( - ~= _ )
HYPHEN_INSENSITIVE="true"

# Keep colors enabled for ls output
DISABLE_LS_COLORS="false"

# Prevent Oh My Zsh from auto-changing terminal window title
DISABLE_AUTO_TITLE="true"

# Enable command auto-correction for mistyped commands
ENABLE_CORRECTION="true"

# Keep magic functions enabled (URL/paste smart handling remains active)
DISABLE_MAGIC_FUNCTIONS="false"

# Show visual dots while waiting for completion results
COMPLETION_WAITING_DOTS="true"

# Keep checking untracked files for Git dirty status (more accurate, can be slower)
DISABLE_UNTRACKED_FILES_DIRTY="false"

# Set the format of timestamps in the history file (default: "mm/dd/yyyy")
HIST_STAMPS="yyyy-mm-dd"

# Plugins to load
# plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Quickly use script in local bin folder
export PATH="$HOME/.local/bin:$PATH"

# Custom environment variables
export GTK_USE_PORTAL=1
export MOZ_ENABLE_WAYLAND=1
export DOTNET_ROOT=$HOME/.dotnet
export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools
export PATH=$PATH:$HOME/go/bin
export PATH=$PATH:$HOME/.cargo/bin

# Set alias for common commands
alias ls='eza --icons --group-directories-first -1'
alias ll='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias c='clear'
alias h='history'
alias haku='~/.local/bin/haku.sh'
alias menu='~/.local/bin/hakumenu.sh'
alias pacsize='expac -H M "%m\t%n" $(\pacman -Qeq) | sort -h -r'
alias pacsizefull='expac -H M "%m\t%n" | sort -h'
alias hsdoctor='~/hakuspace/doctor.sh'
alias hsupdate='~/hakuspace/update.sh'
alias hsrepo='cd ~/hakuspace/'

# History quality-of-life
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# Completion (thay cho oh-my-zsh)
fpath=(/usr/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{-_}={_-}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Starship setup
eval "$(starship init zsh)"

# Direnv setup
eval "$(direnv hook zsh)"

# Zoxide setup
eval "$(zoxide init zsh)"

[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
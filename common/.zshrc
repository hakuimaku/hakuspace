# Zsh Wiki: https://github.com/ohmyzsh/ohmyzsh/wiki

export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

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
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Quickly use script in local bin folder
export PATH="$HOME/.local/bin:$PATH"

# Custom environment variables
export GTK_USE_PORTAL=1
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORMTHEME=qt6ct
export DOTNET_ROOT=$HOME/.dotnet
export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools
export PATH=$PATH:$HOME/go/bin

# Set alias for common commands
alias zshconfig="nano ~/.zshrc"
alias reload="source ~/.zshrc"
alias haku="~/.local/bin/haku.sh"
alias menu="~/.local/bin/hakumenu.sh"
alias openconfig="~/.local/bin/open_config.sh"
alias pacsize='expac -H M "%m\t%n" $(\pacman -Qeq) | sort -h -r'
alias pacsizefull='expac -H M "%m\t%n" | sort -h -r'

# History quality-of-life
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

source $ZSH/oh-my-zsh.sh

# Override color for theme agnoster (oh-my-zsh)
export AGNOSTER_DIR_BG="white"
export AGNOSTER_GIT_DIRTY_BG="black"
export AGNOSTER_GIT_DIRTY_FG="white"
export AGNOSTER_CONTEXT_BG="#010101"
export AGNOSTER_CONTEXT_FG="blue"
export AGNOSTER_DIR_FG="#010101"
export AGNOSTER_DIR_BG="blue"

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
#!/usr/bin/env bash
# HakuSpace Generic Helper Library
# Presentation, logging, and general utility functions.

# Colors (enabled if either stdout or stderr is an interactive terminal)
if [[ -t 1 || -t 2 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'

    C_BLUE='\033[34m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
    C_CYAN='\033[36m'
    C_MAGENTA='\033[35m'
    C_WHITE='\033[37m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''

    C_BLUE=''
    C_GREEN=''
    C_YELLOW=''
    C_RED=''
    C_CYAN=''
    C_MAGENTA=''
    C_WHITE=''
fi

# ==============================================================================
# TERMINAL UI STREAM CONTRACT
# ==============================================================================
# Special Rule for Command Substitution (`VALUE="$(some_script)"`):
#   stdout is an API!
#   stdout          = machine-readable result ONLY
#   /dev/tty|stderr = all human-facing UI (headers, menus, warnings, logging,
#                     ANSI UI, prompts, descriptions, progress messages)
#   stdin|/dev/tty  = user input
#
# If stderr is a terminal and /dev/tty is writable, human UI is sent to /dev/tty.
# Otherwise (e.g. stream tests capturing stderr), human UI is sent to stderr.
# ==============================================================================

ui_print() {
    if [[ -t 2 && -w /dev/tty ]]; then
        echo -e "${1:-}" >/dev/tty
    else
        echo -e "${1:-}" >&2
    fi
}

ui_printf() {
    if [[ -t 2 && -w /dev/tty ]]; then
        printf "$@" >/dev/tty
    else
        printf "$@" >&2
    fi
}

ui_prompt() {
    local prompt="${1:-}"
    local out_var="${2:-REPLY}"
    local input=""

    ui_printf "%b" "$prompt"
    if [[ -t 0 && -r /dev/tty ]]; then
        IFS= read -r input </dev/tty || true
    else
        IFS= read -r input || true
        ui_print ""
    fi

    printf -v "$out_var" '%s' "$input"
}

# Logging helpers
shorten_path() {
    echo "${1//$HOME/\~}"
}

log_info()   { echo -e "${C_BLUE}[INFO]${C_RESET}   $(shorten_path "${1:-}")"; }
log_ok()     { echo -e "${C_GREEN}[OK]${C_RESET}     $(shorten_path "${1:-}")"; }
log_warn()   { echo -e "${C_YELLOW}[WARN]${C_RESET}   $(shorten_path "${1:-}")"; }
log_error()  { echo -e "${C_RED}[ERROR]${C_RESET}  $(shorten_path "${1:-}")"; }
log_backup() { echo -e "${C_MAGENTA}[BACKUP]${C_RESET} $(shorten_path "${1:-}")"; }
log_copy()   { echo -e "${C_CYAN}[COPY]${C_RESET}   $(shorten_path "${1:-}")"; }
log_skip()   { echo -e "${C_WHITE}[SKIP]${C_RESET}   $(shorten_path "${1:-}")"; }
log_symlink(){ echo -e "${C_CYAN}[SYMLINK]${C_RESET} $(shorten_path "${1:-}")"; }

# UI Helpers
UI_WIDTH=60
UI_LINE="────────────────────────────────────────────────────────────" # 60 chars
UI_LINE_THICK="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" # 60 chars

print_divider() {
    echo -e "${C_DIM}${UI_LINE}${C_RESET}"
}

step_title() {
    echo ""
    echo -e "${C_BOLD}${C_CYAN}╭${UI_LINE}╮${C_RESET}"
    printf "${C_BOLD}${C_CYAN}│${C_BOLD}${C_BLUE} %-58s ${C_BOLD}${C_CYAN}│${C_RESET}\n" "${1:-}"
    echo -e "${C_BOLD}${C_CYAN}╰${UI_LINE}╯${C_RESET}"
}

print_header() {
    local title="${1:-}"
    local desc="${2:-}"

    print_divider

    cat <<'EOF'
    __  __      __
   / / / /___ _/ /____  ___________  ____ _________
  / /_/ / __ `/ //_/ / / / ___/ __ \/ __ `/ ___/ _ \
 / __  / /_/ / ,< / /_/ (__  ) /_/ / /_/ / /__/  __/
/_/ /_/\__,_/_/|_|\__,_/____/ .___/\__,_/\___/\___/
                           /_/
EOF

    if [[ -n "$title" ]]; then
        echo -e "$title"
    fi
    if [[ -n "$desc" ]]; then
        echo -e "$desc"
    fi

    print_divider
}

# Control & Confirmation helpers
ask_yes_no() {
    local prompt="${1:-}"
    local answer=""
    ui_prompt "${prompt} (y/n): " answer
    [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]
}

die() {
    ui_print "${C_RED}[ERROR]${C_RESET}  $(shorten_path "${1:-Unknown error}")"
    exit 1
}

# Source filesystem primitives
if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi
source "$HAKU_DIR/scripts/filesystem.sh"

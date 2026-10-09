#!/usr/bin/env bash

# shell_switcher.sh - pick a login shell (fish / zsh) via rofi and apply it.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: shell_switcher.sh [OPTION]
Pick a shell, change login shell (chsh). If run from a terminal, also start the new shell right away.

Options:
    --print             Pick a shell, change login shell, print its path to stdout
    -h, --help          Show this help message

Requirements: rofi, chsh (util-linux), sudo (for registering shells / no-tty usage)
EOF
        exit 0
fi

SHELLS=("fish" "zsh")
PRINT_ONLY=0

if [[ "${1:-}" == "--print" ]]; then
    PRINT_ONLY=1
fi

notify() {
    notify-send "Shell Switcher" "$1"
    echo "$1"
}

# Check dependencies
need() { command -v "$1" >/dev/null 2>&1 || { notify "Missing dependency: $1"; exit 1; }; }

# NixOS: the login shell is managed declaratively, chsh changes are unsupported/overwritten
is_nixos() {
    [[ -e /etc/NIXOS ]] && return 0
    ( . /etc/os-release 2>/dev/null; [[ ${ID:-} == nixos ]] )
}

# Run a command as root. Asks for the password via rofi when there is no tty
# (e.g. launched from a keybind); the password is only asked once per run.
SUDO_PASS=""
run_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -t 0 ]]; then
        sudo "$@"
    else
        if [[ -z $SUDO_PASS ]]; then
            SUDO_PASS=$(rofi -dmenu -password -l 0 -p "sudo password" -theme option-menu.rasi </dev/null) || return 1
        fi
        printf '%s\n' "$SUDO_PASS" | sudo -S -p '' "$@"
    fi
}

# True if two paths point to the same binary (handles /bin -> /usr/bin symlinks)
same_bin() {
    [[ -n $1 && -n $2 && $(readlink -f "$1" 2>/dev/null) == "$(readlink -f "$2" 2>/dev/null)" ]]
}

# Find the path for shell $1 as it should be written for chsh:
#  1) the exact `command -v` path if listed in /etc/shells
#  2) another /etc/shells entry pointing to the same binary (e.g. /bin/zsh vs /usr/bin/zsh)
#  3) otherwise the `command -v` path (will be registered in /etc/shells on selection)
find_shell_path() {
    local bin line
    bin=$(command -v "$1") || return 1
    if grep -qx "$bin" /etc/shells 2>/dev/null; then echo "$bin"; return 0; fi
    while read -r line; do
        [[ $line == /* ]] || continue
        if same_bin "$line" "$bin"; then echo "$line"; return 0; fi
    done < /etc/shells
    echo "$bin"
}

if is_nixos; then
    notify "NixOS detected - not running. Set users.users.<name>.shell in your NixOS config instead."
    exit 1
fi

need rofi
need chsh

user=$(id -un)
# Read the real login shell from passwd ($SHELL can be stale inside an existing session)
current=$(getent passwd "$user" | cut -d: -f7)

# Build the menu from every shell in SHELLS that is installed
declare -A paths
menu=""
for name in "${SHELLS[@]}"; do
    p=$(find_shell_path "$name") || continue
    paths[$name]=$p
    label=$name
    same_bin "$p" "$current" && label+=" (current)"
    menu+="$label"$'\n'
done

if [[ -z $menu ]]; then
    notify "No supported shell found in PATH (looked for: ${SHELLS[*]})."
    exit 1
fi

choice=$(printf '%s' "$menu" | rofi -dmenu -i -no-custom -p "Shell" -theme option-menu.rasi) || exit 0
name=${choice%% *}
new=${paths[$name]:-}
[[ -n $new ]] || exit 0

# chsh only accepts shells listed in /etc/shells - register it if missing
if ! grep -qx "$new" /etc/shells 2>/dev/null; then
    run_root sh -c 'echo "$1" >> /etc/shells' _ "$new" \
        || { notify "Could not add $new to /etc/shells."; exit 1; }
fi

# Change the login shell only if it actually differs
if ! same_bin "$new" "$current"; then
    if [[ -t 0 ]]; then
        # Launched from a terminal: chsh asks for the password itself
        chsh -s "$new" "$user"
    else
        run_root chsh -s "$new" "$user"
    fi || { notify "Failed to change login shell to $name."; exit 1; }
fi

# Print mode: hand the path to the wrapper function, which does the exec in the *current* shell
if [[ "$PRINT_ONLY" == "1" ]]; then
    echo "$new"
    exit 0
fi

# Run from a terminal: start the new shell now (no need to log out).
# Note: a child process can't replace its parent shell, so this is a nested shell;
# use the `shsw` wrapper below for a true in-place replacement.
if [[ -t 0 && -t 1 ]]; then
    exec env SHELL="$new" "$new"
fi

notify "Shell changed to $name. Log out and back in for it to take effect."

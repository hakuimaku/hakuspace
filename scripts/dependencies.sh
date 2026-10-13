#!/usr/bin/env bash
# HakuSpace Dependencies Check & Bootstrap Module
# Verifies system prerequisites (pacman, yay, git, curl)

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

check_dependencies() {
    local interactive="${1:-1}"
    local errors=0

    # 1. Distro / Pacman check
    if command -v pacman >/dev/null 2>&1; then
        if command -v yay >/dev/null 2>&1; then
            log_ok "yay is installed."
        else
            log_warn "yay (AUR helper) is not installed. It is required to install HakuSpace package groups."
            if [[ "$interactive" -eq 1 ]]; then
                if ask_yes_no "===> Clone and build yay-bin from AUR now?"; then
                    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay
                    (cd /tmp/yay && makepkg -si --noconfirm)
                    rm -rf /tmp/yay
                    log_ok "yay has been installed successfully."
                else
                    log_warn "You need yay to proceed with automatic package installation."
                    errors=$((errors + 1))
                fi
            else
                errors=$((errors + 1))
            fi
        fi
    else
        log_warn "Non-Arch distro detected. Manual package management required."
        errors=$((errors + 1))
    fi

    # 2. Check essential tools (git, curl)
    local deps=("git" "curl")
    for pkg in "${deps[@]}"; do
        if command -v "$pkg" >/dev/null 2>&1; then
            log_ok "$pkg exists."
        else
            log_warn "Required prerequisite tool '$pkg' was not found."
            if [[ "$interactive" -eq 1 ]] && command -v yay >/dev/null 2>&1; then
                if ask_yes_no "===> Install '$pkg' via yay now?"; then
                    yay -S --noconfirm "$pkg"
                    log_ok "Installed $pkg."
                else
                    errors=$((errors + 1))
                fi
            else
                errors=$((errors + 1))
            fi
        fi
    done

    if [[ "$errors" -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# CLI Entrypoint
case "${1:-}" in
    --check)
        check_dependencies 0
        ;;
    --help|-h)
        echo "Usage: $0 [--check]"
        exit 0
        ;;
    *)
        check_dependencies 1
        ;;
esac

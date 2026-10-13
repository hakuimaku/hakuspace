#!/usr/bin/env bash
# HakuSpace NixOS Integration Module
# Handles NixOS installation, updates, and rebuilds.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"

NIXOS_ETC="/etc/nixos"
SOURCE_HAKU_NIX="$NIX_DIR/hakuspace-config.nix"
SOURCE_FLAKE_EXAMPLE="$NIX_DIR/flake.nix.example"

nixos_status() {
    if ! command -v nixos-rebuild >/dev/null 2>&1; then
        echo "not_nixos"
        return 0
    fi

    if [[ -f "$NIXOS_ETC/flake.nix" ]] && grep -q "hakuspace.nixosModules.default" "$NIXOS_ETC/flake.nix" 2>/dev/null; then
        echo "flake"
    elif [[ -f "$NIXOS_ETC/hakuspace-config.nix" ]]; then
        echo "offline"
    else
        echo "unconfigured"
    fi
}

nixos_install() {
    if ! command -v nixos-rebuild >/dev/null 2>&1; then
        log_skip "Not on NixOS. Skipping NixOS installation."
        return 0
    fi

    ui_print ""
    ui_print "${C_DIM}${UI_LINE}${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}NIXOS CONFIGURATION MODE${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[1]${C_RESET} Offline Config"
    ui_print "    ${C_DIM}Copy hakuspace-config.nix to /etc/nixos and import in configuration.nix.${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[2]${C_RESET} Online Flake Template"
    ui_print "    ${C_DIM}Deploy template flake.nix to /etc/nixos/flake.nix.${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[0]${C_RESET} Skip"
    ui_print "    ${C_DIM}Skip NixOS-specific configuration deployment.${C_RESET}"
    ui_print ""
    ui_print "${C_DIM}${UI_LINE}${C_RESET}"

    local nixos_mode=""
    ui_prompt "Choose NixOS configuration mode [1/2/0] (default: 0): " nixos_mode
    nixos_mode="${nixos_mode:-0}"

    if [[ "$nixos_mode" == "1" ]]; then
        log_info "Deploying NixOS Offline Config..."
        copy_file "$SOURCE_HAKU_NIX" "$NIXOS_ETC/hakuspace-config.nix"

        local config_nix="$NIXOS_ETC/configuration.nix"
        if [[ -f "$config_nix" ]]; then
            if grep -q "./hakuspace-config.nix" "$config_nix"; then
                log_skip "./hakuspace-config.nix is already imported in $config_nix."
            else
                log_info "Injecting ./hakuspace-config.nix into imports of configuration.nix..."
                sudo sed -i '/^[[:space:]]*imports[[:space:]]*=/,/^[[:space:]]*];[[:space:]]*$/ { /^[[:space:]]*];[[:space:]]*$/i\      ./hakuspace-config.nix
}' "$config_nix"
                if grep -q "./hakuspace-config.nix" "$config_nix"; then
                    log_ok "Updated imports in $config_nix."
                else
                    log_warn "Failed to inject into imports. Please add ./hakuspace-config.nix manually to $config_nix."
                fi
            fi
        else
            log_warn "$config_nix not found! Please import hakuspace-config.nix manually."
        fi

    elif [[ "$nixos_mode" == "2" ]]; then
        log_info "Deploying NixOS Online Remote Config (Flake)..."
        local dest_flake="$NIXOS_ETC/flake.nix"

        if [[ -f "$dest_flake" ]]; then
            log_warn "$dest_flake already exists."
            log_warn "Hakuspace flake.nix will overwrite your existing flake.nix (backup your own first)."
            log_warn "Hakuspace flake.nix is a template and may not include your custom configurations."
            if ask_yes_no "===> Overwrite existing $dest_flake with the HakuSpace template?"; then
                copy_file "$SOURCE_FLAKE_EXAMPLE" "$dest_flake"
                log_ok "flake.nix overwritten successfully."
            else
                log_skip "Kept existing flake.nix."
            fi
        else
            copy_file "$SOURCE_FLAKE_EXAMPLE" "$dest_flake"
            log_ok "flake.nix deployed successfully."
        fi
    else
        log_skip "Skipping NixOS specific deployment."
    fi
}

nixos_update() {
    if ! command -v nixos-rebuild >/dev/null 2>&1; then
        log_skip "Not on NixOS. Skipping NixOS update."
        return 0
    fi

    local status
    status="$(nixos_status)"

    local rebuild_done=0

    if [[ "$status" == "flake" ]]; then
        log_info "Detected NixOS with Hakuspace Flake (Online Mode)."
        if ask_yes_no "===> Do you want to update flake inputs and rebuild NixOS now?"; then
            (cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake .)
            log_ok "NixOS updated and rebuilt successfully via Flake."
            rebuild_done=1
        fi
    elif [[ "$status" == "offline" ]]; then
        log_info "Detected NixOS with Local hakuspace-config.nix (Offline Mode)."
        if ask_yes_no "===> Do you want to update local hakuspace-config.nix and rebuild NixOS now?"; then
            copy_file "$SOURCE_HAKU_NIX" "$NIXOS_ETC/hakuspace-config.nix"
            log_info "Rebuilding NixOS system..."
            sudo nixos-rebuild switch
            log_ok "NixOS updated and rebuilt successfully via Local Config."
            rebuild_done=1
        fi
    else
        log_warn "NixOS detected, but no Hakuspace configuration pattern found."
    fi

    if [[ "$rebuild_done" -eq 0 ]]; then
        log_warn "You chose not to rebuild the NixOS system. Please remember to rebuild later to apply system-level changes."
    fi
}

nixos_rebuild() {
    if ! command -v nixos-rebuild >/dev/null 2>&1; then
        log_skip "Not on NixOS. Skipping rebuild."
        return 0
    fi

    if ask_yes_no "===> Do you want to rebuild NixOS system now? (maybe have some conflicts)"; then
        sudo nixos-rebuild switch
    else
        log_warn "You chose not to rebuild NixOS system. Please remember to run 'sudo nixos-rebuild switch' later."
    fi
}

# CLI Entrypoint
COMMAND="${1:-status}"

case "$COMMAND" in
    install)
        nixos_install
        ;;
    update)
        nixos_update
        ;;
    rebuild)
        nixos_rebuild
        ;;
    status)
        nixos_status
        ;;
    --help|-h)
        echo "Usage: $0 [install | update | rebuild | status]"
        exit 0
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac

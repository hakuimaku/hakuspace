#!/usr/bin/env bash
# HakuSpace Repository Update Module
# Updates HakuSpace dotfiles repository via Git (LATEST vs STABLE).
# Exit code 10 signals to the caller (e.g. update.sh) that updater scripts changed and re-exec is needed.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

STATUS_REEXEC=10

update_repo() {
    local mode="${1:-}"
    local target_script="${2:-$HAKU_DIR/update.sh}"

    if [[ -z "$mode" ]]; then
        ui_print "${C_DIM}${UI_LINE}${C_RESET}"
        ui_print ""
        ui_print "${C_BOLD}REPOSITORY UPDATE MODE${C_RESET}"
        ui_print ""
        ui_print "${C_BOLD}[1]${C_RESET} Latest (main branch)"
        ui_print "    ${C_DIM}Pull latest development commits from origin/main.${C_RESET}"
        ui_print ""
        ui_print "${C_BOLD}[2]${C_RESET} Stable (latest release tag)"
        ui_print "    ${C_DIM}Checkout the most recent tagged release.${C_RESET}"
        ui_print ""
        ui_print "${C_BOLD}[0]${C_RESET} Skip"
        ui_print "    ${C_DIM}Do not update the local repository.${C_RESET}"
        ui_print ""
        ui_print "${C_DIM}${UI_LINE}${C_RESET}"

        local choice=""
        ui_prompt "Choose repository update mode [1/2/0] (default: 0): " choice
        mode="${choice:-0}"
    fi

    # Snapshot target script for change detection
    local backup_target=""
    if [[ -f "$target_script" ]]; then
        backup_target="/tmp/hakuspace_target_script_$$.bak"
        cp "$target_script" "$backup_target"
    fi

    local repo_changed=0

    case "$mode" in
        1|latest|LATEST)
            log_info "Switching to main branch and pulling latest changes..."
            git -C "$HAKU_DIR" checkout main
            git -C "$HAKU_DIR" pull origin main
            log_ok "Repository updated to LATEST."
            repo_changed=1
            ;;
        2|stable|STABLE)
            log_info "Fetching tags from remote..."
            git -C "$HAKU_DIR" fetch --tags
            local latest_tag
            latest_tag=$(git -C "$HAKU_DIR" describe --tags "$(git -C "$HAKU_DIR" rev-list --tags --max-count=1 2>/dev/null)" 2>/dev/null || true)
            if [[ -z "$latest_tag" ]]; then
                log_warn "No tags found in repository. Falling back to main branch."
                git -C "$HAKU_DIR" checkout main
                git -C "$HAKU_DIR" pull origin main
            else
                log_info "Latest stable tag found: $latest_tag"
                git -C "$HAKU_DIR" checkout "$latest_tag"
                log_ok "Repository updated to STABLE ($latest_tag)."
            fi
            repo_changed=1
            ;;
        0|skip|SKIP)
            log_skip "Skipping repository update."
            ;;
        *)
            log_warn "Unknown choice '$mode'. Skipping repository update."
            ;;
    esac

    if [[ "$repo_changed" -eq 1 && -n "$backup_target" && -f "$backup_target" ]]; then
        if ! cmp -s "$backup_target" "$target_script"; then
            rm -f "$backup_target"
            log_warn "Updater logic updated in repository! Re-exec required."
            return $STATUS_REEXEC
        fi
        rm -f "$backup_target"
    fi

    return 0
}

# CLI Entrypoint
MODE=""
TARGET_SCRIPT="$HAKU_DIR/update.sh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --target-script)
            TARGET_SCRIPT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--mode latest|stable|skip] [--target-script <path>]"
            exit 0
            ;;
        *)
            MODE="$1"
            shift
            ;;
    esac
done

update_repo "$MODE" "$TARGET_SCRIPT"

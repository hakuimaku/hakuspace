#!/usr/bin/env bash
# HakuSpace Repository Update Module
# Updates HakuSpace dotfiles repository via Git (LATEST vs STABLE).
# Exit code 10 requests re-exec whenever the repository revision changes.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

STATUS_REEXEC=10

update_repo() {
    local mode="${1:-}"

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

    # Revision changes require reloading every module sourced by the parent updater.
    local before_revision after_revision
    case "$mode" in
        1|latest|LATEST|2|stable|STABLE)
            before_revision="$(git -C "$HAKU_DIR" rev-parse --verify HEAD)" || return $?
            ;;
    esac

    case "$mode" in
        1|latest|LATEST)
            log_info "Switching to main branch and pulling latest changes..."
            git -C "$HAKU_DIR" checkout main || return $?
            git -C "$HAKU_DIR" pull --ff-only origin main || return $?
            log_ok "Repository updated to LATEST."
            ;;
        2|stable|STABLE)
            log_info "Fetching tags from remote..."
            git -C "$HAKU_DIR" fetch --tags || return $?
            local latest_tag
            latest_tag=$(git -C "$HAKU_DIR" describe --tags "$(git -C "$HAKU_DIR" rev-list --tags --max-count=1 2>/dev/null)" 2>/dev/null || true)
            if [[ -z "$latest_tag" ]]; then
                log_warn "No tags found in repository. Falling back to main branch."
                git -C "$HAKU_DIR" checkout main || return $?
                git -C "$HAKU_DIR" pull --ff-only origin main || return $?
            else
                log_info "Latest stable tag found: $latest_tag"
                git -C "$HAKU_DIR" checkout "$latest_tag" || return $?
                log_ok "Repository updated to STABLE ($latest_tag)."
            fi
            ;;
        0|skip|SKIP)
            log_skip "Skipping repository update."
            ;;
        *)
            log_warn "Unknown choice '$mode'. Skipping repository update."
            ;;
    esac

    if [[ -n "${before_revision:-}" ]]; then
        after_revision="$(git -C "$HAKU_DIR" rev-parse --verify HEAD)" || return $?
        if [[ "$before_revision" != "$after_revision" ]]; then
            log_warn "Repository revision changed; re-exec required to reload updater modules."
            return "$STATUS_REEXEC"
        fi
    fi

    return 0
}

# CLI Entrypoint
MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --target-script)
            # Accept the legacy argument for callers predating revision-based detection.
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

update_repo "$MODE"

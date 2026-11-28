#!/usr/bin/env bash
# HakuSpace Legacy Package Migration Module
# Migrates deprecated/renamed Arch packages separately from package group updates.
# Exit codes:
#   0 - All pending migrations applied (or nothing to migrate)
#   1 - Fatal error or unrecoverable rollback failure
#   2 - One or more migrations could not complete, but previous package(s) were preserved/rolled back

set -eo pipefail

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

# Format: "old_pkg|new_pkg|strategy|reason"
# strategy:
#   conflict    - packages conflict; pre-download new, locate old cache, swap, roll back on failure
#   nonconflict - packages can coexist; install new first, remove old only after new succeeds
PKG_MIGRATIONS=(
    "mangowm-git|mangowm|conflict|MangoWM moved to the Arch extra repository"
    "wl-screenrec-git|gpu-screen-recorder|nonconflict|Screen recorder migrated to gpu-screen-recorder"
)

MODE=""
LOG_FILE=""
SOFT_FAIL=0
HARD_FAIL=0

is_pacman_system() {
    ! command -v nixos-rebuild >/dev/null 2>&1 && command -v pacman >/dev/null 2>&1
}

is_pkg_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

pkg_version() {
    pacman -Q "$1" 2>/dev/null | awk '{print $2}'
}

run_privileged() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_logged() {
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

# Match exact <pkgname>-<pkgver>-<pkgrel>-<arch>.pkg.tar* archives while skipping .sig and -debug-.
find_cached_pkg() {
    local pkg="$1"
    local ver="${2:-}"
    local yay_cache="${HAKUSPACE_YAY_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/yay}"
    local pacman_cache="${HAKUSPACE_PACMAN_CACHE_DIR:-/var/cache/pacman/pkg}"
    local -a search_dirs=("$yay_cache/$pkg" "$pacman_cache")
    local dir file base suffix mtime
    local best_exact="" best_exact_mtime=-1
    local best_any="" best_any_mtime=-1
    local suffix_regex='^[^-]+-[^-]+-[^-]+\.pkg\.tar(\.[^.]+)?$'
    local shopt_state
    shopt_state="$(shopt -p nullglob || true)"
    shopt -s nullglob

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir/${pkg}-"*.pkg.tar*; do
            [[ -f "$file" && -r "$file" ]] || continue
            base="${file##*/}"
            [[ "$base" == *.sig ]] && continue
            [[ "$base" == "${pkg}-debug-"* ]] && continue
            suffix="${base#"${pkg}-"}"
            [[ "$suffix" =~ $suffix_regex ]] || continue
            mtime="$(stat -c '%Y' "$file" 2>/dev/null || echo 0)"
            if [[ -n "$ver" && "$base" == "${pkg}-${ver}-"* ]]; then
                if (( mtime > best_exact_mtime )); then
                    best_exact="$file"
                    best_exact_mtime="$mtime"
                fi
            elif (( mtime > best_any_mtime )); then
                best_any="$file"
                best_any_mtime="$mtime"
            fi
        done
    done

    eval "$shopt_state"
    if [[ -n "$best_exact" ]]; then
        printf '%s\n' "$best_exact"
    elif [[ -n "$best_any" ]]; then
        printf '%s\n' "$best_any"
    fi
}

collect_pending() {
    PENDING_MIGRATIONS=()
    is_pacman_system || return 0
    local entry old_pkg new_pkg strategy reason
    for entry in "${PKG_MIGRATIONS[@]}"; do
        IFS='|' read -r old_pkg new_pkg strategy reason <<< "$entry"
        if is_pkg_installed "$old_pkg"; then
            PENDING_MIGRATIONS+=("$entry")
        fi
    done
}

print_plan() {
    if ! is_pacman_system; then
        log_skip "Package migration only applies to Arch/pacman systems."
        return 0
    fi
    collect_pending
    echo ""
    print_divider
    echo -e "${C_BOLD}PACKAGE MIGRATION PLAN${C_RESET}"
    echo ""
    if [[ ${#PENDING_MIGRATIONS[@]} -eq 0 ]]; then
        log_ok "No legacy packages require migration."
        print_divider
        return 0
    fi

    local entry old_pkg new_pkg strategy reason old_ver cache_file note
    for entry in "${PENDING_MIGRATIONS[@]}"; do
        IFS='|' read -r old_pkg new_pkg strategy reason <<< "$entry"
        old_ver="$(pkg_version "$old_pkg")"
        if is_pkg_installed "$new_pkg"; then
            note="remove old; $new_pkg already installed"
        elif [[ "$strategy" == "conflict" ]]; then
            cache_file="$(find_cached_pkg "$old_pkg" "$old_ver")"
            if [[ -n "$cache_file" ]]; then
                note="pre-download new, replace old (offline rollback cache found)"
            else
                note="pre-download new, replace old (rollback via AUR fallback if needed)"
            fi
        else
            note="install new first, then remove old"
        fi
        echo -e "  • ${C_BOLD}${old_pkg}${C_RESET} (${old_ver:-installed}) -> ${C_BOLD}${new_pkg}${C_RESET}"
        echo -e "    ${C_DIM}${reason} — ${note}${C_RESET}"
    done
    echo ""
    echo -e "${C_DIM}If a new package fails to download or install, the previous package is preserved or rolled back with a reminder.${C_RESET}"
    print_divider
}

pkg_has_metadata_conflict() {
    local old_pkg="$1"
    local new_pkg="$2"
    pacman -Qi "$old_pkg" 2>/dev/null | grep -qE "^(Conflicts With|Provides)[[:space:]]*:.*\\b${new_pkg}\\b"
}

# Pre-download target package before removing a conflicting package so network/mirror errors never leave the user without it.
predownload_repo_pkg() {
    local old_pkg="$1"
    local new_pkg="$2"
    local tmp_out
    tmp_out="$(mktemp)"

    if run_privileged pacman -Sw --noconfirm "$new_pkg" >"$tmp_out" 2>&1; then
        tee -a "$LOG_FILE" < "$tmp_out"
        rm -f "$tmp_out"
        return 0
    fi

    tee -a "$LOG_FILE" < "$tmp_out"
    if grep -qiE 'in conflict|conflicting dependencies' "$tmp_out" || pkg_has_metadata_conflict "$old_pkg" "$new_pkg"; then
        rm -f "$tmp_out"
        log_info "[$old_pkg -> $new_pkg] Conflict detected during download check; pre-downloading $new_pkg archive before swap..."
        if run_logged run_privileged pacman -Swdd --noconfirm "$new_pkg"; then
            return 0
        fi
        return 1
    fi

    rm -f "$tmp_out"
    return 1
}

rollback_old_pkg() {
    local old_pkg="$1"
    local rollback_cache="$2"

    log_warn "[$old_pkg] Attempting rollback to previous package..."
    if [[ -n "$rollback_cache" && -f "$rollback_cache" ]]; then
        log_info "[$old_pkg] Restoring from cached archive: $(shorten_path "$rollback_cache")"
        if run_logged run_privileged pacman -U --noconfirm "$rollback_cache" && is_pkg_installed "$old_pkg"; then
            return 0
        fi
    fi

    if command -v yay >/dev/null 2>&1; then
        log_info "[$old_pkg] Cached archive unavailable or failed; falling back to yay..."
        if run_logged yay -S --needed --noconfirm "$old_pkg" && is_pkg_installed "$old_pkg"; then
            return 0
        fi
    fi

    is_pkg_installed "$old_pkg"
}

migrate_nonconflict() {
    local old_pkg="$1"
    local new_pkg="$2"
    local installed_new=0

    if is_pkg_installed "$new_pkg"; then
        installed_new=1
        log_info "[$old_pkg -> $new_pkg] $new_pkg is already installed; removing legacy $old_pkg..."
    else
        log_info "[$old_pkg -> $new_pkg] Installing $new_pkg before removing $old_pkg..."
        if pacman -Si "$new_pkg" >/dev/null 2>&1; then
            if run_logged run_privileged pacman -S --needed --noconfirm "$new_pkg" && is_pkg_installed "$new_pkg"; then
                installed_new=1
            fi
        elif command -v yay >/dev/null 2>&1; then
            if run_logged yay -S --needed --noconfirm "$new_pkg" && is_pkg_installed "$new_pkg"; then
                installed_new=1
            fi
        else
            log_warn "[$old_pkg -> $new_pkg] $new_pkg not found in pacman sync DB and yay is unavailable."
        fi
    fi

    if [[ "$installed_new" -ne 1 ]]; then
        log_warn "[$old_pkg -> $new_pkg] Failed to install $new_pkg; kept existing $old_pkg."
        log_warn "Reminder: refresh your system packages (sudo pacman -Syu) and retry with ./scripts/pkg_migrate.sh --apply."
        SOFT_FAIL=1
        return 0
    fi

    if run_logged run_privileged pacman -R --noconfirm "$old_pkg"; then
        log_ok "[$old_pkg -> $new_pkg] Migrated successfully."
    else
        log_warn "[$old_pkg -> $new_pkg] Installed $new_pkg, but could not remove $old_pkg automatically."
        log_warn "Reminder: check reverse dependencies and remove manually when ready: sudo pacman -R $old_pkg"
        SOFT_FAIL=1
    fi
}

migrate_conflict() {
    local old_pkg="$1"
    local new_pkg="$2"
    local old_ver rollback_cache

    if is_pkg_installed "$new_pkg"; then
        log_info "[$old_pkg -> $new_pkg] $new_pkg is already installed; removing legacy $old_pkg..."
        if run_logged run_privileged pacman -R --noconfirm "$old_pkg"; then
            log_ok "[$old_pkg -> $new_pkg] Removed legacy $old_pkg."
        else
            log_warn "[$old_pkg -> $new_pkg] Could not remove $old_pkg automatically; run: sudo pacman -R $old_pkg"
            SOFT_FAIL=1
        fi
        return 0
    fi

    old_ver="$(pkg_version "$old_pkg")"
    rollback_cache="$(find_cached_pkg "$old_pkg" "$old_ver")"

    if ! pacman -Si "$new_pkg" >/dev/null 2>&1; then
        log_warn "[$old_pkg -> $new_pkg] $new_pkg was not found in the local pacman sync database; kept existing $old_pkg."
        log_warn "Reminder: run 'sudo pacman -Syu' to refresh package databases, then retry ./scripts/pkg_migrate.sh --apply."
        SOFT_FAIL=1
        return 0
    fi

    log_info "[$old_pkg -> $new_pkg] Pre-downloading $new_pkg before removing $old_pkg..."
    if ! predownload_repo_pkg "$old_pkg" "$new_pkg"; then
        log_warn "[$old_pkg -> $new_pkg] Failed to download $new_pkg; kept existing $old_pkg."
        log_warn "Reminder: check network/mirrors or run 'sudo pacman -Syu', then retry ./scripts/pkg_migrate.sh --apply."
        SOFT_FAIL=1
        return 0
    fi

    log_info "[$old_pkg -> $new_pkg] Removing $old_pkg..."
    if ! run_logged run_privileged pacman -R --noconfirm "$old_pkg"; then
        log_warn "[$old_pkg -> $new_pkg] Could not remove $old_pkg (likely required by another package); kept existing $old_pkg."
        log_warn "Reminder: resolve dependencies and migrate manually: sudo pacman -R $old_pkg && sudo pacman -S $new_pkg"
        SOFT_FAIL=1
        return 0
    fi

    log_info "[$old_pkg -> $new_pkg] Installing $new_pkg..."
    if run_logged run_privileged pacman -S --needed --noconfirm "$new_pkg" && is_pkg_installed "$new_pkg"; then
        log_ok "[$old_pkg -> $new_pkg] Migrated successfully."
        return 0
    fi

    if rollback_old_pkg "$old_pkg" "$rollback_cache"; then
        log_warn "[$old_pkg -> $new_pkg] Installing $new_pkg failed; rolled back to $old_pkg."
        log_warn "Reminder: review $(shorten_path "$LOG_FILE") and retry later with ./scripts/pkg_migrate.sh --apply."
        SOFT_FAIL=1
    else
        log_error "[$old_pkg -> $new_pkg] CRITICAL: Installing $new_pkg failed AND rolling back $old_pkg also failed!"
        log_error "Reinstall manually before ending your session: sudo pacman -S $new_pkg  (or: yay -S $old_pkg)"
        HARD_FAIL=1
    fi
}

apply_migrations() {
    local dry_run="${1:-0}"
    if ! is_pacman_system; then
        log_skip "Package migration only applies to Arch/pacman systems."
        return 0
    fi

    collect_pending
    if [[ ${#PENDING_MIGRATIONS[@]} -eq 0 ]]; then
        log_ok "No legacy packages require migration."
        return 0
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        local entry old_pkg new_pkg strategy reason old_ver rollback_cache
        for entry in "${PENDING_MIGRATIONS[@]}"; do
            IFS='|' read -r old_pkg new_pkg strategy reason <<< "$entry"
            old_ver="$(pkg_version "$old_pkg")"
            if [[ "$strategy" == "conflict" ]]; then
                rollback_cache="$(find_cached_pkg "$old_pkg" "$old_ver")"
                log_info "DRY RUN [$old_pkg -> $new_pkg]: pre-download $new_pkg, remove $old_pkg, install $new_pkg (rollback cache: ${rollback_cache:-none})"
            else
                log_info "DRY RUN [$old_pkg -> $new_pkg]: install $new_pkg, then remove $old_pkg"
            fi
        done
        return 0
    fi

    mkdir -p "$BACKUP_DIR/packages" || return 1
    LOG_FILE="$BACKUP_DIR/packages/pkg_migrate.log"
    printf '=== Package migration run (%s) ===\n' "${HAKUSPACE_RUN_ID:-manual}" >> "$LOG_FILE"

    local entry old_pkg new_pkg strategy reason
    for entry in "${PENDING_MIGRATIONS[@]}"; do
        IFS='|' read -r old_pkg new_pkg strategy reason <<< "$entry"
        printf '[%s -> %s] strategy=%s\n' "$old_pkg" "$new_pkg" "$strategy" >> "$LOG_FILE"
        if [[ "$strategy" == "conflict" ]]; then
            migrate_conflict "$old_pkg" "$new_pkg"
        else
            migrate_nonconflict "$old_pkg" "$new_pkg"
        fi
    done

    if [[ "$HARD_FAIL" -ne 0 ]]; then
        return 1
    fi
    if [[ "$SOFT_FAIL" -ne 0 ]]; then
        return 2
    fi
    return 0
}

usage() {
    echo "Usage: $0 --plan | --apply | --dry-run | --has-pending"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --has-pending)
            MODE="has-pending"
            shift
            ;;
        --plan)
            MODE="plan"
            shift
            ;;
        --apply)
            MODE="apply"
            shift
            ;;
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: '$1'"
            usage >&2
            exit 1
            ;;
    esac
done

case "$MODE" in
    has-pending)
        collect_pending
        [[ ${#PENDING_MIGRATIONS[@]} -gt 0 ]]
        ;;
    plan)
        print_plan
        ;;
    apply)
        apply_migrations 0
        ;;
    dry-run)
        apply_migrations 1
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

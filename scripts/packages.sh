#!/usr/bin/env bash
# HakuSpace Package Management Module
# Installs package groups using yay. Supports manual targets and profiles.

set -eo pipefail

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

DRY_RUN=0
PLAN_MODE=0
REPAIR_MISSING=0
PROFILE=""
INPUT_TARGETS=()
RESOLVED_WMS=()
RESOLVED_GROUPS=()

extract_packages_from_file() {
    local file="${1:-}"
    [[ -f "$file" ]] || return 0
    sed 's/[[:space:]]*#.*$//' "$file" | grep -E '^[a-zA-Z0-9@._+-]+$' || true
}

append_unique_item() {
    local array_name="$1"
    local val="$2"
    local item
    eval "local current_items=(\"\${${array_name}[@]}\")"
    for item in "${current_items[@]}"; do
        [[ "$item" == "$val" ]] && return 0
    done
    eval "${array_name}+=(\"\$val\")"
}

resolve_package_profile() {
    RESOLVED_WMS=()
    RESOLVED_GROUPS=()

    if [[ -n "$PROFILE" ]]; then
        RESOLVED_GROUPS=(core service)
        local wm
        for wm in "${INPUT_TARGETS[@]}"; do
            if [[ "${wm,,}" == "all" || "$wm" == "5" ]]; then
                local c_wm
                for c_wm in niri mango labwc hyprland; do
                    append_unique_item RESOLVED_WMS "$c_wm"
                    append_unique_item RESOLVED_GROUPS "$c_wm"
                done
            else
                local canon
                canon="$(registry_canonical_wm_name "$wm" 2>/dev/null || true)"
                if [[ -n "$canon" ]]; then
                    append_unique_item RESOLVED_WMS "$canon"
                    append_unique_item RESOLVED_GROUPS "$canon"
                else
                    log_error "Unknown window manager for package profile: '$wm'"
                    return 1
                fi
            fi
        done

        append_unique_item RESOLVED_GROUPS "core"
        append_unique_item RESOLVED_GROUPS "service"
        if [[ "$PROFILE" == "install" ]]; then
            append_unique_item RESOLVED_GROUPS "optional"
        fi
    else
        local grp
        for grp in "${INPUT_TARGETS[@]}"; do
            local file
            file="$(registry_get_package_file "$grp" 2>/dev/null || true)"
            if [[ -z "$file" ]]; then
                log_error "Unknown package group: '$grp'. Use --list to view valid groups."
                return 1
            fi
            local canon_wm
            canon_wm="$(registry_canonical_wm_name "$grp" 2>/dev/null || true)"
            if [[ -n "$canon_wm" ]]; then
                append_unique_item RESOLVED_WMS "$canon_wm"
                append_unique_item RESOLVED_GROUPS "$canon_wm"
            else
                append_unique_item RESOLVED_GROUPS "${grp,,}"
            fi
        done
    fi
}

print_package_plan() {
    echo ""
    print_divider
    if [[ "$PROFILE" == "update" ]]; then
        echo -e "${C_BOLD}PACKAGE UPDATE PLAN${C_RESET}"
    else
        echo -e "${C_BOLD}PACKAGE INSTALLATION PLAN${C_RESET}"
    fi
    echo ""

    if [[ ${#RESOLVED_WMS[@]} -gt 0 ]]; then
        if [[ "$PROFILE" == "update" ]]; then
            echo -e "${C_BOLD}Detected/selected Window Manager(s):${C_RESET}"
        elif [[ ${#RESOLVED_WMS[@]} -eq 1 ]]; then
            echo -e "${C_BOLD}Selected Window Manager:${C_RESET}"
        else
            echo -e "${C_BOLD}Selected Window Manager(s):${C_RESET}"
        fi
        local wm
        for wm in "${RESOLVED_WMS[@]}"; do
            echo "  • $(registry_wm_display_name "$wm")"
        done
        echo ""
    fi

    echo -e "${C_BOLD}Package groups:${C_RESET}"
    local grp
    for grp in "${RESOLVED_GROUPS[@]}"; do
        echo "  • $grp"
    done
    echo ""

    echo -e "${C_BOLD}Sources:${C_RESET}"
    for grp in "${RESOLVED_GROUPS[@]}"; do
        local file
        file="$(registry_get_package_file "$grp")"
        local rel_file="${file#"$HAKU_DIR/"}"
        echo "  • $rel_file"
    done
    echo ""

    echo -e "${C_BOLD}Package counts:${C_RESET}"
    local all_pkgs=()
    local total_entries=0
    for grp in "${RESOLVED_GROUPS[@]}"; do
        local file
        file="$(registry_get_package_file "$grp")"
        local grp_pkgs=()
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && grp_pkgs+=("$pkg")
        done < <(extract_packages_from_file "$file")
        local count="${#grp_pkgs[@]}"
        total_entries=$((total_entries + count))
        all_pkgs+=("${grp_pkgs[@]}")
        printf "  %-10s %3d packages\n" "$grp" "$count"
    done
    echo ""

    local unique_count=0
    if [[ ${#all_pkgs[@]} -gt 0 ]]; then
        unique_count="$(printf '%s\n' "${all_pkgs[@]}" | sort -u | wc -l | tr -d ' ')"
    fi

    if [[ "$unique_count" -ne "$total_entries" ]]; then
        echo -e "${C_BOLD}Total:${C_RESET} $unique_count unique packages ($total_entries package entries)"
    else
        echo -e "${C_BOLD}Total:${C_RESET} $total_entries package entries"
    fi
    print_divider
}

install_pkg_file() {
    local label="${1:-}"
    local file="${2:-}"

    if [[ ! -f "$file" ]]; then
        log_warn "[$label] File not found: $(shorten_path "$file") (skip)"
        return 1
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[$label] DRY RUN: Packages from $(shorten_path "$file"):"
        extract_packages_from_file "$file" | sed 's/^/  - /' || true
        return 0
    fi

    if command -v nixos-rebuild >/dev/null 2>&1 || ! command -v pacman >/dev/null 2>&1; then
        log_error "[$label] Unsupported package manager; use the system configuration, then --audit-runtime."
        return 1
    fi
    command -v yay >/dev/null 2>&1 || { log_error "yay is not installed."; return 1; }
    local pkg status log
    local -a packages=()
    while IFS= read -r pkg; do
        if [[ "$REPAIR_MISSING" == 1 ]] && pacman -Qq "$pkg" >/dev/null 2>&1; then continue; fi
        packages+=("$pkg")
    done < <(extract_packages_from_file "$file")
    if [[ ${#packages[@]} == 0 ]]; then log_ok "[$label] No missing packages."; return 0; fi
    mkdir -p "$BACKUP_DIR/packages" || return 1
    log="$BACKUP_DIR/packages/$label.log"
    printf '[%s] Packages: %s\n' "$label" "${packages[*]}" | tee "$log"
    if printf '%s\n' "${packages[@]}" | yay -S --needed --noconfirm - 2>&1 | tee -a "$log"; then
        log_ok "[$label] installed (exit=0)."
        return 0
    else
        status=$?
        log_error "[$label] failed (exit=$status); output: $log; retry: scripts/packages.sh --repair-missing ${label,,}"
        return "$status"
    fi
}

install_group() {
    local group="${1:-}"
    local file
    file="$(registry_get_package_file "$group")" || {
        log_error "Unknown package group: '$group'. Use --list to view valid groups."
        return 1
    }

    local label
    label="$(echo "$group" | tr '[:lower:]' '[:upper:]')"
    install_pkg_file "$label" "$file"
}

list_groups() {
    echo "Available package groups:"
    echo "  core       (Base desktop utilities and fonts)"
    echo "  service    (Background daemons and services)"
    echo "  optional   (Extra optional applications)"
    echo "  hyprland   (Hyprland WM and specific packages)"
    echo "  niri       (Niri scrollable WM packages)"
    echo "  mango      (MangoWM packages)"
    echo "  labwc      (Labwc stacking compositor packages)"
}

# Verify the actual QML module in addition to Arch package declarations.
audit_runtime() {
    local failed=0 pkg
    if ! command -v nixos-rebuild >/dev/null 2>&1 && command -v pacman >/dev/null 2>&1; then
        for pkg in quickshell qt6-multimedia qt6-multimedia-ffmpeg; do
            pacman -Q "$pkg" || { log_error "BLOCKED: missing $pkg; run scripts/packages.sh --repair-missing core"; failed=1; }
        done
    fi
    if command -v quickshell >/dev/null 2>&1; then
        QT_QPA_PLATFORM=offscreen timeout 15 quickshell -p "$HAKU_DIR/tools/probes/multimedia.qml" || failed=1
    else
        log_error "BLOCKED: quickshell is missing."
        failed=1
    fi
    return "$failed"
}

# CLI Entrypoint
while [[ $# -gt 0 ]]; do
    case "$1" in
        --audit-runtime)
            audit_runtime
            exit $?
            ;;
        --repair-missing)
            REPAIR_MISSING=1
            shift
            ;;
        --plan)
            PLAN_MODE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --list)
            list_groups
            exit 0
            ;;
        --all)
            INPUT_TARGETS+=("core" "service" "optional" "hyprland" "niri" "mango" "labwc")
            shift
            ;;
        --profile)
            PROFILE="${2:-}"
            if [[ "$PROFILE" != "install" && "$PROFILE" != "update" ]]; then
                log_error "Invalid profile: '$PROFILE'. Expected 'install' or 'update'."
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--plan | --dry-run] <group1> [group2...]"
            echo "       $0 [--plan | --dry-run] --profile install|update <wm1> [wm2...]"
            echo "       $0 [--plan | --dry-run] --all"
            echo "       $0 --repair-missing <group...> | --audit-runtime"
            echo "       $0 --list"
            exit 0
            ;;
        *)
            INPUT_TARGETS+=("$1")
            shift
            ;;
    esac
done

resolve_package_profile

if [[ ${#RESOLVED_GROUPS[@]} -eq 0 ]]; then
    echo "Usage: $0 [--plan | --dry-run] <group1> [group2...] | --profile <install|update> [wm...]" >&2
    exit 1
fi

if [[ "$PLAN_MODE" -eq 1 ]]; then
    print_package_plan
    exit 0
fi

# Independent groups continue after failure; the caller receives the aggregate result.
FAILED=0
for grp in "${RESOLVED_GROUPS[@]}"; do
    if install_group "$grp"; then
        log_ok "PACKAGE STATUS: $grp applied"
    else
        STATUS=$?
        log_error "PACKAGE STATUS: $grp failed exit=$STATUS"
        FAILED=1
    fi
done
exit "$FAILED"

#!/usr/bin/env bash
# HakuSpace Central Target Registry
# Single source of truth for managed dotfiles, configs, and system targets.

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

# Ensure paths from variables.sh are set if not already defined
if [[ -z "${SOURCE_CONFIG:-}" ]]; then
    source "$HAKU_DIR/scripts/variables.sh"
fi

# ==============================================================================
# STATIC CONFIGURATION LISTS & POLICIES
# ==============================================================================

# Names of configs deployed only once (not updated by update.sh or symlinked)
ONCE_CONFIG_NAMES=(
    "Thunar"
    "xfce4"
    "mpv"
    "btop"
    "cava"
    "mimeapps.list"
)

# Full paths in source tree for backward compatibility
ONCE_CONFIGS=(
    "$SOURCE_CONFIG/Thunar"
    "$SOURCE_CONFIG/xfce4"
    "$SOURCE_CONFIG/mpv"
    "$SOURCE_CONFIG/btop"
    "$SOURCE_CONFIG/cava"
    "$SOURCE_CONFIG/mimeapps.list"
)

# Names of configs in $SOURCE_CONFIG that require custom/WM-specific handling
SKIP_CONFIG_NAMES=(
    "hypr"
    "niri"
    "mango"
    "labwc"
)

# Full paths in source tree for backward compatibility
SKIP_CONFIGS=(
    "$SOURCE_CONFIG/hypr"
    "$SOURCE_CONFIG/niri"
    "$SOURCE_CONFIG/mango"
    "$SOURCE_CONFIG/labwc"
)

# Canonical Window Manager names
CANONICAL_WMS=("hyprland" "niri" "mango" "labwc")

# ==============================================================================
# PREDICATES & LOOKUPS
# ==============================================================================

registry_is_once_config() {
    local target="${1:-}"
    local base
    base="$(basename "$target")"

    local item
    for item in "${ONCE_CONFIG_NAMES[@]}"; do
        if [[ "$item" == "$base" || "$SOURCE_CONFIG/$item" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

registry_is_skip_config() {
    local target="${1:-}"
    local base
    base="$(basename "$target")"

    local item
    for item in "${SKIP_CONFIG_NAMES[@]}"; do
        if [[ "$item" == "$base" || "$SOURCE_CONFIG/$item" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

registry_canonical_wm_name() {
    local input="${1:-}"
    case "${input,,}" in
        1|hypr|hyprland)
            echo "hyprland"
            ;;
        2|niri)
            echo "niri"
            ;;
        3|mango|mangowm)
            echo "mango"
            ;;
        4|labwc)
            echo "labwc"
            ;;
        *)
            return 1
            ;;
    esac
}

registry_wm_display_name() {
    local input="${1:-}"
    case "${input,,}" in
        1|hypr|hyprland)
            echo "Hyprland"
            ;;
        2|niri)
            echo "Niri"
            ;;
        3|mango|mangowm)
            echo "MangoWM"
            ;;
        4|labwc)
            echo "Labwc"
            ;;
        *)
            echo "$input"
            ;;
    esac
}

registry_format_wm_list() {
    local formatted=()
    local wm
    for wm in "$@"; do
        formatted+=("$(registry_wm_display_name "$wm")")
    done
    local IFS=", "
    echo "${formatted[*]}"
}

# ==============================================================================
# CONFIG MAPPINGS (Formatted as source|destination)
# ==============================================================================

# Base common configs (auto-discovered normal configs + independent special files)
registry_get_common_configs() {
    # 1. Auto-discovered items in $SOURCE_CONFIG
    local item
    for item in "$SOURCE_CONFIG"/*; do
        [[ -e "$item" ]] || continue
        if registry_is_once_config "$item"; then
            continue
        fi
        if registry_is_skip_config "$item"; then
            continue
        fi
        local name
        name="$(basename "$item")"
        echo "$item|$DEST_CONFIG/$name"
    done

    # 2. Hyprland independent files (hypridle, hyprlock)
    echo "$SOURCE_CONFIG/hypr/hypridle.conf|$DEST_CONFIG/hypr/hypridle.conf"
    echo "$SOURCE_CONFIG/hypr/hyprlock.conf|$DEST_CONFIG/hypr/hyprlock.conf"
    echo "$SOURCE_CONFIG/hypr/hyprlock_tiny.conf|$DEST_CONFIG/hypr/hyprlock_tiny.conf"

    # 3. Home root dotfiles
    echo "$HOME_SRC_DIR/.nanorc|$HOME/.nanorc"
    echo "$HOME_SRC_DIR/.zshrc|$HOME/.zshrc"
}

# Once configs (install-only copy)
registry_get_once_configs() {
    local item
    for item in "${ONCE_CONFIG_NAMES[@]}"; do
        echo "$SOURCE_CONFIG/$item|$DEST_CONFIG/$item"
    done
}

# WM-specific configs
registry_get_wm_configs() {
    local wm="${1:-}"
    local canonical
    canonical="$(registry_canonical_wm_name "$wm")" || return 1

    case "$canonical" in
        hyprland)
            echo "$SOURCE_CONFIG/hypr/config|$DEST_CONFIG/hypr/config"
            echo "$SOURCE_CONFIG/hypr/hyprland.lua|$DEST_CONFIG/hypr/hyprland.lua"
            ;;
        niri)
            echo "$SOURCE_CONFIG/niri|$DEST_CONFIG/niri"
            ;;
        mango)
            echo "$SOURCE_CONFIG/mango|$DEST_CONFIG/mango"
            ;;
        labwc)
            echo "$SOURCE_CONFIG/labwc|$DEST_CONFIG/labwc"
            ;;
    esac
}

# Core scripts in src/core (flattened by basename into ~/.local/bin)
registry_get_core_scripts() {
    [[ -d "$SOURCE_CORE" ]] || return 0
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        [[ "$filename" == "README.md" ]] && continue
        echo "$file|$DEST_BIN/$filename"
    done < <(find "$SOURCE_CORE" -type f -print0)
}

# Managed destination paths (for rollback and doctor)
registry_get_managed_destinations() {
    # 1. Normal auto-discovered configs in $SOURCE_CONFIG
    local item
    for item in "$SOURCE_CONFIG"/*; do
        [[ -e "$item" ]] || continue
        if registry_is_once_config "$item"; then
            continue
        fi
        if registry_is_skip_config "$item"; then
            continue
        fi
        local name
        name="$(basename "$item")"
        echo "$DEST_CONFIG/$name"
    done

    # 2. Hypr targets
    echo "$DEST_CONFIG/hypr/config"
    echo "$DEST_CONFIG/hypr/hyprland.lua"
    echo "$DEST_CONFIG/hypr/hypridle.conf"
    echo "$DEST_CONFIG/hypr/hyprlock.conf"
    echo "$DEST_CONFIG/hypr/hyprlock_tiny.conf"

    # 3. Other WM targets
    echo "$DEST_CONFIG/niri"
    echo "$DEST_CONFIG/mango"
    echo "$DEST_CONFIG/labwc"

    # 4. Core scripts
    if [[ -d "$SOURCE_CORE" ]]; then
        while IFS= read -r -d '' file; do
            local filename
            filename="$(basename "$file")"
            [[ "$filename" == "README.md" ]] && continue
            echo "$DEST_BIN/$filename"
        done < <(find "$SOURCE_CORE" -type f -print0)
    fi

    # 5. Home dotfiles
    echo "$HOME/.nanorc"
    echo "$HOME/.zshrc"
}

# List all recognized module names for manual link / unlink
registry_list_modules() {
    # Auto-discovered modules
    local item
    for item in "$SOURCE_CONFIG"/*; do
        [[ -e "$item" ]] || continue
        local name
        name="$(basename "$item")"
        if registry_is_once_config "$item" || registry_is_skip_config "$item"; then
            continue
        fi
        echo "${name%.toml}"
    done

    # Window managers
    echo "hyprland"
    echo "niri"
    echo "mango"
    echo "labwc"

    # Special modules
    echo "hypridle"
    echo "hyprlock"
    echo "nanorc"
    echo "zshrc"
    echo "core"
}

# Resolve a single module name to its source|destination mappings
registry_resolve_module() {
    local mod="${1:-}"
    case "${mod,,}" in
        hyprland|hypr)
            registry_get_wm_configs "hyprland"
            ;;
        niri)
            registry_get_wm_configs "niri"
            ;;
        mango|mangowm)
            registry_get_wm_configs "mango"
            ;;
        labwc)
            registry_get_wm_configs "labwc"
            ;;
        core)
            registry_get_core_scripts
            ;;
        hypridle)
            echo "$SOURCE_CONFIG/hypr/hypridle.conf|$DEST_CONFIG/hypr/hypridle.conf"
            ;;
        hyprlock)
            echo "$SOURCE_CONFIG/hypr/hyprlock.conf|$DEST_CONFIG/hypr/hyprlock.conf"
            echo "$SOURCE_CONFIG/hypr/hyprlock_tiny.conf|$DEST_CONFIG/hypr/hyprlock_tiny.conf"
            ;;
        nano|nanorc|.nanorc)
            echo "$HOME_SRC_DIR/.nanorc|$HOME/.nanorc"
            ;;
        zsh|zshrc|.zshrc)
            echo "$HOME_SRC_DIR/.zshrc|$HOME/.zshrc"
            ;;
        starship|starship.toml)
            echo "$SOURCE_CONFIG/starship.toml|$DEST_CONFIG/starship.toml"
            ;;
        *)
            # Check directory in $SOURCE_CONFIG
            if [[ -d "$SOURCE_CONFIG/$mod" ]]; then
                echo "$SOURCE_CONFIG/$mod|$DEST_CONFIG/$mod"
            elif [[ -f "$SOURCE_CONFIG/$mod" ]]; then
                echo "$SOURCE_CONFIG/$mod|$DEST_CONFIG/$mod"
            elif [[ -f "$SOURCE_CONFIG/$mod.toml" ]]; then
                echo "$SOURCE_CONFIG/$mod.toml|$DEST_CONFIG/$mod.toml"
            else
                return 1
            fi
            ;;
    esac
}

# ==============================================================================
# HAKUCFG & STATE ASSETS
# ==============================================================================

registry_get_hakucfg_files() {
    cat <<'EOF'
setting.sh
wm/mango-custom.conf
wm/niri-custom.kdl
wm/hyprland-custom.lua
config/taskbar-pin-apps
config/hypridle.conf
config/kitty.conf
config/shell.fish
config/hyprlock.conf
general-menu.sh
EOF
}

registry_get_state_files() {
    cat <<'EOF'
taskbar-theme
rofi-theme.rasi
niri-animation.kdl
EOF
}

# ==============================================================================
# PACKAGES MAPPINGS
# ==============================================================================

registry_get_package_file() {
    local group="${1:-}"
    case "${group,,}" in
        core)
            echo "$PKG_CORE"
            ;;
        service)
            echo "$PKG_SERVICE"
            ;;
        optional)
            echo "$PKG_OPTIONAL"
            ;;
        hyprland|hypr)
            echo "$PKG_HYPRLAND"
            ;;
        niri)
            echo "$PKG_NIRI"
            ;;
        mango)
            echo "$PKG_MANGO"
            ;;
        labwc)
            echo "$PKG_LABWC"
            ;;
        *)
            return 1
            ;;
    esac
}

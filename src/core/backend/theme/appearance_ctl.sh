#!/usr/bin/env bash
# Appearance policy for optional assets; the safe accent engine is HakuSpace core.
set -u
export PATH="$HOME/.local/bin:$PATH"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source_library() {
    local name="$1" candidate
    for candidate in "$SCRIPT_DIR/$name" "$SCRIPT_DIR/../../lib/$name" "$HOME/.local/bin/$name"; do
        if [[ -f "$candidate" ]]; then
            source "$candidate"
            return 0
        fi
    done
    printf 'appearance: missing library %s\n' "$name" >&2
    return 1
}
source_library haku_appearance.sh || exit 1
case "$HAKU_ICON_ACCENT_MODE" in
    auto|on|off) ;;
    *) printf 'appearance: invalid HAKU_ICON_ACCENT_MODE: %s\n' "$HAKU_ICON_ACCENT_MODE" >&2; exit 2 ;;
esac

resolve_engine() {
    local candidate
    for candidate in "$SCRIPT_DIR/haku_icon_accent.py" "$SCRIPT_DIR/../../app/icon-accent/haku_icon_accent.py" "$HOME/.local/bin/haku_icon_accent.py"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'appearance: broken HakuSpace deployment: haku_icon_accent.py missing\n' >&2
    return 1
}

# Resolve the shared native-settings helper in source and deployed layouts.
resolve_settings_helper() {
    local candidate
    for candidate in "$SCRIPT_DIR/appearance_settings.py" "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../theme/appearance_settings.py"; do
        if [[ -f "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
    done
    printf 'appearance: GTK settings helper unavailable\n' >&2
    return 1
}

# User-selected third-party themes take precedence over the built-in defaults.
load_selected_themes() {
    local helper selected
    helper="$(resolve_settings_helper)" || return 1
    selected="$(python3 "$helper" current)" || return 1
    HAKU_GTK_THEME="$(jq -r '.gtk' <<< "$selected")" || return 1
    if [[ "$HAKU_ICON_THEME" != system ]]; then
        HAKU_ICON_THEME="$(jq -r '.icons' <<< "$selected")" || return 1
    fi
}

asset_warning() {
    printf 'appearance: warning: %s\n' "$*" >&2
    [[ "${HAKUSPACE_STRICT_ASSETS:-0}" != 1 ]]
}

cursor_directory() {
    local root
    for root in "$HOME/.icons" "${XDG_DATA_HOME:-$HOME/.local/share}/icons" /usr/local/share/icons /usr/share/icons; do
        if [[ -f "$root/$HAKU_CURSOR_THEME/index.theme" ]]; then
            printf '%s\n' "$root/$HAKU_CURSOR_THEME"
            return 0
        fi
    done
    return 1
}

gtk_directory() {
    local root
    for root in "$HOME/.themes" "${XDG_DATA_HOME:-$HOME/.local/share}/themes" /usr/local/share/themes /usr/share/themes; do
        if [[ -f "$root/$HAKU_GTK_THEME/index.theme" ]]; then
            printf '%s\n' "$root/$HAKU_GTK_THEME"
            return 0
        fi
    done
    return 1
}
gtk_installed() { gtk_directory >/dev/null; }

# Read validated Hikai preferences only when Hikai is the committed backend.
effective_mode() {
    local backend=classic candidate settings
    if [[ -f "$HOME/.local/state/hakuspace/state/[shell].backend" ]]; then
        read -r backend < "$HOME/.local/state/hakuspace/state/[shell].backend"
    fi
    if [[ "$backend" != hikai ]]; then
        echo dark
        return
    fi
    for candidate in "$SCRIPT_DIR/hikai_settings_ctl.py" "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../user/hikai_settings_ctl.py"; do
        if [[ -f "$candidate" ]]; then
            settings="$(python3 "$candidate" read)" || return 1
            jq -er '.values.appearance.colorMode | select(. == "dark" or . == "light")' <<< "$settings"
            return $?
        fi
    done
    printf 'appearance: Hikai settings controller unavailable\n' >&2
    return 1
}
icon_directory() {
    local root
    for root in "$HAKU_ICON_DIR" "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons" /usr/local/share/icons /usr/share/icons; do
        if [[ -f "$root/$HAKU_ICON_THEME/index.theme" ]]; then
            printf '%s\n' "$root/$HAKU_ICON_THEME"
            return 0
        fi
    done
    return 1
}

icons_installed() { [[ "$HAKU_ICON_THEME" == system ]] || icon_directory >/dev/null; }
cursor_installed() { cursor_directory >/dev/null; }
# Validate only this family's metadata; arbitrary themes never gain a guessed sibling.
managed_icon_variant() {
    python3 - "$HAKU_ICON_DIR/$1" <<'PYTHON'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
mode = {"Hikaide-Symbols": "dark", "Hikaide-Symbols-Light": "light"}.get(path.name)
if mode is None or path.is_symlink() or not path.is_dir():
    sys.exit(1)
metadata = path / ".hikaide-symbols.json"
try:
    if metadata.exists() or metadata.is_symlink():
        if metadata.is_symlink() or json.loads(metadata.read_text()) != {
                "family": "Hikaide-Symbols", "version": 2, "variant": mode}:
            sys.exit(1)
        print(mode)
    else:
        metadata = path / ".hikaide-symbols"
        if mode != "dark" or metadata.is_symlink() or metadata.read_text().rstrip("\n") != "Hikaide-Symbols managed theme v1":
            sys.exit(1)
        print("legacy")
except (OSError, ValueError):
    sys.exit(1)
PYTHON
}

# V2 installations reconcile both precolored themes; v1 and custom themes stay single-target.
icon_accent_targets() {
    local variant
    variant="$(managed_icon_variant "$HAKU_ICON_THEME")" || variant=''
    if [[ "$variant" == dark || "$variant" == light ]]; then
        printf 'Hikaide-Symbols %s\nHikaide-Symbols-Light %s\n' "$ACCENT_DARK" "$ACCENT_LIGHT"
    elif [[ "$HAKU_ICON_THEME" == Hikaide-Symbols-Light ]]; then
        printf '%s %s\n' "$HAKU_ICON_THEME" "$ACCENT_LIGHT"
    else
        printf '%s %s\n' "$HAKU_ICON_THEME" "$(theme_state_value accent)"
    fi
}

icon_accent_policy() {
    local variant theme
    if [[ "$HAKU_ICON_THEME" == system || "$HAKU_ICON_ACCENT_MODE" == off ||
            ( "$HAKU_ICON_THEME" != Hikaide-Symbols && "$HAKU_ICON_THEME" != Hikaide-Symbols-Light ) ]]; then
        echo disabled
        return
    fi
    if ! icons_installed; then
        echo missing
        return
    fi
    if [[ ! -f "$HAKU_ICON_DIR/$HAKU_ICON_THEME/index.theme" ]]; then
        echo not-applicable
        return
    fi
    variant="$(managed_icon_variant "$HAKU_ICON_THEME")" || variant=''
    if [[ -z "$variant" ]]; then
        echo not-applicable
        return
    fi
    if [[ "$variant" == dark || "$variant" == light ]]; then
        for theme in Hikaide-Symbols Hikaide-Symbols-Light; do
            if [[ ! -f "$HAKU_ICON_DIR/$theme/index.theme" ]]; then
                echo missing
                return
            fi
            if ! managed_icon_variant "$theme" >/dev/null; then
                echo not-applicable
                return
            fi
        done
    fi
    echo active
}

icon_accent_status() {
    local policy engine result theme accent
    policy="$(icon_accent_policy)"
    if [[ "$policy" != active ]]; then
        printf '%s\n' "$policy"
        return
    fi
    if ! engine="$(resolve_engine)"; then
        echo error
        return
    fi
    while read -r theme accent; do
        if [[ ! -O "$HAKU_ICON_DIR/$theme" ]]; then
            echo error
            return
        fi
        if python3 "$engine" --icons-dir "$HAKU_ICON_DIR" set "$accent" --theme "$theme" --dry-run >/dev/null 2>&1; then
            continue
        else
            result=$?
        fi
        if [[ "$result" == 4 ]]; then echo not-applicable; else echo error; fi
        return
    done < <(icon_accent_targets)
    echo active
}

status() {
    source_library haku_theme.sh || return 1
    printf 'gtk_theme=%s\nicon_theme=%s\ncursor_theme=%s\ncursor_size=%s\naccent=%s\n' \
        "$HAKU_GTK_THEME" "$HAKU_ICON_THEME" "$HAKU_CURSOR_THEME" "$HAKU_CURSOR_SIZE" "$(theme_state_value accent)"
    case "$HAKU_ICON_THEME" in
        Hikaide-Symbols|Hikaide-Symbols-Light) echo icon_theme_mode=managed ;;
        *) echo icon_theme_mode=external ;;
    esac
    printf 'icon_accent_mode=%s\nicon_accent_status=%s\n' "$HAKU_ICON_ACCENT_MODE" "$(icon_accent_status)"
    printf 'icon_accent_dark=%s\nicon_accent_light=%s\n' "$ACCENT_DARK" "$ACCENT_LIGHT"
    local mode
    mode="$(effective_mode)" || return 1
    printf 'effective_mode=%s\ngtk_theme_effective=%s\nicon_theme_effective=%s\n' \
        "$mode" "$(appearance_gtk_theme_for_mode "$mode")" "$(appearance_icon_theme_for_mode "$mode")"
    local component
    for component in gtk_installed icons_installed cursor_installed; do
        if "$component"; then printf '%s=yes\n' "$component"; else printf '%s=no\n' "$component"; fi
    done
}

verify() {
    local component failed=0
    for component in gtk_installed icons_installed cursor_installed; do
        case "$component:$HAKU_GTK_THEME:$HAKU_ICON_THEME" in
            gtk_installed:Hikaide:*|gtk_installed:Hikaide-Light:*) ;;
            gtk_installed:*) continue ;;
            icons_installed:*:Hikaide-Symbols|icons_installed:*:Hikaide-Symbols-Light) ;;
            icons_installed:*) continue ;;
        esac
        if ! "$component"; then
            printf 'appearance: missing %s\n' "$component" >&2
            failed=1
        fi
    done
    resolve_engine >/dev/null || failed=1
    return "$failed"
}

sync_accent() {
    local policy engine accent result theme previous index rollback failed=0
    local -a themes=() accents=() originals=()
    policy="$(icon_accent_policy)"
    case "$policy" in
        disabled|not-applicable) printf 'icon_accent_status=%s\n' "$policy"; return 0 ;;
        missing) asset_warning "$HAKU_ICON_THEME appearance pair unavailable; icons unchanged"; return $? ;;
    esac
    engine="$(resolve_engine)" || return 1
    source_library haku_theme.sh || return 1
    # Serialize reconciles, then reload the latest canonical colors after waiting.
    local lock_fd
    exec {lock_fd}> "$THEME_ROOT/icon-accent.lock" || return 1
    flock -x "$lock_fd" || return 1
    theme_load_state || return 1
    # Validate every target and capture old colors before changing either tree.
    while read -r theme accent; do
        if [[ ! -O "$HAKU_ICON_DIR/$theme" ]]; then
            printf 'appearance: refusing icon theme not owned by this user\n' >&2
            return 2
        fi
        [[ "$accent" =~ ^#[0-9a-fA-F]{6}$ ]] || { asset_warning 'Invalid canonical accent; icons unchanged'; return $?; }
        if python3 "$engine" --icons-dir "$HAKU_ICON_DIR" set "$accent" --theme "$theme" --dry-run >/dev/null; then
            :
        else
            result=$?
            if [[ "$result" == 4 ]]; then echo icon_accent_status=not-applicable; return 0; fi
            return "$result"
        fi
        previous="$(python3 "$engine" --icons-dir "$HAKU_ICON_DIR" status "$theme")" || return $?
        themes+=("$theme")
        accents+=("$accent")
        originals+=("$previous")
    done < <(icon_accent_targets)
    if (( ${#themes[@]} > 1 )); then
        for previous in "${originals[@]}"; do
            [[ "$previous" =~ ^#[0-9a-fA-F]{6}$ ]] || {
                printf 'appearance: ambiguous previous icon accent; pair unchanged\n' >&2
                return 2
            }
        done
    fi
    for index in "${!themes[@]}"; do
        if python3 "$engine" --icons-dir "$HAKU_ICON_DIR" set "${accents[index]}" --theme "${themes[index]}"; then
            continue
        else
            result=$?
        fi
        # Restore the failed tree too: an engine error may follow partial writes.
        if (( ${#themes[@]} > 1 )); then
            for ((rollback=index; rollback>=0; rollback--)); do
                if ! python3 "$engine" --icons-dir "$HAKU_ICON_DIR" set "${originals[rollback]}" --theme "${themes[rollback]}"; then
                    printf 'appearance: rollback failed for %s; inspect icon accent backups\n' "${themes[rollback]}" >&2
                    failed=1
                fi
            done
        fi
        printf 'appearance: icon accent engine failed (%s); core theme preserved\n' "$result" >&2
        (( failed == 0 )) || return 5
        return "$result"
    done
}

apply() {
    local mode="${1:-}" mode_only="${2:-0}" helper
    local change_gtk=0 change_icons=0
    [[ -n "$mode" ]] || mode="$(effective_mode)" || return 1
    [[ "$mode" == dark || "$mode" == light ]] || { echo 'appearance: mode must be dark or light' >&2; return 2; }
    if [[ "$mode_only" != 1 ]] && ! [[ "$HAKU_CURSOR_THEME" =~ ^[a-zA-Z0-9_.-]+$ && "$HAKU_CURSOR_SIZE" =~ ^[1-9][0-9]*$ ]]; then
        asset_warning 'Invalid cursor theme/size; appearance unchanged'
        return $?
    fi
    case "$HAKU_GTK_THEME" in Hikaide|Hikaide-Light) change_gtk=1 ;; esac
    case "$HAKU_ICON_THEME" in Hikaide-Symbols|Hikaide-Symbols-Light) change_icons=1 ;; esac
    local HAKU_GTK_THEME="$(appearance_gtk_theme_for_mode "$mode")"
    local HAKU_ICON_THEME="$(appearance_icon_theme_for_mode "$mode")"
    if { [[ "$change_gtk" == 1 ]] && ! gtk_installed; } || { [[ "$change_icons" == 1 ]] && ! icons_installed; }; then
        asset_warning "Missing assets for $mode; appearance unchanged"
        return $?
    fi
    if [[ "$mode_only" == 1 && "$change_gtk" == 0 && "$change_icons" == 0 ]]; then
        echo appearance_status=external
        return 0
    fi
    if [[ "$change_gtk" == 1 || "$change_icons" == 1 ]]; then
        helper="$(resolve_settings_helper)" || return 1
        local gtk='' icons='' directory=''
        if [[ "$change_gtk" == 1 ]]; then gtk="$HAKU_GTK_THEME"; directory="$(gtk_directory)"; fi
        if [[ "$change_icons" == 1 ]]; then icons="$HAKU_ICON_THEME"; fi
        python3 "$helper" "$gtk" "$icons" "$mode" "$directory" || return 1
    fi
    local setting value component failed=0
    local schema=org.gnome.desktop.interface
    local have_settings=0
    if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -qx "$schema"; then
        have_settings=1
    else
        asset_warning 'gsettings interface schema unavailable' || failed=1
    fi
    for setting in gtk-theme icon-theme cursor-theme cursor-size; do
        [[ "$mode_only" == 1 && "$setting" == cursor-* ]] && continue
        case "$setting" in
            gtk-theme) [[ "$change_gtk" == 1 ]] || continue; value="$HAKU_GTK_THEME"; component=gtk_installed ;;
            icon-theme) [[ "$change_icons" == 1 ]] || continue; value="$HAKU_ICON_THEME"; component=icons_installed ;;
            cursor-theme) value="$HAKU_CURSOR_THEME"; component=cursor_installed ;;
            cursor-size) value="$HAKU_CURSOR_SIZE"; component=cursor_installed ;;
        esac
        if ! "$component"; then
            asset_warning "Cannot activate missing $component" || failed=1
        elif [[ "$have_settings" == 1 ]]; then
            gsettings set "$schema" "$setting" "$value" || { asset_warning "Cannot set $setting" || failed=1; }
        fi
    done
    if [[ "$mode_only" != 1 ]] && cursor_installed; then
        local directory="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d" temporary
        mkdir -p "$directory" || return 1
        temporary="$(mktemp "$directory/90-hakuspace-cursor.conf.XXXXXX")" || return 1
        if ! printf 'XCURSOR_THEME=%s\nXCURSOR_SIZE=%s\n' "$HAKU_CURSOR_THEME" "$HAKU_CURSOR_SIZE" > "$temporary" ||
                ! mv -f "$temporary" "$directory/90-hakuspace-cursor.conf"; then
            rm -f "$temporary"
            return 1
        fi
        if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
            hyprctl setcursor "$HAKU_CURSOR_THEME" "$HAKU_CURSOR_SIZE" || { asset_warning 'Hyprland cursor activation failed' || failed=1; }
        fi
    fi
    return "$failed"
}

load_selected_themes || exit 1

case "${1:-}" in
    status) status ;;
    verify) verify ;;
    apply) apply ;;
    apply-mode) [[ $# == 2 ]] || { echo "Usage: appearance_ctl.sh apply-mode dark|light" >&2; exit 2; }; apply "$2" 1 ;;
    sync-accent) sync_accent ;;
    *) echo 'Usage: appearance_ctl.sh {status|verify|apply|apply-mode dark|light|sync-accent}' >&2; exit 2 ;;
esac

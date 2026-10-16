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

gtk_installed() { [[ -f "$HOME/.themes/$HAKU_GTK_THEME/index.theme" ]]; }
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
icon_accent_policy() {
    if [[ "$HAKU_ICON_THEME" == system || "$HAKU_ICON_ACCENT_MODE" == off ||
            ( "$HAKU_ICON_ACCENT_MODE" == auto && "$HAKU_ICON_THEME" != Hikaide-Symbols ) ]]; then
        echo disabled
    elif ! icons_installed; then
        echo missing
    elif [[ ! -f "$HAKU_ICON_DIR/$HAKU_ICON_THEME/index.theme" ]]; then
        echo not-applicable
    elif [[ "$HAKU_ICON_ACCENT_MODE" == auto ]] && {
        [[ -L "$HAKU_ICON_DIR/$HAKU_ICON_THEME" || -L "$HAKU_ICON_DIR/$HAKU_ICON_THEME/.hikaide-symbols" ]] ||
        [[ ! -f "$HAKU_ICON_DIR/$HAKU_ICON_THEME/.hikaide-symbols" ]] ||
        [[ "$(cat "$HAKU_ICON_DIR/$HAKU_ICON_THEME/.hikaide-symbols")" != 'Hikaide-Symbols managed theme v1' ]];
    }; then
        echo not-applicable
    else
        echo active
    fi
}

icon_accent_status() {
    local policy engine result
    policy="$(icon_accent_policy)"
    if [[ "$policy" != active ]]; then
        printf '%s\n' "$policy"
    elif ! engine="$(resolve_engine)"; then
        echo error
    elif [[ ! -O "$HAKU_ICON_DIR/$HAKU_ICON_THEME" ]]; then
        echo error
    elif python3 "$engine" --icons-dir "$HAKU_ICON_DIR" set "$(theme_state_value accent)" --theme "$HAKU_ICON_THEME" --dry-run >/dev/null 2>&1; then
        echo active
    else
        result=$?
        if [[ "$result" == 4 ]]; then echo not-applicable; else echo error; fi
    fi
}

status() {
    source_library haku_theme.sh || return 1
    printf 'gtk_theme=%s\nicon_theme=%s\ncursor_theme=%s\ncursor_size=%s\naccent=%s\n' \
        "$HAKU_GTK_THEME" "$HAKU_ICON_THEME" "$HAKU_CURSOR_THEME" "$HAKU_CURSOR_SIZE" "$(theme_state_value accent)"
    if [[ "$HAKU_ICON_THEME" == system ]]; then
        echo icon_theme_mode=external
    else
        echo icon_theme_mode=managed
    fi
    printf 'icon_accent_mode=%s\nicon_accent_status=%s\n' "$HAKU_ICON_ACCENT_MODE" "$(icon_accent_status)"
    local component
    for component in gtk_installed icons_installed cursor_installed; do
        if "$component"; then printf '%s=yes\n' "$component"; else printf '%s=no\n' "$component"; fi
    done
}

verify() {
    local component failed=0
    for component in gtk_installed icons_installed cursor_installed; do
        if ! "$component"; then
            printf 'appearance: missing %s\n' "$component" >&2
            failed=1
        fi
    done
    resolve_engine >/dev/null || failed=1
    return "$failed"
}

sync_accent() {
    local policy engine accent result
    policy="$(icon_accent_policy)"
    case "$policy" in
        disabled|not-applicable) printf 'icon_accent_status=%s\n' "$policy"; return 0 ;;
        missing) asset_warning "$HAKU_ICON_THEME unavailable; core theme preserved"; return $? ;;
    esac
    engine="$(resolve_engine)" || return 1
    if [[ ! -O "$HAKU_ICON_DIR/$HAKU_ICON_THEME" ]]; then
        printf 'appearance: refusing icon theme not owned by this user\n' >&2
        return 2
    fi
    source_library haku_theme.sh || return 1
    accent="$(theme_state_value accent)"
    [[ "$accent" =~ ^#[0-9a-fA-F]{6}$ ]] || { asset_warning 'Invalid canonical accent; icons unchanged'; return $?; }
    if python3 "$engine" --icons-dir "$HAKU_ICON_DIR" set "$accent" --theme "$HAKU_ICON_THEME"; then
        return 0
    else
        result=$?
    fi
    if [[ "$result" == 4 ]]; then
        echo icon_accent_status=not-applicable
        return 0
    fi
    printf 'appearance: icon accent engine failed (%s); core theme preserved\n' "$result" >&2
    return "$result"
}

apply() {
    [[ "$HAKU_CURSOR_THEME" =~ ^[a-zA-Z0-9_.-]+$ && "$HAKU_CURSOR_SIZE" =~ ^[1-9][0-9]*$ ]] || {
        asset_warning 'Invalid cursor theme/size; appearance unchanged'
        return $?
    }
    local setting value component failed=0
    local schema=org.gnome.desktop.interface
    local have_settings=0
    if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -qx "$schema"; then
        have_settings=1
    else
        asset_warning 'gsettings interface schema unavailable' || failed=1
    fi
    for setting in gtk-theme icon-theme cursor-theme cursor-size; do
        case "$setting" in
            gtk-theme) value="$HAKU_GTK_THEME"; component=gtk_installed ;;
            icon-theme) [[ "$HAKU_ICON_THEME" == system ]] && continue; value="$HAKU_ICON_THEME"; component=icons_installed ;;
            cursor-theme) value="$HAKU_CURSOR_THEME"; component=cursor_installed ;;
            cursor-size) value="$HAKU_CURSOR_SIZE"; component=cursor_installed ;;
        esac
        if ! "$component"; then
            asset_warning "Cannot activate missing $component" || failed=1
        elif [[ "$have_settings" == 1 ]]; then
            gsettings set "$schema" "$setting" "$value" || { asset_warning "Cannot set $setting" || failed=1; }
        fi
    done
    if cursor_installed; then
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

case "${1:-}" in
    status) status ;;
    verify) verify ;;
    apply) apply ;;
    sync-accent) sync_accent ;;
    *) echo 'Usage: appearance_ctl.sh {status|verify|apply|sync-accent}' >&2; exit 2 ;;
esac

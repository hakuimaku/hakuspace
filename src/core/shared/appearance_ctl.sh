#!/usr/bin/env bash
# Appearance policy for optional assets; the safe accent engine is HakuSpace core.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" ]]; then
    source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
    source "$HAKU_BIN_DIR/haku_appearance.sh" || exit 1
else
    source "$SCRIPT_DIR/../lib/haku_state.sh" || exit 1
    source "$SCRIPT_DIR/../lib/haku_appearance.sh" || exit 1
fi
export PATH="$HAKU_BIN_DIR:$SCRIPT_DIR:$PATH"
case "$HAKU_ICON_ACCENT_MODE" in
    auto|on|off) ;;
    *) printf 'appearance: invalid HAKU_ICON_ACCENT_MODE: %s\n' "$HAKU_ICON_ACCENT_MODE" >&2; exit 2 ;;
esac

resolve_engine() {
    local candidate
    for candidate in "$HAKU_BIN_DIR/haku_icon_accent.py" "$SCRIPT_DIR/haku_icon_accent.py"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'appearance: broken HakuSpace deployment: haku_icon_accent.py missing\n' >&2
    return 1
}

# Resolve the shared native-settings helper in deployed layout.
resolve_settings_helper() {
    local candidate
    for candidate in "$HAKU_BIN_DIR/appearance_settings.py" "$SCRIPT_DIR/appearance_settings.py"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'appearance: GTK settings helper unavailable\n' >&2
    return 1
}

# Read the currently persisted cursor theme before applying a backend/mode change.
read_current_cursor_theme() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/90-hakuspace-cursor.conf" line val
    if command -v gsettings >/dev/null 2>&1; then
        val="$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || true)"
        val="${val#\'}"
        val="${val%\'}"
        if [[ -n "$val" && "$val" != *"'"* && "$val" != *$'\n'* ]]; then
            printf '%s\n' "$val"
            return 0
        fi
    fi
    if [[ -f "$conf" && ! -L "$conf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" == XCURSOR_THEME=* ]]; then
                printf '%s\n' "${line#XCURSOR_THEME=}"
                return 0
            fi
        done < "$conf"
    fi
    printf '%s\n' "$HAKU_CURSOR_THEME"
}

# User-selected third-party themes take precedence over the built-in defaults.
load_selected_themes() {
    local helper selected
    helper="$(resolve_settings_helper)" || return 1
    selected="$(python3 "$helper" current)" || return 1
    # Keep observed selection separate from the special system-icon policy.
    SELECTED_THEMES="$selected"
    HAKU_GTK_THEME="$(jq -r '.gtk' <<< "$selected")" || return 1
    if [[ "$HAKU_ICON_THEME" != system ]]; then
        HAKU_ICON_THEME="$(jq -r '.icons' <<< "$selected")" || return 1
    fi
    CURRENT_CURSOR_THEME="$(read_current_cursor_theme)"
    if [[ "${HAKU_CURSOR_EXPLICIT:-0}" == 0 && -n "$CURRENT_CURSOR_THEME" ]]; then
        HAKU_CURSOR_THEME="$CURRENT_CURSOR_THEME"
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
effective_backend() {
    local backend=hikai
    if [[ -f "$HOME/.local/state/hakuspace/state/[shell].backend" ]]; then
        read -r backend < "$HOME/.local/state/hakuspace/state/[shell].backend"
    fi
    case "$backend" in
        classic) echo classic ;;
        *) echo hikai ;;
    esac
}

effective_mode() {
    local backend="" settings
    if [[ -f "$HOME/.local/state/hakuspace/state/[shell].backend" ]]; then
        read -r backend < "$HOME/.local/state/hakuspace/state/[shell].backend"
    fi
    if [[ "$backend" == classic ]]; then
        echo light
        return
    fi
    if [[ "$backend" != hikai ]]; then
        echo dark
        return
    fi
    local hikai_ctl="$HAKU_BIN_DIR/hikai_settings_ctl.py"
    [[ -f "$hikai_ctl" ]] || hikai_ctl="$SCRIPT_DIR/../hikai/hikai_settings_ctl.py"
    if [[ -f "$hikai_ctl" ]]; then
        settings="$(python3 "$hikai_ctl" read)" || return 1
        jq -er '.values.appearance.colorMode | select(. == "dark" or . == "light")' <<< "$settings"
        return $?
    fi
    printf 'appearance: Hikai settings controller unavailable\n' >&2
    return 1
}
# Share icon discovery and managed-target validation across every operation.
resolve_icons_helper() {
    local candidate
    for candidate in "$HAKU_BIN_DIR/appearance_icons.py" "$SCRIPT_DIR/appearance_icons.py"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'appearance: icon resolver unavailable\n' >&2
    return 1
}

icon_resolution() {
    local helper
    helper="$(resolve_icons_helper)" || return 1
    python3 "$helper" "$HAKU_ICON_THEME" "$HAKU_ICON_ACCENT_MODE"
}

icon_directory() {
    icon_resolution | jq -er '.directory // empty'
}

icons_installed() { [[ "$HAKU_ICON_THEME" == system ]] || icon_directory >/dev/null; }
cursor_installed() { cursor_directory >/dev/null; }

# Paths and variants come from the same validated resolver snapshot.
icon_accent_targets() {
    local path variant
    while IFS=$'\t' read -r path variant; do
        if [[ "$variant" == light ]]; then
            printf '%s\t%s\n' "$path" "$ACCENT_LIGHT"
        else
            printf '%s\t%s\n' "$path" "$ACCENT_DARK"
        fi
    done < <(jq -r '.targets[] | [.directory, .variant] | @tsv' <<< "$1")
}

icon_accent_status() {
    local resolution policy engine result path accent
    resolution="$(icon_resolution)" || { echo error; return; }
    policy="$(jq -r '.policy' <<< "$resolution")"
    if [[ "$policy" != active ]]; then
        printf '%s\n' "$policy"
        return
    fi
    engine="$(resolve_engine)" || { echo error; return; }
    while IFS=$'\t' read -r path accent; do
        if python3 "$engine" apply --theme-dir "$path" --accent "$accent" --no-backup --dry-run >/dev/null 2>&1; then
            continue
        else
            result=$?
        fi
        if [[ "$result" == 4 ]]; then echo not-applicable; else echo error; fi
        return
    done < <(icon_accent_targets "$resolution")
    echo active
}

status() {
    if [[ -f "$HAKU_BIN_DIR/haku_theme.sh" ]]; then
        source "$HAKU_BIN_DIR/haku_theme.sh" || return 1
    else
        source "$SCRIPT_DIR/../lib/haku_theme.sh" || return 1
    fi
    printf 'gtk_theme=%s\nicon_theme=%s\ncursor_theme=%s\ncursor_size=%s\naccent=%s\n' \
        "$HAKU_GTK_THEME" "$HAKU_ICON_THEME" "$HAKU_CURSOR_THEME" "$HAKU_CURSOR_SIZE" "$(theme_state_value accent)"
    if appearance_is_managed_icons "$HAKU_ICON_THEME"; then
        echo icon_theme_mode=managed
    else
        echo icon_theme_mode=external
    fi
    printf 'icon_accent_mode=%s\nicon_accent_status=%s\n' "$HAKU_ICON_ACCENT_MODE" "$(icon_accent_status)"
    printf 'icon_accent_dark=%s\nicon_accent_light=%s\n' "$ACCENT_DARK" "$ACCENT_LIGHT"
    local mode backend
    mode="$(effective_mode)" || return 1
    backend="$(effective_backend)"
    printf 'effective_mode=%s\ngtk_theme_effective=%s\nicon_theme_effective=%s\n' \
        "$mode" "$(appearance_gtk_theme_for_mode "$mode" "$backend")" "$(appearance_icon_theme_for_mode "$mode" "$backend")"
    local component
    for component in gtk_installed icons_installed cursor_installed; do
        if "$component"; then printf '%s=yes\n' "$component"; else printf '%s=no\n' "$component"; fi
    done
}

verify() {
    local component failed=0
    for component in gtk_installed icons_installed cursor_installed; do
        case "$component" in
            gtk_installed) appearance_is_managed_gtk "$HAKU_GTK_THEME" || continue ;;
            icons_installed) appearance_is_managed_icons "$HAKU_ICON_THEME" || continue ;;
        esac
        if ! "$component"; then
            printf 'appearance: missing %s\n' "$component" >&2
            failed=1
        fi
    done
    resolve_engine >/dev/null || failed=1
    return "$failed"
}

sync_accent() (
    local resolution policy engine accent result path helper lock_root lock_fd permissions
    resolution="$(icon_resolution)" || return 1
    policy="$(jq -r '.policy' <<< "$resolution")"
    case "$policy" in
        disabled|not-applicable) printf 'icon_accent_status=%s\n' "$policy"; return 0 ;;
        missing) asset_warning "$HAKU_ICON_THEME appearance pair unavailable; icons unchanged"; return $? ;;
    esac
    source "$HAKU_BIN_DIR/haku_theme.sh" || return 1
    # Keep the pair lock ephemeral and reload canonical colors after waiting.
    lock_root="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}/hakuspace-$UID}"
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then lock_root+="/hakuspace"; fi
    for path in "$lock_root" "$lock_root/appearance"; do
        (umask 077; mkdir -p "$path") || return 1
        permissions="$(stat -c %a -- "$path")" || return 1
        if [[ -L "$path" || ! -O "$path" ]] || (( (8#$permissions & 8#022) != 0 )); then
            printf 'appearance: unsafe runtime lock directory\n' >&2
            return 2
        fi
    done
    if [[ -L "$lock_root/appearance/icon-accent.lock" ]]; then
        printf 'appearance: unsafe runtime lock file\n' >&2
        return 2
    fi
    exec {lock_fd}> "$lock_root/appearance/icon-accent.lock" || return 1
    flock -x "$lock_fd" || return 1
    theme_load_state || return 1
    resolution="$(icon_resolution)" || return 1
    policy="$(jq -r '.policy' <<< "$resolution")"
    case "$policy" in
        disabled|not-applicable) printf 'icon_accent_status=%s\n' "$policy"; return 0 ;;
        missing) asset_warning "$HAKU_ICON_THEME appearance pair unavailable; icons unchanged"; return $? ;;
    esac
    engine="$(resolve_engine)" || return 1
    # Preflight the full target set before the first atomic SVG replacement.
    while IFS=$'\t' read -r path accent; do
        [[ "$accent" =~ ^#[0-9a-fA-F]{6}$ ]] || { printf 'appearance: invalid canonical accent\n' >&2; return 2; }
        if python3 "$engine" apply --theme-dir "$path" --accent "$accent" --no-backup --dry-run >/dev/null; then
            continue
        else
            result=$?
        fi
        if [[ "$result" == 4 ]]; then echo icon_accent_status=not-applicable; return 0; fi
        return "$result"
    done < <(icon_accent_targets "$resolution")
    while IFS=$'\t' read -r path accent; do
        if python3 "$engine" apply --theme-dir "$path" --accent "$accent" --no-backup; then
            continue
        else
            result=$?
        fi
        printf 'appearance: icon accent engine failed (%s); core theme preserved; retry sync-accent\n' "$result" >&2
        return "$result"
    done < <(icon_accent_targets "$resolution")
    helper="$(resolve_icons_helper)" || return 1
    python3 "$helper" cleanup
)

apply() {
    local mode="${1:-}" mode_only="${2:-0}" backend="${3:-}" helper
    local backend_explicit=0
    [[ -n "$backend" ]] && backend_explicit=1
    local change_gtk=0 change_icons=0 change_cursor=0
    local previous_cursor="${CURRENT_CURSOR_THEME:-$HAKU_CURSOR_THEME}"
    if [[ -z "$backend" ]]; then
        if [[ "$mode_only" == 1 && "$mode" == light ]]; then
            backend=hikai
        else
            backend="$(effective_backend)"
        fi
    fi
    [[ -n "$mode" ]] || mode="$(effective_mode)" || return 1
    [[ "$mode" == dark || "$mode" == light ]] || { echo 'appearance: mode must be dark or light' >&2; return 2; }
    if [[ "$mode_only" != 1 || "$backend_explicit" == 1 ]] && ! [[ "$HAKU_CURSOR_THEME" =~ ^[a-zA-Z0-9_.-]+$ && "$HAKU_CURSOR_SIZE" =~ ^[1-9][0-9]*$ ]]; then
        asset_warning 'Invalid cursor theme/size; appearance unchanged'
        return $?
    fi
    if appearance_is_managed_gtk "$HAKU_GTK_THEME"; then change_gtk=1; fi
    if appearance_is_managed_icons "$HAKU_ICON_THEME"; then change_icons=1; fi
    if [[ "$mode_only" != 1 || "$backend_explicit" == 1 ]] && appearance_is_managed_cursor "$HAKU_CURSOR_THEME"; then
        change_cursor=1
    fi
    local HAKU_GTK_THEME="$(appearance_gtk_theme_for_mode "$mode" "$backend")"
    local HAKU_ICON_THEME="$(appearance_icon_theme_for_mode "$mode" "$backend")"
    local HAKU_CURSOR_THEME="$HAKU_CURSOR_THEME"
    if [[ "$change_cursor" == 1 ]]; then
        local candidate_cursor
        candidate_cursor="$(appearance_cursor_theme_for_mode "$mode" "$backend" "$HAKU_CURSOR_THEME")"
        if HAKU_CURSOR_THEME="$candidate_cursor" cursor_installed; then
            HAKU_CURSOR_THEME="$candidate_cursor"
        elif [[ "$backend_explicit" == 1 ]]; then
            HAKU_CURSOR_THEME="$candidate_cursor"
        fi
    fi
    if { [[ "$change_gtk" == 1 ]] && ! gtk_installed; } ||
            { [[ "$change_icons" == 1 ]] && ! icons_installed; } ||
            { [[ "$backend_explicit" == 1 && "$change_cursor" == 1 ]] && ! cursor_installed; }; then
        asset_warning "Missing assets for $mode; appearance unchanged"
        return $?
    fi
    if [[ "$mode_only" == 1 && "$change_gtk" == 0 && "$change_icons" == 0 && "$change_cursor" == 0 ]]; then
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
    local apply_cursor=0
    if [[ "$mode_only" != 1 ]]; then
        apply_cursor=1
    elif [[ "$backend_explicit" == 1 && "$change_cursor" == 1 ]]; then
        apply_cursor=1
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
        [[ "$apply_cursor" == 0 && "$setting" == cursor-* ]] && continue
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
    if [[ "$apply_cursor" == 1 ]] && cursor_installed; then
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
        if [[ "$change_cursor" == 1 && "$previous_cursor" != "$HAKU_CURSOR_THEME" ]]; then
            local rt_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace"
            if [[ -d "$rt_dir" && -w "$rt_dir" ]]; then
                printf '%s\n' "$HAKU_CURSOR_THEME" > "$rt_dir/cursor-changed" 2>/dev/null || true
            fi
        fi
    fi
    # Strict setup/recovery verifies managed selection rather than trusting successful writes.
    if [[ "${HAKUSPACE_STRICT_ASSETS:-0}" == 1 && ( "$change_gtk" == 1 || "$change_icons" == 1 ) ]]; then
        helper="$(resolve_settings_helper)" || return 1
        local selected
        selected="$(python3 "$helper" current --strict)" || return 1
        if { [[ "$change_gtk" == 1 ]] && [[ "$(jq -r '.gtk' <<< "$selected")" != "$HAKU_GTK_THEME" ]]; } ||
                { [[ "$change_icons" == 1 ]] && [[ "$(jq -r '.icons' <<< "$selected")" != "$HAKU_ICON_THEME" ]]; }; then
            printf 'appearance: activation not confirmed: expected GTK=%s icons=%s; selected=%s\n' \
                "$HAKU_GTK_THEME" "$HAKU_ICON_THEME" "$selected" >&2
            failed=1
        fi
    fi
    return "$failed"
}

# Explicit consent may select installed managed assets without changing the shell backend.
activate() {
    local component="$1" backend mode helper selected expected actual
    backend="$(effective_backend)"
    case "$component" in
        gtk) HAKU_GTK_THEME=Hikaide ;;
        cassettk) HAKU_GTK_THEME=Cassettk ;;
        symbols) HAKU_ICON_THEME=Hikaide-Symbols ;;
        cassetton) HAKU_ICON_THEME=Cassetton ;;
        *) echo 'appearance: activate expects gtk, cassettk, symbols or cassetton' >&2; return 2 ;;
    esac
    mode="$(effective_mode)" || return 1
    HAKUSPACE_STRICT_ASSETS=1 apply "$mode" 1 "$backend" || return 1
    helper="$(resolve_settings_helper)" || return 1
    selected="$(python3 "$helper" current --strict)" || return 1
    case "$component" in
        gtk|cassettk)
            expected="$(appearance_gtk_theme_for_mode "$mode" "$backend")"
            actual="$(jq -r '.gtk' <<< "$selected")" ;;
        symbols|cassetton)
            expected="$(appearance_icon_theme_for_mode "$mode" "$backend")"
            actual="$(jq -r '.icons' <<< "$selected")" ;;
    esac
    if [[ "$actual" != "$expected" ]]; then
        printf 'appearance: activation not confirmed: expected %s, selected %s\n' "$expected" "$actual" >&2
        return 1
    fi
}

load_selected_themes || exit 1

case "${1:-}" in
    status) status ;;
    selection) printf '%s\n' "$SELECTED_THEMES" ;;
    activate) [[ $# == 2 ]] || exit 2; activate "$2" ;;
    verify) verify ;;
    apply) apply ;;
    apply-mode) [[ $# -ge 2 && $# -le 3 ]] || { echo "Usage: appearance_ctl.sh apply-mode dark|light [hikai|classic]" >&2; exit 2; }; apply "$2" 1 "${3:-}" ;;
    sync-accent) sync_accent ;;
    *) echo 'Usage: appearance_ctl.sh {status|selection|verify|activate gtk|cassettk|symbols|cassetton|apply|apply-mode dark|light [hikai|classic]|sync-accent}' >&2; exit 2 ;;
esac

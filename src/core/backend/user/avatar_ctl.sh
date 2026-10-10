#!/usr/bin/env bash

# Headless avatar controller for HakuSpace user-data.
# Owns avatar state validation, atomic copy, persistence, and cleanup.
# UI and file pickers belong in frontend/QML layers.

set -u

USER_DIR="${HAKUSPACE_USER_DIR:-$HOME/.local/share/hakuspace/user}"
MANIFEST_FILE="$USER_DIR/avatar.path"

is_safe_basename() {
    local name="$1"
    [[ -n "$name" ]] || return 1
    [[ "$name" != *"/"* ]] || return 1
    [[ "$name" != *".."* ]] || return 1
    [[ "$name" != *$'\n'* ]] || return 1
    case "$name" in
        avatar.png|avatar.jpg|avatar.jpeg|avatar.webp) return 0 ;;
        *) return 1 ;;
    esac
}

cmd_current() {
    [[ -f "$MANIFEST_FILE" ]] || return 0
    local manifest
    manifest="$(head -n 1 "$MANIFEST_FILE" 2>/dev/null || true)"
    if ! is_safe_basename "$manifest"; then
        return 0
    fi
    local current_file="$USER_DIR/$manifest"
    if [[ -f "$current_file" && -r "$current_file" ]]; then
        printf '%s\n' "$current_file"
    fi
    return 0
}

cmd_set() {
    if [[ $# -ne 1 ]]; then
        printf 'avatar_ctl.sh set: requires exactly one source argument\n' >&2
        return 1
    fi

    local src="$1"
    if [[ -z "$src" ]]; then
        printf 'avatar_ctl.sh set: source path cannot be empty\n' >&2
        return 1
    fi

    if [[ "$src" == *$'\n'* ]]; then
        printf 'avatar_ctl.sh set: source path cannot contain newlines\n' >&2
        return 1
    fi

    if [[ ! -f "$src" || ! -r "$src" ]]; then
        printf 'avatar_ctl.sh set: file does not exist or is not readable: %s\n' "$src" >&2
        return 1
    fi

    local mime
    mime="$(file -b --mime-type "$src" 2>/dev/null || true)"
    local ext=""
    case "$mime" in
        image/png)
            ext="png"
            ;;
        image/jpeg)
            local lower_src="${src,,}"
            if [[ "$lower_src" == *.jpeg ]]; then
                ext="jpeg"
            else
                ext="jpg"
            fi
            ;;
        image/webp)
            ext="webp"
            ;;
        *)
            printf 'avatar_ctl.sh set: unsupported image mime-type (%s): %s\n' "$mime" "$src" >&2
            return 1
            ;;
    esac

    local previous_basename=""
    if [[ -f "$MANIFEST_FILE" ]]; then
        local raw_prev
        raw_prev="$(head -n 1 "$MANIFEST_FILE" 2>/dev/null || true)"
        if is_safe_basename "$raw_prev"; then
            previous_basename="$raw_prev"
        fi
    fi

    # Restrictive umask for user-data mutations
    local saved_umask
    saved_umask="$(umask)"
    umask 077

    mkdir -p "$USER_DIR" || {
        umask "$saved_umask"
        printf 'avatar_ctl.sh set: failed to create user directory: %s\n' "$USER_DIR" >&2
        return 1
    }

    local target_basename="avatar.$ext"
    local target_path="$USER_DIR/$target_basename"
    local temp_file="$USER_DIR/.avatar_tmp.$$.$ext"
    local manifest_temp="$USER_DIR/.avatar.path.tmp.$$"

    # Copy to temporary file and enforce 0600 permissions
    if ! cp "$src" "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        umask "$saved_umask"
        printf 'avatar_ctl.sh set: failed to copy source image: %s\n' "$src" >&2
        return 1
    fi
    chmod 600 "$temp_file"

    # Atomically replace active avatar image
    if ! mv -f "$temp_file" "$target_path"; then
        rm -f "$temp_file"
        umask "$saved_umask"
        printf 'avatar_ctl.sh set: failed to install avatar image: %s\n' "$target_path" >&2
        return 1
    fi
    chmod 600 "$target_path"

    # Atomically update avatar.path manifest with 0600 permissions
    printf '%s\n' "$target_basename" > "$manifest_temp"
    chmod 600 "$manifest_temp" 2>/dev/null || true
    if ! mv -f "$manifest_temp" "$MANIFEST_FILE"; then
        rm -f "$manifest_temp" 2>/dev/null || true
        umask "$saved_umask"
        printf 'avatar_ctl.sh set: failed to update manifest: %s\n' "$MANIFEST_FILE" >&2
        return 1
    fi
    chmod 600 "$MANIFEST_FILE" 2>/dev/null || true

    # Safely remove previous avatar if different extension
    if [[ -n "$previous_basename" && "$previous_basename" != "$target_basename" ]]; then
        rm -f "$USER_DIR/$previous_basename" 2>/dev/null || true
    fi

    umask "$saved_umask"
    printf '%s\n' "$target_path"
    return 0
}

usage() {
    printf 'Usage: avatar_ctl.sh <current|set <path>>\n' >&2
    return 1
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        return 1
    fi

    local action="$1"
    shift

    case "$action" in
        current)
            if [[ $# -ne 0 ]]; then
                printf 'avatar_ctl.sh current: accepts no arguments\n' >&2
                return 1
            fi
            cmd_current
            ;;
        set)
            cmd_set "$@"
            ;;
        *)
            usage
            return 1
            ;;
    esac
}

main "$@"

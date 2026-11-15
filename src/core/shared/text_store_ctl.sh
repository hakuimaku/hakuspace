#!/usr/bin/env bash

# Headless text store controller for HakuSpace user notes and bio.
# Owns storage initialization, directory permissions (0700), file permissions (0600),
# atomic persistence, and reads for Bio (~/.local/share/hakuspace/user/bio.txt)
# and Quick Note (/tmp/hakuspace-<uid>/quick-note.txt).

set -u

USER_DIR="${HAKUSPACE_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/hakuspace/user}"
BIO_PATH="$USER_DIR/bio.txt"

UID_VAL="$(id -u 2>/dev/null || echo 1000)"
SCRATCH_DIR="${HAKUSPACE_SCRATCH_DIR:-/tmp/hakuspace-${UID_VAL}}"
SCRATCH_PATH="$SCRATCH_DIR/quick-note.txt"

ensure_user_dir() {
    if [[ -L "$USER_DIR" ]]; then
        printf 'text_store_ctl.sh: rejected symlink at user directory: %s\n' "$USER_DIR" >&2
        return 1
    fi
    if [[ -e "$USER_DIR" && ! -d "$USER_DIR" ]]; then
        printf 'text_store_ctl.sh: user directory path is not a directory: %s\n' "$USER_DIR" >&2
        return 1
    fi
    if [[ ! -d "$USER_DIR" ]]; then
        mkdir -m 0700 -p "$USER_DIR" || {
            printf 'text_store_ctl.sh: failed to create user directory: %s\n' "$USER_DIR" >&2
            return 1
        }
    fi
    local owner_uid
    owner_uid="$(stat -c '%u' "$USER_DIR" 2>/dev/null || echo '')"
    if [[ -n "$owner_uid" && "$owner_uid" != "$UID_VAL" ]]; then
        printf 'text_store_ctl.sh: user directory owner mismatch: expected %s, got %s\n' "$UID_VAL" "$owner_uid" >&2
        return 1
    fi
    chmod 700 "$USER_DIR" 2>/dev/null || true
}

ensure_scratch_dir() {
    if [[ -L "$SCRATCH_DIR" ]]; then
        printf 'text_store_ctl.sh: rejected symlink at scratch directory: %s\n' "$SCRATCH_DIR" >&2
        return 1
    fi
    if [[ -e "$SCRATCH_DIR" && ! -d "$SCRATCH_DIR" ]]; then
        printf 'text_store_ctl.sh: scratch directory path is not a directory: %s\n' "$SCRATCH_DIR" >&2
        return 1
    fi
    if [[ ! -d "$SCRATCH_DIR" ]]; then
        mkdir -m 0700 -p "$SCRATCH_DIR" || {
            printf 'text_store_ctl.sh: failed to create scratch directory: %s\n' "$SCRATCH_DIR" >&2
            return 1
        }
    fi
    if [[ -L "$SCRATCH_DIR" ]]; then
        printf 'text_store_ctl.sh: symlink race detected at scratch directory: %s\n' "$SCRATCH_DIR" >&2
        return 1
    fi
    local owner_uid
    owner_uid="$(stat -c '%u' "$SCRATCH_DIR" 2>/dev/null || echo '')"
    if [[ -n "$owner_uid" && "$owner_uid" != "$UID_VAL" ]]; then
        printf 'text_store_ctl.sh: scratch directory owner mismatch: expected %s, got %s\n' "$UID_VAL" "$owner_uid" >&2
        return 1
    fi
    chmod 700 "$SCRATCH_DIR" 2>/dev/null || true
}

cmd_paths() {
    cat <<EOF
{"bioPath":"$BIO_PATH","scratchPath":"$SCRATCH_PATH"}
EOF
}

cmd_prepare() {
    ensure_user_dir || return 1
    if [[ ! -f "$BIO_PATH" ]]; then
        touch "$BIO_PATH" || {
            printf 'text_store_ctl.sh: failed to touch bio file: %s\n' "$BIO_PATH" >&2
            return 1
        }
    fi
    chmod 600 "$BIO_PATH" 2>/dev/null || true

    ensure_scratch_dir || return 1
    if [[ ! -f "$SCRATCH_PATH" ]]; then
        touch "$SCRATCH_PATH" || {
            printf 'text_store_ctl.sh: failed to touch scratch file: %s\n' "$SCRATCH_PATH" >&2
            return 1
        }
    fi
    chmod 600 "$SCRATCH_PATH" 2>/dev/null || true

    cmd_paths
}

cmd_read_bio() {
    if [[ -f "$BIO_PATH" && -r "$BIO_PATH" ]]; then
        cat "$BIO_PATH"
    fi
}

cmd_read_scratch() {
    if [[ -f "$SCRATCH_PATH" && -r "$SCRATCH_PATH" ]]; then
        cat "$SCRATCH_PATH"
    fi
}

cmd_save_bio() {
    ensure_user_dir || return 1
    local payload="${HAKUSPACE_TEXT_PAYLOAD-}"

    local saved_umask
    saved_umask="$(umask)"
    umask 077

    local temp_file
    temp_file="$(mktemp "$USER_DIR/.bio_tmp.XXXXXX" 2>/dev/null)" || {
        umask "$saved_umask"
        printf 'text_store_ctl.sh: failed to create secure temp bio file\n' >&2
        return 1
    }

    if ! printf '%s' "$payload" > "$temp_file"; then
        rm -f "$temp_file" 2>/dev/null || true
        umask "$saved_umask"
        printf 'text_store_ctl.sh: failed to write temp bio file\n' >&2
        return 1
    fi
    chmod 600 "$temp_file" 2>/dev/null || true

    if ! mv -f "$temp_file" "$BIO_PATH"; then
        rm -f "$temp_file" 2>/dev/null || true
        umask "$saved_umask"
        printf 'text_store_ctl.sh: failed to atomically install bio file\n' >&2
        return 1
    fi
    chmod 600 "$BIO_PATH" 2>/dev/null || true
    umask "$saved_umask"
}

cmd_save_scratch() {
    ensure_scratch_dir || return 1
    local payload="${HAKUSPACE_TEXT_PAYLOAD-}"

    local saved_umask
    saved_umask="$(umask)"
    umask 077

    local temp_file
    temp_file="$(mktemp "$SCRATCH_DIR/.scratch_tmp.XXXXXX" 2>/dev/null)" || {
        umask "$saved_umask"
        printf 'text_store_ctl.sh: failed to create secure temp scratch file\n' >&2
        return 1
    }

    if ! printf '%s' "$payload" > "$temp_file"; then
        rm -f "$temp_file" 2>/dev/null || true
        umask "$saved_umask"
        printf 'text_store_ctl.sh: failed to write temp scratch file\n' >&2
        return 1
    fi
    chmod 600 "$temp_file" 2>/dev/null || true

    if ! mv -f "$temp_file" "$SCRATCH_PATH"; then
        rm -f "$temp_file" 2>/dev/null || true
        umask "$saved_umask"
        printf 'text_store_ctl.sh: failed to atomically install scratch file\n' >&2
        return 1
    fi
    chmod 600 "$SCRATCH_PATH" 2>/dev/null || true
    umask "$saved_umask"
}

usage() {
    printf 'Usage: text_store_ctl.sh <paths|prepare|read-bio|read-scratch|save-bio|save-scratch>\n' >&2
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
        paths)
            cmd_paths
            ;;
        prepare)
            cmd_prepare
            ;;
        read-bio)
            cmd_read_bio
            ;;
        read-scratch)
            cmd_read_scratch
            ;;
        save-bio)
            cmd_save_bio
            ;;
        save-scratch)
            cmd_save_scratch
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"

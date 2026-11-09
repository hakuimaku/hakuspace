#!/usr/bin/env bash

# Headless emoji controller.
# Owns emoji data access, clipboard operations, and HakuSpace cache history.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source_core_lib() {
    local name="$1" source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -f "$candidate" ]]; then
            # shellcheck source=/dev/null
            source "$candidate"
            return 0
        fi
    done
    printf 'emoji_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

source_core_lib haku_cache.sh ../../lib/haku_cache.sh || exit 1

usage() {
    cat <<'EOF_HELP'
Usage: emoji_ctl.sh <COMMAND> [ARGS]

Commands:
    list                        Print emoji database rows (TSV format)
    history                     Print recent emojis from cache (one per line, up to 16)
    record [EMOJI]              Record EMOJI into recent history cache
    copy [EMOJI]                Copy EMOJI into the Wayland clipboard and
                                record to history; reads from stdin when omitted
    -h, --help                  Show this help message
EOF_HELP
}

require_command() {
    local command_name=$1
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'emoji_ctl.sh: missing dependency: %s\n' "$command_name" >&2
        return 1
    fi
}

resolve_emoji_file() {
    if [[ -n "${HAKUSPACE_EMOJI_FILE:-}" && -f "$HAKUSPACE_EMOJI_FILE" ]]; then
        printf '%s\n' "$HAKUSPACE_EMOJI_FILE"
        return 0
    fi

    local candidate
    for candidate in \
        "/usr/share/rofi-emoji/all_emojis.txt" \
        "/usr/local/share/rofi-emoji/all_emojis.txt"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf 'emoji_ctl.sh: emoji database not found\n' >&2
    return 1
}

resolve_cache_dir() {
    if [[ -n "${HAKUSPACE_EMOJI_CACHE_DIR:-}" ]]; then
        printf '%s\n' "$HAKUSPACE_EMOJI_CACHE_DIR"
        return 0
    fi
    printf '%s/emoji\n' "$HAKUSPACE_CACHE_DIR"
}

resolve_history_file() {
    local cache_dir
    cache_dir="$(resolve_cache_dir)"
    printf '%s/history.txt\n' "$cache_dir"
}

list_emojis() {
    [[ $# -eq 0 ]] || {
        printf 'emoji_ctl.sh: list accepts no arguments.\n' >&2
        return 2
    }

    local db_file
    db_file="$(resolve_emoji_file)" || return 1
    cat "$db_file"
}

get_history() {
    [[ $# -eq 0 ]] || {
        printf 'emoji_ctl.sh: history accepts no arguments.\n' >&2
        return 2
    }

    local history_file
    history_file="$(resolve_history_file)"

    local -a items=()
    local -A seen=()

    if [[ -f "$history_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] || continue
            if [[ -z "${seen[$line]:-}" ]]; then
                seen["$line"]=1
                items+=("$line")
                if [[ ${#items[@]} -ge 16 ]]; then
                    break
                fi
            fi
        done < "$history_file"
    fi

    local item
    for item in "${items[@]}"; do
        printf '%s\n' "$item"
    done
}

record_history() {
    local glyph="${1:-}"
    if [[ -z "$glyph" ]]; then
        glyph="$(cat)"
    fi
    glyph="${glyph#"${glyph%%[![:space:]]*}"}"
    glyph="${glyph%"${glyph##*[![:space:]]}"}"
    [[ -n "$glyph" ]] || return 0

    local cache_dir history_file
    cache_dir="$(resolve_cache_dir)"
    mkdir -p "$cache_dir" 2>/dev/null || return 0
    history_file="$(resolve_history_file)"

    local -a new_items=("$glyph")
    local -A seen=()
    seen["$glyph"]=1

    if [[ -f "$history_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] || continue
            if [[ -z "${seen[$line]:-}" ]]; then
                seen["$line"]=1
                new_items+=("$line")
                if [[ ${#new_items[@]} -ge 16 ]]; then
                    break
                fi
            fi
        done < "$history_file"
    fi

    local temp_file
    temp_file="$(mktemp "${history_file}.XXXXXX" 2>/dev/null || mktemp)"
    local item
    for item in "${new_items[@]}"; do
        printf '%s\n' "$item"
    done > "$temp_file" && mv -f "$temp_file" "$history_file" 2>/dev/null || rm -f "$temp_file"
}

copy_emoji() {
    [[ $# -le 1 ]] || {
        printf 'emoji_ctl.sh: copy accepts at most one EMOJI argument.\n' >&2
        return 2
    }
    require_command wl-copy || return 1

    local payload=""
    if [[ $# -eq 1 ]]; then
        payload="$1"
    else
        payload="$(cat)"
    fi

    [[ -n "$payload" ]] || return 0

    printf '%s' "$payload" | wl-copy || return $?
    record_history "$payload"
    return 0
}

case "${1:-}" in
    list)
        shift
        list_emojis "$@"
        ;;
    history)
        shift
        get_history "$@"
        ;;
    record)
        shift
        record_history "$@"
        ;;
    copy)
        shift
        copy_emoji "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        printf 'emoji_ctl.sh: unknown command: %s\n' "${1:-}" >&2
        usage >&2
        exit 2
        ;;
esac

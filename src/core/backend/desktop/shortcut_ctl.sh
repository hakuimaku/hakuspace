#!/usr/bin/env bash

# Headless desktop-shortcut controller.
# Owns discovery and filesystem mutations only; no picker/frontend dependencies.

set -u

DESKTOP_DIR="${HAKUSPACE_SHORTCUT_DESKTOP_DIR:-$HOME/Desktop}"
DEFAULT_SEARCH_DIRS=(
    "/usr/share/applications"
    "$HOME/.local/share/applications"
    "/var/lib/snapd/desktop/applications"
    "/var/lib/flatpak/exports/share/applications"
)

if [[ -n ${HAKUSPACE_SHORTCUT_SEARCH_DIRS:-} ]]; then
    IFS=':' read -r -a SEARCH_DIRS <<< "$HAKUSPACE_SHORTCUT_SEARCH_DIRS"
else
    SEARCH_DIRS=("${DEFAULT_SEARCH_DIRS[@]}")
fi

usage() {
    cat <<'EOF_HELP'
Usage: shortcut_ctl.sh COMMAND [ARGS]

Commands:
    list [KEYWORD]                  List matching .desktop files as absolute paths
    add <KEYWORD|PATH>              Copy matching .desktop files to ~/Desktop
    create <APP_NAME> <EXEC> [ICON] Create a custom desktop shortcut

Environment (mainly for testing):
    HAKUSPACE_SHORTCUT_DESKTOP_DIR
    HAKUSPACE_SHORTCUT_SEARCH_DIRS  Colon-separated discovery directories
EOF_HELP
}

find_matches() {
    local keyword="${1:-}" pattern dir file
    if [[ $keyword == *.desktop ]]; then
        pattern="$keyword"
    else
        pattern="*${keyword}*.desktop"
    fi

    for dir in "${SEARCH_DIRS[@]}"; do
        [[ -d $dir ]] || continue
        while IFS= read -r file; do
            [[ -n $file ]] && printf '%s\n' "$file"
        done < <(find "$dir" -iname "$pattern" 2>/dev/null)
    done
}

trust_shortcut() {
    local path="$1"
    chmod +x "$path"
    if command -v gio >/dev/null 2>&1; then
        gio set "$path" metadata::trusted true 2>/dev/null || true
    fi
}

cmd_list() {
    [[ $# -le 1 ]] || { printf 'shortcut_ctl.sh: list accepts at most one keyword.\n' >&2; return 2; }
    find_matches "${1:-}"
}

cmd_add() {
    [[ $# -eq 1 ]] || { printf 'shortcut_ctl.sh: add requires exactly one target.\n' >&2; return 2; }
    local target="$1" pattern dir file real_file basename dest_file
    local -a found_files=()

    if [[ -f $target ]]; then
        found_files+=("$target")
    else
        if [[ $target == *.desktop ]]; then
            pattern="$target"
        else
            pattern="*${target}*.desktop"
        fi
        for dir in "${SEARCH_DIRS[@]}"; do
            [[ -d $dir ]] || continue
            while IFS= read -r file; do
                [[ -n $file ]] && found_files+=("$file")
            done < <(find "$dir" -iname "$pattern" 2>/dev/null)
        done
    fi

    if [[ ${#found_files[@]} -eq 0 ]]; then
        printf "No shortcuts found matching '%s'.\n" "$target" >&2
        return 1
    fi

    mkdir -p "$DESKTOP_DIR"
    printf 'Found %d matching shortcut(s). Copying to Desktop...\n' "${#found_files[@]}"

    for file in "${found_files[@]}"; do
        real_file=$(readlink -f "$file") || return 1
        basename=$(basename "$real_file")
        dest_file="$DESKTOP_DIR/$basename"

        if [[ -f $dest_file ]]; then
            printf 'Warning: %s already exists on Desktop. Overwriting...\n' "$basename"
        fi

        cp "$real_file" "$dest_file"
        trust_shortcut "$dest_file"
        printf 'Copied & trusted: %s\n' "$dest_file"
    done
}

cmd_create() {
    [[ $# -ge 2 && $# -le 3 ]] || {
        printf 'shortcut_ctl.sh: create requires APP_NAME EXEC_PATH [ICON_PATH].\n' >&2
        return 2
    }
    local app_name="$1" exec_path="$2" icon_path="${3:-utilities-terminal}"
    local shortcut_file="$DESKTOP_DIR/$app_name.desktop"

    mkdir -p "$DESKTOP_DIR"
    cat > "$shortcut_file" <<EOF_ENTRY
[Desktop Entry]
Version=1.0
Type=Application
Name=$app_name
Exec=$exec_path
Icon=$icon_path
Terminal=false
Categories=Utility;Application;
EOF_ENTRY

    trust_shortcut "$shortcut_file"
    printf 'Shortcut created successfully: %s\n' "$shortcut_file"
}

case "${1:-}" in
    list)
        shift
        cmd_list "$@"
        ;;
    add)
        shift
        cmd_add "$@"
        ;;
    create)
        shift
        cmd_create "$@"
        ;;
    -h|--help)
        usage
        ;;
    '')
        usage >&2
        exit 2
        ;;
    *)
        printf 'shortcut_ctl.sh: unknown command: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac

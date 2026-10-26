#!/usr/bin/env bash
# Own visual source lifecycles while upstream projects own builds and installation.
set -euo pipefail
HAKU_DIR="${HAKU_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HAKU_DIR/scripts/variables.sh"

# Shared defaults are read-only; legacy appearance.env is never executed.
source "$SOURCE_CORE/lib/haku_appearance.sh"
source "$SOURCE_CORE/lib/haku_state.sh"
export HAKU_CURSOR_THEME HAKU_CURSOR_SIZE
VISUAL_SOURCES_FILE="$(haku_state_path system.visual-sources.json)"
RECONCILE_PENDING="$(haku_state_path system.visual-reconcile.pending)"
LEGACY_ASSET_DIR="$HAKU_STATE_ROOT/assets"

# Report failures without exiting a batch before independent components are checked.
fail() { printf 'setup: %s\n' "$*" >&2; return 1; }

# Resolve all metadata together so every command uses the same source and origin.
resolve_component() {
    local component="$1" override saved=''
    case "$component" in
        cursor) SOURCE_PATH=''; SOURCE_URL="$HAKU_CURSOR_REPO_URL"; override="${HAKU_CURSOR_SOURCE:-}" ;;
        gtk) SOURCE_PATH=''; SOURCE_URL="$HAKU_GTK_REPO_URL"; override="${HAKU_GTK_THEME_SOURCE:-}" ;;
        symbols) SOURCE_PATH=''; SOURCE_URL="$HAKU_SYMBOLS_REPO_URL"; override="${HAKU_ICON_THEME_SOURCE:-}" ;;
        *) fail "Unknown component: $component"; return 1 ;;
    esac
    SOURCE_OVERRIDE=0
    if [[ -e "$VISUAL_SOURCES_FILE" || -L "$VISUAL_SOURCES_FILE" ]]; then
        [[ -f "$VISUAL_SOURCES_FILE" && ! -L "$VISUAL_SOURCES_FILE" && -O "$VISUAL_SOURCES_FILE" ]] || { fail 'Unsafe visual source state'; return 1; }
        saved="$(jq -er --arg key "$component" '
            if type == "object" and ((keys - ["cursor", "gtk", "symbols"]) | length == 0)
                and all(.[]; type == "string" and startswith("/") and (test("[\u0000\n\r]") | not))
            then .[$key] // "" else error("Invalid visual source state") end' "$VISUAL_SOURCES_FILE")" || return 1
    fi
    if [[ -n "$override" || -n "$saved" ]]; then SOURCE_PATH="${override:-$saved}"; SOURCE_OVERRIDE=1; fi
    if [[ -n "$SOURCE_PATH" ]]; then SOURCE_PATH="$(realpath -ms -- "$SOURCE_PATH")" || return 1; fi
}

# Persist only explicit source intent, never repository revisions or installed metadata.
remember_source() {
    local component="$1" temporary
    [[ "$SOURCE_OVERRIDE" == 1 ]] || return 0
    mkdir -p "$HAKU_STATE_DIR" || return 1
    temporary="$(mktemp "$VISUAL_SOURCES_FILE.XXXXXX")" || return 1
    if ! jq -n --arg key "$component" --arg path "$SOURCE_PATH" \
            --argjson previous "$(if [[ -f "$VISUAL_SOURCES_FILE" ]]; then cat "$VISUAL_SOURCES_FILE"; else echo '{}'; fi)" \
            '$previous + {($key): $path}' > "$temporary" || ! mv -f -- "$temporary" "$VISUAL_SOURCES_FILE"; then
        rm -f -- "$temporary"
        return 1
    fi
}

# Warn about old clones without adopting, deleting or moving their working trees.
warn_legacy_nested() {
    local component legacy
    for component in cursor gtk symbols; do
        resolve_component "$component" || return 1
        case "$component" in cursor) legacy=haku-cursor ;; gtk) legacy=hikade-gtk-theme ;; symbols) legacy=hikaide-symbols ;; esac
        legacy="$HAKU_DIR/ecosystem/$legacy"
        if [[ -e "$legacy" || -L "$legacy" ]]; then
            printf 'setup: warning: legacy nested repository detected: %s\nResolved source: %s\nOld working tree left untouched; move/backup development work manually.\n' "$legacy" "${SOURCE_PATH:-temporary installation source}" >&2
        fi
    done
}

# Verify each downloaded checkout belongs to the expected upstream.
validate_checkout() {
    local origin top
    if [[ -L "$SOURCE_PATH" || ! -d "$SOURCE_PATH/.git" || -L "$SOURCE_PATH/.git" ]]; then
        fail "Refusing to replace non-repository ecosystem path: $SOURCE_PATH"
        return 1
    fi
    top="$(git -C "$SOURCE_PATH" rev-parse --show-toplevel)" || return 1
    [[ "$top" == "$(cd "$SOURCE_PATH" && pwd -P)" ]] || { fail "Not an independent checkout: $SOURCE_PATH"; return 1; }
    origin="$(git -C "$SOURCE_PATH" config --get remote.origin.url)" || return 1
    [[ "${origin%.git}" == "${SOURCE_URL%.git}" ]] || { fail "Wrong origin for $SOURCE_PATH: actual=$origin expected=$SOURCE_URL"; return 1; }
    git -C "$SOURCE_PATH" rev-parse --verify HEAD >/dev/null
}

# Only installer-created staging is removed; development sources retain their lifetime.
cleanup_source_stage() {
    if [[ -n "${VISUAL_SOURCE_STAGE:-}" ]]; then rm -rf -- "$VISUAL_SOURCE_STAGE"; fi
}

# Allocate lazily so inspection and developer overrides create no temporary checkouts.
ensure_source_stage() {
    [[ -z "${VISUAL_SOURCE_STAGE:-}" ]] || return 0
    local base="${XDG_RUNTIME_DIR:-}"
    if [[ -z "$base" || ! -d "$base" || ! -w "$base" || ! -O "$base" ]]; then base="${TMPDIR:-/tmp}"; fi
    VISUAL_SOURCE_STAGE="$(mktemp -d "$base/hakuspace-visuals.XXXXXX")" || return 1
    trap cleanup_source_stage EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

# Fetch latest disposable sources; explicit or remembered local sources are used as-is.
prepare_component_source() {
    REPO_STATUS=error
    if [[ "$SOURCE_OVERRIDE" == 1 ]]; then
        [[ -d "$SOURCE_PATH" ]] || { fail "Source override does not exist: $SOURCE_PATH"; return 1; }
        REPO_STATUS=override
        return 0
    fi
    ensure_source_stage || return 1
    local name="${SOURCE_URL##*/}"
    SOURCE_PATH="$VISUAL_SOURCE_STAGE/${name%.git}"
    git clone --depth 1 -- "$SOURCE_URL" "$SOURCE_PATH" || return 1
    validate_checkout || return 1
    REPO_STATUS=cloned
}

# Derive Git metadata for status without persisting it.
source_metadata() {
    SOURCE_REV=unknown
    SOURCE_DIRTY=unknown
    local top changes
    if top="$(git -C "$SOURCE_PATH" rev-parse --show-toplevel 2>/dev/null)" &&
            [[ "$top" == "$(cd "$SOURCE_PATH" && pwd -P)" ]]; then
        SOURCE_REV="$(git -C "$SOURCE_PATH" rev-parse HEAD)" || return 1
        changes="$(git -C "$SOURCE_PATH" status --porcelain)" || return 1
        if [[ -z "$changes" ]]; then SOURCE_DIRTY=0; else SOURCE_DIRTY=1; fi
    fi
}

# Only the selected cursor variant is built and installed; its sibling stays intact.
resolve_cursor_theme() {
    local preset
    case "$HAKU_CURSOR_THEME" in
        Haku-Dark) CURSOR_BUILD_TARGET=dark; CURSOR_STYLE=dark ;;
        Haku-Light) CURSOR_BUILD_TARGET=light; CURSOR_STYLE=light ;;
        Haku-*)
            preset="${HAKU_CURSOR_THEME#Haku-}"
            CURSOR_STYLE=dark
            if [[ "$preset" == *-Light ]]; then preset="${preset%-Light}"; CURSOR_STYLE=light; fi
            [[ "$preset" =~ ^[A-Z][a-zA-Z0-9]*$ ]] || { fail "Invalid cursor theme: $HAKU_CURSOR_THEME"; return 1; }
            CURSOR_BUILD_TARGET="${preset,,}" ;;
        *) fail "Invalid cursor theme: $HAKU_CURSOR_THEME"; return 1 ;;
    esac
}

# Preserve the archive's exact-target guard and managed cursor ownership marker.
install_cursor() {
    resolve_cursor_theme || return 1
    local target="$HOME/.icons/$HAKU_CURSOR_THEME"
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" || ! -f "$target/.hakuspace-cursor" || -L "$target/.hakuspace-cursor" ]] ||
                [[ "$(cat "$target/.hakuspace-cursor")" != 'HakuSpace managed cursor v1' ]]; then
            fail "Refusing to overwrite an unmanaged cursor: $target"
            return 1
        fi
    fi
    (
        cd "$SOURCE_PATH" || exit 1
        make "$CURSOR_BUILD_TARGET" STYLE="$CURSOR_STYLE" && make verify || exit 1
        [[ -d "dist/$HAKU_CURSOR_THEME/cursors" && -f "dist/$HAKU_CURSOR_THEME/index.theme" ]] || {
            fail "Selected cursor was not built: $HAKU_CURSOR_THEME"; exit 1;
        }
        make install THEME="$HAKU_CURSOR_THEME"
    ) || return 1
    [[ -f "$target/index.theme" && -d "$target/cursors" ]] || { fail "Cursor installation missing: $target"; return 1; }
    printf 'HakuSpace managed cursor v1\n' > "$target/.hakuspace-cursor"
}

# Delegate pair validation and replacement to each upstream installer.
install_component() {
    case "$1" in
        cursor) install_cursor ;;
        gtk) python3 "$SOURCE_PATH/scripts/install_gtk_theme.py" --dest "$HOME/.themes" ;;
        symbols)
            local -a args=()
            if [[ -e "$HOME/.icons/Hikaide-Symbols" || -L "$HOME/.icons/Hikaide-Symbols" ||
                    -e "$HOME/.icons/Hikaide-Symbols-Light" || -L "$HOME/.icons/Hikaide-Symbols-Light" ]]; then args=(--replace); fi
            (cd "$SOURCE_PATH" && python3 scripts/build.py && python3 scripts/validate.py && ./scripts/install.sh "${args[@]}")
            ;;
    esac
}

# Verify installed component outputs directly from the filesystem.
verify_component() {
    local relative
    local -a paths=()
    case "$1" in
        cursor) paths=(".icons/$HAKU_CURSOR_THEME") ;;
        gtk) paths=(.themes/Hikaide .themes/Hikaide-Light) ;;
        symbols) paths=(.icons/Hikaide-Symbols .icons/Hikaide-Symbols-Light) ;;
    esac
    for relative in "${paths[@]}"; do
        [[ -f "$HOME/$relative/index.theme" ]] || { fail "${relative##*/} installation missing"; return 1; }
    done
}

# Pending activation is recovery state and survives a successful install followed by failure.
mark_reconcile_pending() {
    mkdir -p "$HAKU_STATE_DIR" || return 1
    [[ ! -L "$RECONCILE_PENDING" && ( ! -e "$RECONCILE_PENDING" || -f "$RECONCILE_PENDING" ) ]] || {
        fail 'Unsafe visual reconcile state'; return 1;
    }
    printf '1\n' > "$RECONCILE_PENDING"
}

# Retry activation using installed assets without downloading sources again.
retry_reconcile() {
    [[ -e "$RECONCILE_PENDING" || -L "$RECONCILE_PENDING" ]] || return 0
    [[ -f "$RECONCILE_PENDING" && ! -L "$RECONCILE_PENDING" ]] || { fail 'Unsafe visual reconcile state'; return 1; }
    reconcile_appearance && rm -f -- "$RECONCILE_PENDING"
}

# Reconcile once per batch through current source core, including in copy deployment mode.
reconcile_appearance() {
    "$SOURCE_CORE/backend/theme/appearance_ctl.sh" verify &&
        "$SOURCE_CORE/backend/theme/appearance_ctl.sh" apply &&
        "$SOURCE_CORE/backend/theme/theme_ctl.sh" apply
}

# Retain checksum-verified migration of the old archive-installed executables.
cleanup_legacy_icon_accent() {
    local receipt="$LEGACY_ASSET_DIR/icon-accent.sha256" name actual
    [[ -e "$receipt" || -L "$receipt" ]] || return 0
    if [[ -L "$receipt" || ! -f "$receipt" ]]; then
        printf 'assets: warning: unsafe legacy checksum receipt; files preserved\n' >&2
        return 0
    fi
    for name in icon-accent icon_accent.py; do
        if [[ -L "$HOME/.local/bin/$name" || ! -f "$HOME/.local/bin/$name" ]]; then
            printf 'assets: warning: legacy icon-accent missing or user-owned; files preserved\n' >&2
            return 0
        fi
    done
    actual="$(sha256sum "$HOME/.local/bin/icon-accent" "$HOME/.local/bin/icon_accent.py")" || {
        printf 'assets: warning: cannot verify both legacy files; files preserved\n' >&2
        return 0
    }
    # Compare the entire receipt, including both exact paths, not arbitrary entries.
    if [[ -n "$actual" ]] && cmp -s "$receipt" <(printf '%s\n' "$actual"); then
        rm -- "$HOME/.local/bin/icon-accent" "$HOME/.local/bin/icon_accent.py" "$receipt"
        printf 'assets: removed checksum-verified legacy icon-accent installation\n'
    else
        printf 'assets: warning: legacy icon-accent modified or user-owned; files preserved\n' >&2
    fi
}

# Continue independent components after failures, but never report a failed batch as success.
run_batch() (
    local command="$1" selection="${2:-all}" component detail failed=0 installed=0
    local -a components=(cursor gtk symbols)
    [[ "$selection" == all ]] || components=("$selection")
    VISUAL_SOURCE_STAGE=''
    if [[ "$command" == update && ( -e "$RECONCILE_PENDING" || -L "$RECONCILE_PENDING" ) ]]; then
        retry_reconcile
        return $?
    fi
    printf 'Visual ecosystem %s:\n' "$command"
    for component in "${components[@]}"; do
        resolve_component "$component" || return 2
        if [[ "$command" == update && "$SOURCE_OVERRIDE" == 1 ]]; then
            [[ -d "$SOURCE_PATH" ]] || { fail "Source override does not exist: $SOURCE_PATH"; failed=1; continue; }
            printf '  %-8s override, skipped; use ./scripts/setup.sh apply %s\n' "$component" "$component"
            continue
        fi
        if ! prepare_component_source; then
            printf '  %-8s source preparation failed\n' "$component" >&2
            failed=1
            continue
        fi
        detail="$REPO_STATUS"
        if install_component "$component" && mark_reconcile_pending && verify_component "$component" && remember_source "$component"; then
            installed=1
            printf '  %-8s %s + installed\n' "$component" "$detail"
        else
            printf '  %-8s %s, installation failed\n' "$component" "$detail" >&2
            failed=1
        fi
    done
    if [[ "$installed" == 1 ]]; then cleanup_legacy_icon_accent || failed=1; fi
    if [[ -e "$RECONCILE_PENDING" || -L "$RECONCILE_PENDING" ]]; then
        retry_reconcile || failed=1
    else
        "$SOURCE_CORE/backend/theme/appearance_ctl.sh" verify || failed=1
    fi
    return "$failed"
)

# Status derives repository and installed state without writing configuration.
workspace_status() {
    local component status revision installed dirty
    for component in cursor gtk symbols; do
        resolve_component "$component"
        status=temporary
        revision=unknown
        if [[ "$SOURCE_OVERRIDE" == 1 ]]; then
            if [[ -d "$SOURCE_PATH" ]]; then status=override; else status=error; fi
        fi
        dirty=unknown
        if [[ -d "$SOURCE_PATH" ]]; then
            source_metadata || return 1
            revision="$SOURCE_REV"
            dirty="$SOURCE_DIRTY"
        fi
        if verify_component "$component" 2>/dev/null; then installed=yes; else installed=no; fi
        printf '%s\t%s\t%s\t%s\tdirty=%s\tinstalled=%s\n' "$component" "$status" "${SOURCE_PATH:-not retained}" "$revision" "$dirty" "$installed"
    done
    if "$SOURCE_CORE/backend/theme/appearance_ctl.sh" verify >/dev/null 2>&1; then
        echo appearance_verified=yes
    else
        echo appearance_verified=no
    fi
}

# Build a multi-root workspace from verified absolute paths, preserving custom files.
generate_workspace() {
    local destination="$1" component top
    local -a folders=("$HAKU_DIR")
    top="$(git -C "$HAKU_DIR" rev-parse --show-toplevel)" || return 1
    [[ "$top" == "$(cd "$HAKU_DIR" && pwd -P)" ]] || { fail "Not a repository root: $HAKU_DIR"; return 1; }
    for component in cursor gtk symbols; do
        resolve_component "$component" || return 1
        [[ -n "$SOURCE_PATH" ]] || { fail "Configure HAKU_*_SOURCE development repositories before creating a workspace"; return 1; }
        top="$(git -C "$SOURCE_PATH" rev-parse --show-toplevel)" || return 1
        [[ "$top" == "$(cd "$SOURCE_PATH" && pwd -P)" ]] || { fail "Not a repository root: $SOURCE_PATH"; return 1; }
        folders+=("$SOURCE_PATH")
    done
    destination="$(realpath -ms -- "$destination")" || return 1
    python3 - "$destination" "${folders[@]}" <<'PYTHON'
import json
from pathlib import Path
import sys

# Required folders are compared by actual path; existing settings and extra roots survive.
path = Path(sys.argv[1])
required = [str(Path(folder).resolve(strict=True)) for folder in sys.argv[2:]]
try:
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError('workspace must be a regular file, not a symlink')
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open('x') as stream:
            json.dump({'folders': [{'path': folder} for folder in required]}, stream, indent=2)
            stream.write('\n')
    except FileExistsError:
        document = json.loads(path.read_text())
        folders = document.get('folders', [])
        present = {str((path.parent / entry['path']).resolve()) for entry in folders
                   if isinstance(entry, dict) and isinstance(entry.get('path'), str)}
        if not set(required).issubset(present):
            raise ValueError('existing workspace differs; add required folders manually or move it aside and rerun')
except (OSError, ValueError, TypeError, AttributeError) as error:
    sys.exit(f'setup: workspace preserved: {path}: {error}')
print(path)
PYTHON
    local result=$?
    [[ "$result" == 0 ]] || return "$result"
    printf 'Open with:\n  code %q\n' "$destination"
}

# Dispatch commands only when invoked directly; sourced callers reuse the functions.
main() {
    warn_legacy_nested || return 1
    case "${1:-}" in
        setup|update) [[ $# == 1 ]] || return 2; run_batch "$1" ;;
        apply) [[ $# == 2 ]] || return 2; run_batch apply "$2" ;;
        status) [[ $# == 1 ]] || return 2; workspace_status ;;
        path)
            [[ $# == 2 && "$2" != all ]] || return 2
            resolve_component "$2" || return 2
            [[ -n "$SOURCE_PATH" ]] || { fail "No persistent source configured for $2; set HAKU_*_SOURCE for development"; return 1; }
            printf '%s\n' "$SOURCE_PATH" ;;
        verify)
            [[ $# == 1 ]] || return 2
            retry_reconcile || return 1
            local component
            for component in cursor gtk symbols; do verify_component "$component" || return 1; done
            "$SOURCE_CORE/backend/theme/appearance_ctl.sh" verify ;;
        workspace) [[ $# -le 2 && "${2:-}" != --* ]] || return 2; generate_workspace "${2:-$HOME/HakuSpace.code-workspace}" ;;
        *) printf 'Usage: setup.sh {setup|update|status|verify|workspace [FILE]|apply cursor|gtk|symbols|all|path cursor|gtk|symbols}\n' >&2; return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

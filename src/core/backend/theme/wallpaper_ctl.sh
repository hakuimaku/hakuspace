#!/usr/bin/env bash

# Headless wallpaper controller.
# Owns discovery, explicit apply/stop actions, thumbnail cache, and accent sync.
# Presentation belongs in frontend/classic.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

WALL_DIR=${WALL_DIR:-$HOME/Pictures/Wallpapers}
WALL_MPV_DIR=${WALL_MPV_DIR:-$HOME/Videos/Wallpapers}
ACCENT_COLOR_BASED_ON_WALLPAPER=${ACCENT_COLOR_BASED_ON_WALLPAPER:-true}
ACCENT_COLOR_MODE=${ACCENT_COLOR_MODE:-vivid}
PREVIEW_DIR="$WALL_MPV_DIR/.thumbnails"
CURRENT_WALL_FILE=${HAKUSPACE_CURRENT_WALL_FILE:-$HOME/.cache/current_wallpaper}

resolve_script() {
    local name="$1" source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'wallpaper_ctl.sh: required script not found: %s\n' "$name" >&2
    return 1
}

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
    printf 'wallpaper_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

SET_WALLPAPER_SCRIPT="$(resolve_script wallpaper_set.sh ../../theme/wallpaper_set.sh)" || exit 1
GET_ACCENT_COLOR_SCRIPT="$(resolve_script get_accent_color.py ../../theme/get_accent_color.py)" || exit 1
GEN_STYLE_SCRIPT="$(resolve_script gen_style.sh ../../theme/gen_style.sh)" || exit 1
APPLY_STYLE_SCRIPT="$(resolve_script apply_style.sh ../../theme/apply_style.sh)" || exit 1
source_core_lib accent_color.sh ../../lib/accent_color.sh || exit 1

current_path() {
    [[ -f "$CURRENT_WALL_FILE" ]] || return 0
    head -n1 "$CURRENT_WALL_FILE"
}

current_kind() {
    local path="${1:-}"
    [[ -n "$path" ]] || return 0
    if [[ "$path" == "$WALL_MPV_DIR/"* ]]; then
        printf 'lively\n'
    elif [[ "$path" == "$WALL_DIR/"* ]]; then
        printf 'static\n'
    elif [[ -f "$path" ]]; then
        case "$(file -b --mime-type "$path" 2>/dev/null || true)" in
            video/*) printf 'lively\n' ;;
            image/*) printf 'static\n' ;;
        esac
    fi
}

preview_for_video() {
    local path="$1"
    local filename base
    filename="$(basename -- "$path")"
    base="${filename%.*}"
    if [[ -f "$PREVIEW_DIR/$base.gif" ]]; then
        printf '%s\n' "$PREVIEW_DIR/$base.gif"
    elif [[ -f "$PREVIEW_DIR/$base.jpg" ]]; then
        printf '%s\n' "$PREVIEW_DIR/$base.jpg"
    elif [[ -f "$PREVIEW_DIR/$base.png" ]]; then
        printf '%s\n' "$PREVIEW_DIR/$base.png"
    fi
}

generate_thumbnails() {
    local file filename
    mkdir -p "$PREVIEW_DIR"
    [[ -d "$WALL_MPV_DIR" ]] || return 0

    while IFS= read -r -d '' file; do
        filename="$(basename -- "${file%.*}")"
        if [[ -f "$PREVIEW_DIR/$filename.gif" || -f "$PREVIEW_DIR/$filename.jpg" || -f "$PREVIEW_DIR/$filename.png" ]]; then
            continue
        fi
        if command -v magick >/dev/null 2>&1; then
            magick "$file[0]" "$PREVIEW_DIR/$filename.jpg" 2>/dev/null || true
        elif command -v convert >/dev/null 2>&1; then
            convert "$file[0]" "$PREVIEW_DIR/$filename.jpg" 2>/dev/null || true
        fi
    done < <(find "$WALL_MPV_DIR" -maxdepth 1 \( -type f -o -type l \) -name '*.mp4' -print0 2>/dev/null)
}

apply_accent_color() {
    local target_image="$1"
    local accent

    [[ "$ACCENT_COLOR_BASED_ON_WALLPAPER" == true ]] || return 0

    if [[ ! -f "$target_image" ]]; then
        accent="#ffffff"
    else
        accent="$(python3 "$GET_ACCENT_COLOR_SCRIPT" "$target_image" "$ACCENT_COLOR_MODE")"
    fi
    accent="$(accent_color_or_fallback "$accent")"
    "$GEN_STYLE_SCRIPT" "$accent" && "$APPLY_STYLE_SCRIPT"
}

resolve_static() {
    local requested="${1:-}"
    [[ -n "$requested" ]] || return 2
    if [[ -f "$requested" ]]; then
        printf '%s\n' "$requested"
    elif [[ -f "$WALL_DIR/$requested" ]]; then
        printf '%s\n' "$WALL_DIR/$requested"
    else
        printf 'wallpaper_ctl.sh: static wallpaper not found: %s\n' "$requested" >&2
        return 2
    fi
}

resolve_lively() {
    local requested="${1:-}"
    [[ -n "$requested" ]] || return 2
    if [[ -f "$requested" ]]; then
        printf '%s\n' "$requested"
    elif [[ -f "$WALL_MPV_DIR/$requested" ]]; then
        printf '%s\n' "$WALL_MPV_DIR/$requested"
    else
        printf 'wallpaper_ctl.sh: lively wallpaper not found: %s\n' "$requested" >&2
        return 2
    fi
}

apply_static() {
    local wall
    wall="$(resolve_static "${1:-}")" || return $?
    "$SET_WALLPAPER_SCRIPT" "$wall" || return $?
    apply_accent_color "$wall"
}

apply_lively() {
    local wall preview
    wall="$(resolve_lively "${1:-}")" || return $?
    generate_thumbnails
    preview="$(preview_for_video "$wall")"
    "$SET_WALLPAPER_SCRIPT" "$wall" || return $?
    if [[ -n "$preview" ]]; then
        apply_accent_color "$preview"
    else
        apply_accent_color "not_found"
    fi
}

stop_lively() {
    local wall
    if ! pgrep -x mpvpaper >/dev/null 2>&1; then
        printf 'wallpaper_ctl.sh: lively wallpaper is not running.\n' >&2
        return 3
    fi

    pkill -x mpvpaper
    awww restore

    wall="$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1)"
    if [[ -n "$wall" && -f "$wall" ]]; then
        "$SET_WALLPAPER_SCRIPT" "$wall" || return $?
        apply_accent_color "$wall"
    fi
}

list_json() {
    local kind="$1"
    local dir current preview_dir
    current="$(current_path)"
    preview_dir="$PREVIEW_DIR"
    case "$kind" in
        static) dir="$WALL_DIR" ;;
        lively) dir="$WALL_MPV_DIR" ;;
        *) return 2 ;;
    esac

    python3 - "$kind" "$dir" "$preview_dir" "$current" <<'PY'
import json
import os
import sys

kind, directory, preview_dir, current = sys.argv[1:]
items = []
if os.path.isdir(directory):
    allowed = {".jpg", ".jpeg", ".png", ".gif", ".webp"} if kind == "static" else {".mp4"}
    for name in sorted(os.listdir(directory), key=str.casefold):
        path = os.path.join(directory, name)
        if not os.path.isfile(path) or os.path.splitext(name)[1].lower() not in allowed:
            continue
        thumb = path
        if kind == "lively":
            stem = os.path.splitext(name)[0]
            thumb = "video-x-generic"
            for ext in (".gif", ".jpg", ".png"):
                candidate = os.path.join(preview_dir, stem + ext)
                if os.path.isfile(candidate):
                    thumb = candidate
                    break
        items.append({
            "id": name,
            "kind": kind,
            "path": path,
            "label": name,
            "thumbnail": thumb,
            "selected": os.path.abspath(path) == os.path.abspath(current) if current else False,
        })
json.dump(items, sys.stdout, ensure_ascii=False, separators=(",", ":"))
sys.stdout.write("\n")
PY
}

list_plain() {
    local kind="$1" json
    json="$(list_json "$kind")" || return $?
    python3 -c 'import json,sys; [print(x["id"]) for x in json.load(sys.stdin)]' <<<"$json"
}

print_current() {
    local as_json="${1:-}"
    local path kind
    path="$(current_path)"
    kind="$(current_kind "$path")"
    if [[ "$as_json" == "--json" ]]; then
        python3 - "$path" "$kind" <<'PY'
import json, sys
path, kind = sys.argv[1:]
print(json.dumps({"path": path or None, "kind": kind or None}, ensure_ascii=False, separators=(",", ":")))
PY
    else
        printf '%s\n' "$path"
    fi
}

print_status() {
    local as_json="${1:-}"
    local path kind lively=false
    path="$(current_path)"
    kind="$(current_kind "$path")"
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        lively=true
    fi

    if [[ "$as_json" == "--json" ]]; then
        python3 - "$path" "$kind" "$lively" "$WALL_DIR" "$WALL_MPV_DIR" "$ACCENT_COLOR_BASED_ON_WALLPAPER" <<'PY'
import json, sys
path, kind, lively, static_dir, lively_dir, accent = sys.argv[1:]
print(json.dumps({
    "current": path or None,
    "kind": kind or None,
    "livelyRunning": lively == "true",
    "staticDir": static_dir,
    "livelyDir": lively_dir,
    "accentFromWallpaper": accent == "true",
}, ensure_ascii=False, separators=(",", ":")))
PY
    else
        printf 'current=%s\nkind=%s\nlivelyRunning=%s\n' "$path" "$kind" "$lively"
    fi
}

print_help() {
    cat <<'EOF_HELP'
Usage: wallpaper_ctl.sh COMMAND [ARG]
Headless wallpaper discovery and control API.

Commands:
    list-static [--json]        List static wallpaper ids or structured records
    list-lively [--json]        List video wallpaper ids or structured records
    apply-static ID_OR_PATH     Apply an explicit static wallpaper and accent
    apply-lively ID_OR_PATH     Apply an explicit video wallpaper and accent
    stop-lively                 Stop video wallpaper and restore the image layer
    current [--json]            Print current wallpaper state
    status [--json]             Print wallpaper subsystem state
    ensure-thumbnails           Generate missing video previews
    -h, --help                  Show this help message
EOF_HELP
}

case "${1:-}" in
    list-static)
        if [[ "${2:-}" == "--json" ]]; then list_json static; else list_plain static; fi
        ;;
    list-lively)
        generate_thumbnails
        if [[ "${2:-}" == "--json" ]]; then list_json lively; else list_plain lively; fi
        ;;
    apply-static)
        apply_static "${2:-}"
        ;;
    apply-lively)
        apply_lively "${2:-}"
        ;;
    stop-lively)
        stop_lively
        ;;
    current)
        print_current "${2:-}"
        ;;
    status)
        print_status "${2:-}"
        ;;
    ensure-thumbnails)
        generate_thumbnails
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac

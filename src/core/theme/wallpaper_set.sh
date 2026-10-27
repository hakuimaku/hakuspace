#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: wallpaper_set.sh WALLPAPER
Set the current wallpaper using the available wallpaper backend.

Arguments:
    WALLPAPER           Path to the wallpaper file
    -h, --help          Show this help message
EOF
        exit 0
fi

# Include AWWW_OPTS, GEN_WIDE_OPTS, and GEN_BOX_OPTS from setting.sh if it exists
[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

AWWW_OPTS=${AWWW_OPTS:-"--transition-type random --transition-step 90 --transition-fps 60"}

# Resolve shared paths in source and flattened installations.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
[[ -f "$LIB_DIR/haku_cache.sh" ]] || LIB_DIR="$SCRIPT_DIR/../lib"
source "$LIB_DIR/haku_cache.sh" || exit 1

WALLPAPER="${1:-}"
# Native commits reuse image application and cache generation without reentering IPC.
NATIVE_COMMIT=${HAKUSPACE_WALLPAPER_NATIVE_COMMIT:-0}
CACHE_DIR="$HAKUSPACE_CACHE_DIR/wallpaper"
# Resolve the wallpaper state controller alongside source or installed scripts.
WALLPAPER_CTL="$SCRIPT_DIR/wallpaper_ctl.py"
[[ -f "$WALLPAPER_CTL" ]] || WALLPAPER_CTL="$SCRIPT_DIR/../backend/theme/wallpaper_ctl.py"
mkdir -p "$CACHE_DIR"

GEN_WIDE_OPTS=${GEN_WIDE_OPTS:-"-resize 800x250^ -gravity Center -crop 800x250+0+0 +repage"}
GEN_BOX_OPTS=${GEN_BOX_OPTS:-"-resize 1653x852^ -gravity Center -extent 1653x852 -gravity NorthWest -crop 1212x852+500+0 +repage"}

# Start only missing image daemons and wait for their sockets before applying.
ensure_awww() {
    local attempt
    local -a daemon_options=()
    [[ -n "${1:-}" ]] && daemon_options=(-n "$1")
    awww query "${daemon_options[@]}" >/dev/null 2>&1 && return 0
    awww-daemon "${daemon_options[@]}" >/dev/null 2>&1 &
    for ((attempt = 0; attempt < 40; attempt++)); do
        awww query "${daemon_options[@]}" >/dev/null 2>&1 && return 0
        sleep 0.05
    done
    echo "Error: awww daemon did not become ready." >&2
    return 1
}

# Detect active monitor using wlr-randr
get_active_monitor() {
    local detected_monitor=""
    if command -v wlr-randr >/dev/null 2>&1; then
        detected_monitor=$(wlr-randr | awk '/^[^ ]/ {m=$1} /current/ {print m; exit}')
    else
        echo "Warning: wlr-randr not found. Defaulting to eDP-1." >&2
        notify-send "Warning: wlr-randr not found. Defaulting to eDP-1."
    fi

    # Fallback to eDP-1 if wlr-randr is missing or output is empty
    if [[ -z "$detected_monitor" ]]; then
        echo "eDP-1"
    else
        echo "$detected_monitor"
    fi
}

# Generate blurred backdrop image for Niri overview and imagebox
make_cache_img() {
    local is_successfull=1

    # Make Niri backdrop
    if [[ "${XDG_CURRENT_DESKTOP:-}" == "niri" ]] || pgrep -x "niri" >/dev/null 2>&1; then
        if { [[ "$NATIVE_COMMIT" != 1 ]] || ensure_awww awww-daemon-backdrop; } && \
            magick "${WALLPAPER}[0]" -background black -alpha remove -set option:filter:blur 1.0 -blur 0x15 "$CACHE_DIR/backdrop.jpg" 2>/dev/null; then
            awww img -n "awww-daemon-backdrop" --transition-type none "$CACHE_DIR/backdrop.jpg"
            echo "Niri backdrop image generated at $CACHE_DIR/backdrop.jpg"
        else
            is_successfull=0
        fi
    fi

    # Make wallpaper preview image for Rofi
    if magick "${WALLPAPER}[0]" $GEN_WIDE_OPTS "$CACHE_DIR/walpaper_wide_gen.jpg" 2>/dev/null && \
        magick "${WALLPAPER}[0]" $GEN_BOX_OPTS "$CACHE_DIR/walpaper_box_gen.jpg" 2>/dev/null; then
        echo "Wallpaper previews generated in $CACHE_DIR"
    else
        is_successfull=0
    fi

    if [[ $is_successfull -eq 0 ]]; then
        echo "Set Wallpaper" "Failed to generate cache images wallpaper via ImageMagick" >&2
        notify-send "Set Wallpaper" "Failed to generate cache images wallpaper via ImageMagick"
    fi
    python3 "$LIB_DIR/haku_cache.py" || return 1
    return 0
}

# Input Validation
if [[ -z "$WALLPAPER" ]]; then
    echo "Error: No wallpaper path provided." >&2
        cat <<'EOF' >&2
Usage: wallpaper_set.sh WALLPAPER
Set the current wallpaper using the available wallpaper backend.

Arguments:
    WALLPAPER           Path to the wallpaper file
    -h, --help          Show this help message
EOF
    exit 1
fi

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Error: File '$WALLPAPER' does not exist." >&2
    exit 1
fi

# Hikai coordinates image/video handoff before committing either renderer.
if [[ "$NATIVE_COMMIT" != 1 && $(cat "$HOME/.local/state/hakuspace/state/[shell].backend" 2>/dev/null) == hikai ]]; then
    native_result=$(qs -c hakuspace ipc call wallpaper select "$(realpath -- "$WALLPAPER")") || exit 1
    if [[ "$native_result" != true ]]; then
        echo "Wallpaper renderer is busy or unavailable; current wallpaper retained." >&2
        exit 1
    fi
    exit 0
fi

# Determine file nature via MIME type
MIME_TYPE=$(file -b --mime-type "$WALLPAPER")

case "$MIME_TYPE" in
    image/*)
        if [[ "$NATIVE_COMMIT" == 1 ]]; then
            ensure_awww || exit 1
        fi
        # Kill any active mpvpaper instance to avoid layer overlapping
        pkill mpvpaper 2>/dev/null || true

        # Set static/animated image background using awww
        if awww img "$WALLPAPER" $AWWW_OPTS; then
            if [[ "$NATIVE_COMMIT" != 1 ]]; then
                python3 "$WALLPAPER_CTL" remember "$WALLPAPER" >/dev/null || exit 1
            fi
            make_cache_img
        else
            echo "Error: Failed to set image wallpaper using awww." >&2
            exit 1
        fi
        ;;

    video/*)
        # Quickshell already prepared a video frame; retain the usual derived images.
        if [[ "$NATIVE_COMMIT" == 1 ]]; then
            make_cache_img
            exit 0
        fi
        # Terminate previous mpvpaper instance before launching a new one
        pkill mpvpaper 2>/dev/null || true
        
        # Make awww remove wallpaper (with solid black background)
        awww clear
        
        sleep 0.2

        MONITOR=$(get_active_monitor)
        echo "Setting video wallpaper on monitor: $MONITOR"

        # Launch mpvpaper in background for video playback on target monitor
        mpvpaper -v -s -o "no-audio loop" "$MONITOR" "$WALLPAPER" >/dev/null 2>&1 &
        MPV_PID=$!

        # Verify whether mpvpaper process started successfully
        sleep 0.3
        if kill -0 "$MPV_PID" 2>/dev/null; then
            if [[ "$NATIVE_COMMIT" != 1 ]]; then
                python3 "$WALLPAPER_CTL" remember "$WALLPAPER" >/dev/null || exit 1
            fi
            make_cache_img
        else
            echo "Error: mpvpaper failed to render video '$WALLPAPER' on monitor '$MONITOR'." >&2
            exit 1
        fi
        ;;

    *)
        echo "Error: Unsupported file format ($MIME_TYPE)." >&2
        exit 1
        ;;
esac

#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="$HOME/.local/state/haku_theme"
mkdir -p "$STATE_DIR"

# Defaults
DEFAULT_ACCENT="#ffffff"
DEFAULT_FONT="monospace"
DEFAULT_SIZE="16"

# Allow env overrides
ACCENT_COLOR="${ACCENT_COLOR:-$DEFAULT_ACCENT}"
FONT_FAMILY="${FONT_FAMILY:-$DEFAULT_FONT}"
FONT_SIZE="${FONT_SIZE:-$DEFAULT_SIZE}"

# Track whether font/size were provided by user
FONT_PROVIDED=false
SIZE_PROVIDED=false

# Positional args (simple debug)
#   $1 = accent, $2 = font, $3 = size
if [[ "${1-}" != "" && "${1-}" != --* ]]; then ACCENT_COLOR="$1"; shift; fi
if [[ "${1-}" != "" && "${1-}" != --* ]]; then FONT_FAMILY="$1"; FONT_PROVIDED=true; shift; fi
if [[ "${1-}" != "" && "${1-}" != --* ]]; then FONT_SIZE="$1"; SIZE_PROVIDED=true; shift; fi

# Flags (optional)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --accent|-a) ACCENT_COLOR="${2:?missing value for --accent}"; shift 2 ;;
    --font|-f)   FONT_FAMILY="${2:?missing value for --font}"; FONT_PROVIDED=true; shift 2 ;;
    --size|-s)   FONT_SIZE="${2:?missing value for --size}"; SIZE_PROVIDED=true; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------
# Keep existing font/size from state unless explicitly provided
# ---------------------------------------------------
if [[ "$FONT_PROVIDED" = false && -f "$STATE_DIR/fonts.css" ]]; then
  parsed_font="$(sed -nE 's/^\s*font-family:\s*"([^"]+)".*$/\1/p' "$STATE_DIR/fonts.css" | head -n1 || true)"
  [[ -n "$parsed_font" ]] && FONT_FAMILY="$parsed_font"
fi

if [[ "$SIZE_PROVIDED" = false && -f "$STATE_DIR/fonts.css" ]]; then
  parsed_size="$(sed -nE 's/^\s*font-size:\s*([0-9]+)px.*$/\1/p' "$STATE_DIR/fonts.css" | head -n1 || true)"
  [[ -n "$parsed_size" ]] && FONT_SIZE="$parsed_size"
fi

# --- sanitize accent ---
ACCENT_COLOR="$(printf '%s' "$ACCENT_COLOR" | tr -cd '#0-9a-fA-F')"
if ! [[ "$ACCENT_COLOR" =~ ^#[0-9a-fA-F]{6}$ ]]; then
  ACCENT_COLOR="$DEFAULT_ACCENT"
fi

# --- sanitize size ---
if ! [[ "$FONT_SIZE" =~ ^[0-9]+$ ]] || [[ "$FONT_SIZE" -le 0 ]]; then
  FONT_SIZE="$DEFAULT_SIZE"
fi

# --- convert accent to hyprland rgba(hex8) ---
hex_to_rgba() {
    local hex="${1:-}"
    hex="${hex#\#}"               # strip leading #
    hex="${hex//[^0-9a-fA-F]/}"   # keep only hex
    if [[ "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        printf 'rgba(%sff)' "${hex,,}"
        return 0
    elif [[ "$hex" =~ ^[0-9a-fA-F]{8}$ ]]; then
        printf 'rgba(%s)' "${hex,,}"
        return 0
    fi
    printf 'rgba(ffffffff)'
}
BORDER_RGBA="$(hex_to_rgba "$ACCENT_COLOR")"

# ===================================================
# ============== Generate theme files ===============
# ===================================================

# Colors (waybar, swaync)
cat > "$STATE_DIR/colors.css" <<EOF
/* Generated - do not edit */
@define-color accent_color ${ACCENT_COLOR};
EOF

# Fonts (waybar, swaync)
cat > "$STATE_DIR/fonts.css" <<EOF
/* Generated - do not edit */
* {
    font-family: "${FONT_FAMILY}";
    font-size: ${FONT_SIZE}px;
}
EOF

# Hyprland style (hyprlock)
cat > "$STATE_DIR/hyprland-style.conf" <<EOF
# Generated - do not edit
\$font_family = ${FONT_FAMILY}
\$font_size = ${FONT_SIZE}
EOF

cat > "$STATE_DIR/hyprland-style.lua" <<EOF
-- Generated - do not edit
return {
    font_family = "${FONT_FAMILY}",
    font_size = ${FONT_SIZE},
    border_color = "${BORDER_RGBA}",
}
EOF

# Rofi style
cat > "$STATE_DIR/rofi-style.rasi" <<EOF
/* Generated - do not edit */
* {
    accent: ${ACCENT_COLOR};
    font: "${FONT_FAMILY} ${FONT_SIZE}";
}
EOF

# Kitty style
cat > "$STATE_DIR/kitty-style.conf" <<EOF
# Generated - do not edit
font_family      family="${FONT_FAMILY}"
font_size        ${FONT_SIZE}
EOF


# Output summary
echo "Generated theme state in: $STATE_DIR"
echo "ACCENT_COLOR=$ACCENT_COLOR"
echo "FONT_FAMILY=$FONT_FAMILY"
echo "FONT_SIZE=$FONT_SIZE"

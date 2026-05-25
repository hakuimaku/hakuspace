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

# Positional args (simple debug)
#   $1 = accent, $2 = font, $3 = size
if [[ "${1-}" != "" && "${1-}" != --* ]]; then ACCENT_COLOR="$1"; shift; fi
if [[ "${1-}" != "" && "${1-}" != --* ]]; then FONT_FAMILY="$1"; shift; fi
if [[ "${1-}" != "" && "${1-}" != --* ]]; then FONT_SIZE="$1"; shift; fi

# Flags (optional)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --accent|-a) ACCENT_COLOR="${2:?missing value for --accent}"; shift 2 ;;
    --font|-f)   FONT_FAMILY="${2:?missing value for --font}"; shift 2 ;;
    --size|-s)   FONT_SIZE="${2:?missing value for --size}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --- sanitize accent ---
ACCENT_COLOR="$(printf '%s' "$ACCENT_COLOR" | tr -cd '#0-9a-fA-F')"
if ! [[ "$ACCENT_COLOR" =~ ^#[0-9a-fA-F]{6}$ ]]; then
  ACCENT_COLOR="$DEFAULT_ACCENT"
fi

# --- sanitize size ---
if ! [[ "$FONT_SIZE" =~ ^[0-9]+$ ]] || [[ "$FONT_SIZE" -le 0 ]]; then
  FONT_SIZE="$DEFAULT_SIZE"
fi

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
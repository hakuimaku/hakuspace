#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

GEN="$HOME/.local/bin/gen_style.sh"
APPLY="$HOME/.local/bin/apply_style.sh"
ROFI_THEME_BASE='mainbox { children: [ inputbar, content-area]; } window { width: 40%;'

prompt="Change Theme - Choose an option:"
choice="$(cat <<EOF | rofi -dmenu -p "$prompt" -theme-str "$ROFI_THEME_BASE height: 40%; }" -i
  Change Waybar Theme
  Change Rofi Theme
  Change font
  Change font size
  Change color
EOF
)"
[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
    *"Change Waybar Theme"*) spawn $HOME/.local/bin/waybar_manager.sh --select ;;
    *"Change Rofi Theme"*) spawn $HOME/.local/bin/rofi_theme_switcher.sh ;;
    *"Change font size"*)
        new_size="$(printf '%s\n' "$FONT_SIZE" | rofi -dmenu -p "  Current: ${FONT_SIZE}px" -theme-str "entry { placeholder: \"Type font size here\"; } $ROFI_THEME_BASE height: 30%; }" -i)"
        [[ -z "${new_size:-}" ]] && exit 0
        [[ "$new_size" =~ ^[0-9]+$ ]] || exit 0
        FONT_SIZE="$new_size"
        ;;

    *"Change font"*)
        fonts="$(fc-list : family 2>/dev/null | sed 's/,.*//' | sort -u || true)"
        [[ -z "$fonts" ]] && { echo "No fonts found via fc-list" >&2; exit 1; }
        new_font="$(printf '%s\n' "$fonts" | rofi -dmenu -p "  Current: ${FONT_FAMILY}" -theme-str "$ROFI_THEME_BASE height: 40%; }" -i)"
        [[ -z "${new_font:-}" ]] && exit 0
        FONT_FAMILY="$new_font"
        ;;

    *"Change color"*)
        accent_choice="$(cat <<'EOF' | rofi -dmenu -p "  Current: ${ACCENT_COLOR}" -theme-str "entry { placeholder: \"Type hex color here #xxxxxx\"; } $ROFI_THEME_BASE height: 50%; }" -i
Pick Color   [Press Enter]
Slate Blue   #7288AE
Green        #A2CB8B
Peach        #FFB399
Yellow       #EFBF04
Pink         #F9B2D7
White        #FFFFFF
Grey         #BFC9D1
EOF
        )"
        [[ -z "${accent_choice:-}" ]] && exit 0

        if [[ "$accent_choice" == "Pick Color   [Press Enter]" ]]; then
            "$HOME/.local/bin/accent_color_picker.sh"
            exit 0
        fi
        picked_hex="$(printf '%s\n' "$accent_choice" | grep -oE '#[0-9a-fA-F]{6}' | head -n1 || true)"
        [[ -n "$picked_hex" ]] && ACCENT_COLOR="$picked_hex"
        ;;
    *)
        exit 0
        ;;
esac

"$GEN" "$ACCENT_COLOR" "$FONT_FAMILY" "$FONT_SIZE"
"$APPLY"

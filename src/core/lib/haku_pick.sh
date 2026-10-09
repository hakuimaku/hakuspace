#!/usr/bin/env bash

# haku_pick.sh - Universal selector (dmenu replacement) for HakuSpace
# Reads items from stdin and outputs the selected item to stdout.
# Exits with 1 if canceled.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

PROMPT="Select"
PASSWORD=false
NO_CUSTOM=false
WIDTH=""
HEIGHT=""
SELECTED=""
LINES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt) PROMPT="$2"; shift 2 ;;
        --password) PASSWORD=true; shift ;;
        --no-custom) NO_CUSTOM=true; shift ;;
        --width) WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --selected) SELECTED="$2"; shift 2 ;;
        --lines) LINES="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Read items from stdin
readarray -t ITEMS

if haku_backend_is "classic"; then
    ROFI_ARGS=("-dmenu" "-i" "-p" "$PROMPT" "-theme" "option-menu.rasi")
    [[ "$PASSWORD" == "true" ]] && ROFI_ARGS+=("-password")
    [[ "$NO_CUSTOM" == "true" ]] && ROFI_ARGS+=("-no-custom")
    
    THEME_STR=""
    [[ -n "$WIDTH" ]] && THEME_STR+="window { width: $WIDTH; }"
    [[ -n "$HEIGHT" ]] && THEME_STR+="window { height: $HEIGHT; }"
    [[ -n "$THEME_STR" ]] && ROFI_ARGS+=("-theme-str" "$THEME_STR")
    
    [[ -n "$SELECTED" ]] && ROFI_ARGS+=("-selected-row" "$SELECTED")
    [[ -n "$LINES" ]] && ROFI_ARGS+=("-l" "$LINES")

    printf "%s\n" "${ITEMS[@]}" | rofi "${ROFI_ARGS[@]}"
    exit $?
else
    RUNTIME_DIR="$(haku_runtime_dir)"
    ID="$$"
    REQ_JSON="$RUNTIME_DIR/pick_req_$ID.json"
    FIFO="$RUNTIME_DIR/pick_fifo_$ID"
    
    cleanup() {
        rm -f "$REQ_JSON" "$FIFO"
    }
    trap cleanup EXIT

    jq -n \
       --arg prompt "$PROMPT" \
       --argjson password "$PASSWORD" \
       --argjson noCustom "$NO_CUSTOM" \
       --arg width "$WIDTH" \
       --arg height "$HEIGHT" \
       --arg selected "$SELECTED" \
       --arg lines "$LINES" \
       '$ARGS.positional | {prompt: $prompt, password: $password, noCustom: $noCustom, width: $width, height: $height, selected: $selected, lines: $lines, items: .}' \
       --args "${ITEMS[@]}" > "$REQ_JSON"

    mkfifo "$FIFO"
    
    if ! timeout 3 qs -c hakuspace ipc call picker open "$FIFO" "$(cat "$REQ_JSON")" 2> >(tee -a "$RUNTIME_DIR/qs.log" >&2); then
        echo "Error: Failed to open IPC picker" >&2
        exit 1
    fi

    exec 3<> "$FIFO"
    
    
    # Wait for response
    while true; do
        if IFS= read -r -t 1 -u 3 result; then
            if [[ "$result" == "__CANCEL__" ]]; then
                exit 1
            fi
            echo "$result"
            exit 0
        fi
        
        
        if ! haku_qs_alive; then
            exit 1
        fi
    done
fi

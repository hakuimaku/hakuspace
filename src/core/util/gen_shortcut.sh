#!/usr/bin/env bash

# This script generates a desktop shortcut, scans to copy existing ones,
# or queries available applications in the system.

DESKTOP_DIR="$HOME/Desktop"
SEARCH_DIRS=(
    "/usr/share/applications"
    "$HOME/.local/share/applications"
    "/var/lib/snapd/desktop/applications"
    "/var/lib/flatpak/exports/share/applications"
)

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "Shortcut Generator Script"
    echo "Generate if matching shortcuts exist in system directories."
    echo "Usage $0 [options]"
    echo ""
    echo "Options:"
    echo "   <AppName> <ExecPath> [IconPath]   Create a custom shortcut"
    echo "   -a|--add <KeywordOrPath>          Find and copy matching shortcuts to Desktop"
    echo "   -m|--menu                         Select and add a shortcut using rofi menu"
    echo "   -q|--query [Keyword]              List available system shortcuts (optional filter)"
    exit 0
fi

mkdir -p "$DESKTOP_DIR"

# Menu logic (-m or --menu)
if [[ $1 == "-m" || $1 == "--menu" ]]; then
    if ! command -v rofi &> /dev/null; then
        echo "Error: rofi is not installed."
        exit 1
    fi

    ALL_FILES=()
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r file; do
                ALL_FILES+=("$file")
            done < <(find "$dir" -iname "*.desktop" 2>/dev/null)
        fi
    done
    
    if [ ${#ALL_FILES[@]} -eq 0 ]; then
        echo "No shortcuts found."
        exit 1
    fi

    SELECTED=$(printf "%s\n" "${ALL_FILES[@]}" | rofi -dmenu -i -p "Add Shortcut" -theme-str 'window {width: 70%;}')
    
    if [ -n "$SELECTED" ]; then
        bash "$0" -a "$SELECTED"
    else
        echo "Cancelled."
    fi
    exit 0
fi

# Query logic (-q or --query)
if [[ $1 == "-q" || $1 == "--query" ]]; then
    KEYWORD="$2"
    FOUND_COUNT=0
    
    if [[ "$KEYWORD" == *.desktop ]]; then
        FIND_PATTERN="$KEYWORD"
    else
        FIND_PATTERN="*${KEYWORD}*.desktop"
    fi
    
    echo "Searching for '$FIND_PATTERN' in system directories..."
    echo "---------------------------------------------------"
    
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r file; do
                if [ -n "$file" ]; then
                    echo "$file"
                    ((FOUND_COUNT++))
                fi
            done < <(find "$dir" -iname "$FIND_PATTERN" 2>/dev/null)
        fi
    done
    
    echo "---------------------------------------------------"
    echo "Total matching applications found: $FOUND_COUNT"
    exit 0
fi

# Add/Scan logic (-a, -add, or --add)
if [[ $1 == "-a" || $1 == "-add" || $1 == "--add" ]]; then
    TARGET="$2"
    if [ -z "$TARGET" ]; then
        echo "Error: Missing target for adding."
        echo "Usage: $0 -a <KeywordOrPath>"
        exit 1
    fi
    
    FOUND_FILES=()
    
    if [ -f "$TARGET" ]; then
        FOUND_FILES+=("$TARGET")
    else
        if [[ "$TARGET" == *.desktop ]]; then
            FIND_PATTERN="$TARGET"
        else
            FIND_PATTERN="*${TARGET}*.desktop"
        fi
        
        for dir in "${SEARCH_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                while IFS= read -r file; do
                    FOUND_FILES+=("$file")
                done < <(find "$dir" -iname "$FIND_PATTERN" 2>/dev/null)
            fi
        done
    fi
    
    if [ ${#FOUND_FILES[@]} -eq 0 ]; then
        echo "No shortcuts found matching '${TARGET}'."
        exit 1
    fi
    
    echo "Found ${#FOUND_FILES[@]} matching shortcut(s). Copying to Desktop..."
    
    for file in "${FOUND_FILES[@]}"; do
        REAL_FILE=$(readlink -f "$file")
        BASENAME=$(basename "$REAL_FILE")
        DEST_FILE="$DESKTOP_DIR/$BASENAME"
        
        if [ -f "$DEST_FILE" ]; then
            echo "Warning: $BASENAME already exists on Desktop. Overwriting..."
        fi
        
        cp "$REAL_FILE" "$DEST_FILE"
        chmod +x "$DEST_FILE"
        gio set "$DEST_FILE" metadata::trusted true 2>/dev/null
        
        echo "Copied & trusted: $DEST_FILE"
    done
    
    exit 0
fi

# Original generation logic
APP_NAME="$1"
EXEC_PATH="$2"
ICON_PATH="$3"

if [ -z "$APP_NAME" ] || [ -z "$EXEC_PATH" ]; then
    echo "Error: Missing arguments."
    echo "Usage: -h|--help for more options."
    exit 1
fi

SHORTCUT_FILE="$DESKTOP_DIR/$APP_NAME.desktop"

cat <<EOF > "$SHORTCUT_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Exec=$EXEC_PATH
Icon=${ICON_PATH:-utilities-terminal}
Terminal=false
Categories=Utility;Application;
EOF

chmod +x "$SHORTCUT_FILE"
gio set "$SHORTCUT_FILE" metadata::trusted true 2>/dev/null

echo "Shortcut created successfully: $SHORTCUT_FILE"
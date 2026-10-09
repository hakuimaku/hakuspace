#!/bin/bash
set -e

echo "Running pre-commit checks..."

# 1. No debug code
if grep -rnE "INJECTED|Perf Test|ancestor|console\.log" src/ | grep -v "Theme.qml" | grep -v "dbg("; then
    echo "ERROR: Debug code found."
    exit 1
fi

# 2. No untracked files in src or scripts
UNTRACKED=$(git ls-files --others --exclude-standard src scripts)
if [ -n "$UNTRACKED" ]; then
    echo "ERROR: Untracked files found in src/ or scripts/:"
    echo "$UNTRACKED"
    exit 1
fi

# 3. No junk files at root
JUNK=$(find . -maxdepth 1 \( -name "*.patch" -o -name "*.log" -o -name "test_*.qml" -o -name "TT3_*" \) )
if [ -n "$JUNK" ]; then
    echo "ERROR: Junk files found at root:"
    echo "$JUNK"
    exit 1
fi

# 4. QML syntax check (if script exists)
if [ -f scripts/qml_syntax_check.py ]; then
    python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
fi

# 5. FlareGeometry JS tests
if [ -f scripts/test_flare_geometry.js ]; then
    node scripts/test_flare_geometry.js
fi

# 6. Shell syntax check for repository tooling
while IFS= read -r -d '' script; do
    bash -n "$script"
done < <(find scripts -type f -name "*.sh" -print0)

# 7. Core-script boundary guardrails
# src/core is deployed flat into ~/.local/bin, so source-tree organization must
# never create duplicate basenames.  Backend/domain code must also remain
# callable without a picker/frontend once src/core/backend exists.
echo "Checking src/core script boundaries..."

CORE_DIR="src/core"
if [[ ! -d "$CORE_DIR" ]]; then
    echo "ERROR: Core script directory not found: $CORE_DIR"
    exit 1
fi

# Shell syntax for every deployable core shell script.
while IFS= read -r -d '' script; do
    bash -n "$script"
done < <(find "$CORE_DIR" -type f -name '*.sh' -print0)

# Python syntax without leaving __pycache__ artifacts in the source tree.
mapfile -d '' CORE_PYTHON_SCRIPTS < <(find "$CORE_DIR" -type f -name '*.py' -print0)
if (( ${#CORE_PYTHON_SCRIPTS[@]} > 0 )); then
    PYCACHE_DIR="$(mktemp -d)"
    if ! PYTHONPYCACHEPREFIX="$PYCACHE_DIR" python3 -m py_compile "${CORE_PYTHON_SCRIPTS[@]}"; then
        rm -rf "$PYCACHE_DIR"
        echo "ERROR: Python syntax check failed in src/core."
        exit 1
    fi
    rm -rf "$PYCACHE_DIR"
fi

# Mirror deploy_hakuspace_scripts(): every file is flattened by basename into
# ~/.local/bin, except README.md. Any duplicate would make deployment ambiguous.
declare -A CORE_BASENAMES=()
while IFS= read -r -d '' file; do
    filename="$(basename "$file")"
    [[ "$filename" == "README.md" ]] && continue

    if [[ -n "${CORE_BASENAMES[$filename]:-}" ]]; then
        echo "ERROR: src/core basename collision for '$filename':"
        echo "  ${CORE_BASENAMES[$filename]}"
        echo "  $file"
        exit 1
    fi
    CORE_BASENAMES[$filename]="$file"
done < <(find "$CORE_DIR" -type f -print0)

# C1 guard for future backend/domain extraction. Skip until the directory
# exists; after C2+ it becomes a hard invariant.
if [[ -d "$CORE_DIR/backend" ]]; then
    if grep -RInE --include='*.sh' --include='*.py' \
        '\brofi\b|haku_pick\.sh|picker open' "$CORE_DIR/backend"; then
        echo "ERROR: UI/picker dependency found in src/core/backend."
        exit 1
    fi
fi

echo "Core-script boundary checks passed."

echo "All checks passed!"
exit 0

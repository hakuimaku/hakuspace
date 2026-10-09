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

# 6. Shell syntax check
for script in $(find scripts -name "*.sh"); do
    bash -n "$script"
done

echo "All checks passed!"
exit 0

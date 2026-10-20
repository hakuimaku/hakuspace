#!/bin/bash
set -e
export PYTHONDONTWRITEBYTECODE=1

echo "Running pre-commit checks..."

# 1. No debug code
if grep -rnE "INJECTED|Perf Test|console\.log" src/ | grep -v "Theme.qml" | grep -v "dbg("; then
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
if [ -f scripts/test_config_tree_model.js ]; then
    node scripts/test_config_tree_model.js
fi
if [ -f scripts/test_plain_text_edit_ops.js ]; then
    node scripts/test_plain_text_edit_ops.js
fi
node scripts/test_safe_zone_geometry.js
node scripts/test_screen_geometry.js
node scripts/test_dock_app_model.js
node scripts/test_dock_geometry.js
node scripts/test_hakumenu_geometry.js
if command -v quickshell >/dev/null 2>&1; then
    bash scripts/test_safe_zone_controller.sh
    bash scripts/test_labwc_exit.sh
    bash scripts/test_hikai_shell.sh
    bash scripts/test_hikai_resource_refresh.sh
    if command -v labwc >/dev/null 2>&1; then
        bash scripts/test_hikai_dock.sh
        HAKUSPACE_CHROME_TEST=1 bash scripts/test_hikai_dock.sh
        HAKUSPACE_DOCK_INPUT=1 bash scripts/test_hikai_dock.sh
        HAKUSPACE_DOCK_REORDER=1 bash scripts/test_hikai_dock.sh
        bash scripts/test_hikai_hakumenu.sh
    fi
fi

python3 -m unittest discover -s tests/icon_accent -v
python3 scripts/test_visual_ecosystem.py
python3 scripts/test_setting_ctl.py
python3 scripts/test_hikai_settings_ctl.py
python3 scripts/test_hikai_chrome_state.py
python3 scripts/test_hikai_chrome_ctl.py
python3 scripts/test_hakucfg_hikai.py
python3 scripts/test_taskbar_pins_ctl.py
python3 scripts/test_dock_app_ctl.py
python3 scripts/test_dock_icon_watch.py
python3 scripts/test_hakucfg_editor_ctl.py
python3 scripts/test_hakuspace_info_ctl.py
python3 scripts/test_shortcut_metadata.py
python3 scripts/test_quick_actions_ctl.py

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

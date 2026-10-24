#!/bin/bash
set -e

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../.." && pwd)"
cd -- "$REPO_ROOT"
export PYTHONDONTWRITEBYTECODE=1

echo "Running final repository checks..."

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

# Validate test layout and the runtime state naming contract.
python3 tests/support/test_layout.py
python3 tools/checks/state_schema.py
python3 tests/config/state/test_naming.py

# Static and component checks run without long profiling workloads.
mapfile -d '' QML_FILES < <(find src/home/.config/quickshell tests tools -name '*.qml' -print0)
python3 tools/checks/qml_syntax.py "${QML_FILES[@]}"
python3 tests/hikai/memory/test_image_budget.py
node tests/geometry/flare/test_geometry.js
node tests/config/hakucfg/test_tree_model.js
node tests/editor/test_edit_ops.js
node tests/geometry/safe_zone/test_geometry.js
node tests/geometry/screen/test_geometry.js
node tests/hikai/hakumenu/test_geometry.js
node tests/hikai/lock/test_geometry.js
node tests/hikai/window_navigator/test_model.js

# Component runners own their test commands and only enable private runtimes on request.
if command -v quickshell >/dev/null 2>&1 && command -v labwc >/dev/null 2>&1 \
    && command -v dbus-run-session >/dev/null 2>&1 && command -v wlr-randr >/dev/null 2>&1 \
    && command -v grim >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
    bash tests/hikai/dock/run.sh --runtime
    bash tests/hikai/settings/run.sh --runtime
    bash tests/hikai/wallpaper/run.sh --runtime
    bash tests/shell/transition/run.sh --headless
    HAKUSPACE_CHROME_TEST=1 bash tests/hikai/dock/test_runtime.sh
    bash tests/hikai/hakumenu/test_runtime.sh
else
    echo "SKIP: private compositor suites require quickshell, labwc, D-Bus, wlr-randr, grim and ffmpeg."
    bash tests/hikai/dock/run.sh
    bash tests/hikai/settings/run.sh
    bash tests/hikai/wallpaper/run.sh
    if command -v quickshell >/dev/null 2>&1; then
        bash tests/shell/transition/run.sh
    else
        echo "SKIP: offscreen shell transition requires quickshell."
    fi
fi
if command -v quickshell >/dev/null 2>&1; then
    python3 tests/hikai/memory/test_lifecycle.py
    bash tests/geometry/safe_zone/test_controller.sh
    bash tests/shell/labwc/test_exit.sh
    bash tests/hikai/shell/test_runtime.sh
    bash tests/hikai/resource_refresh/test_runtime.sh
else
    echo "SKIP: QML lifecycle and offscreen suites require quickshell."
fi

python3 -m unittest discover -s tests/icon_accent -v
python3 tests/desktop/visual_ecosystem/test_ecosystem.py
python3 tests/config/settings/test_ctl.py
python3 tests/hikai/chrome/test_state.py
python3 tests/hikai/chrome/test_ctl.py
python3 -m unittest discover -s tests/tempnote -p test_temp_note_shortcut.py -v
python3 tests/config/hakucfg/test_sync.py
python3 tests/desktop/taskbar/test_pins_ctl.py
python3 tests/config/hakucfg/test_editor_ctl.py
python3 tests/system/info/test_ctl.py
python3 tests/desktop/shortcuts/test_metadata.py
python3 tests/hikai/quick_actions/test_ctl.py
python3 tests/shell/backend_transition/test_transition.py
python3 tests/hikai/cava/test_cava.py
python3 tests/desktop/icons/test_style.py

# 6. Shell syntax check for repository tooling
while IFS= read -r -d '' script; do
    bash -n "$script"
done < <(find scripts tests tools -type f -name "*.sh" -print0)

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

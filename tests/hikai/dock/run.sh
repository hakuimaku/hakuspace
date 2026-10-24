#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Locate this component and its repository assets from any working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Keep compositor work opt-in for component development.
case "${1:-}" in
    ''|--runtime) ;;
    *) echo "Usage: $0 [--runtime]" >&2; exit 2 ;;
esac
node "$TEST_DIR/test_app_model.js"
node "$TEST_DIR/test_geometry.js"
python3 "$TEST_DIR/test_app_ctl.py"
python3 "$TEST_DIR/test_icon_watch.py"
if [[ ${1:-} == --runtime ]]; then
    bash "$TEST_DIR/test_runtime.sh" --headless
    HAKUSPACE_DOCK_INPUT=1 bash "$TEST_DIR/test_runtime.sh" --headless
    HAKUSPACE_DOCK_REORDER=1 bash "$TEST_DIR/test_runtime.sh" --headless
fi

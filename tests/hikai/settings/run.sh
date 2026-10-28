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
python3 "$TEST_DIR/test_ctl.py"
python3 "$TEST_DIR/test_avatar.py"
python3 "$TEST_DIR/test_transactions.py"
node "$TEST_DIR/test_reveal_geometry.js"
node "$TEST_DIR/test_navigation.js"
node "$TEST_DIR/test_ux.js"
node "$TEST_DIR/../config/test_contract.js"
if [[ ${1:-} == --runtime ]]; then
    bash "$TEST_DIR/test_light.sh"
    INK_SETTINGS_ONLY=1 bash "$TEST_DIR/test_ink.sh"
    bash "$TEST_DIR/test_theme_action_menu.sh"
fi

#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Locate Task Manager tests independently of the caller's working directory.
TASK_TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TASK_REPO_ROOT="$(cd -- "$TASK_TEST_DIR/../../.." && pwd)"
cd -- "$TASK_REPO_ROOT"

# Keep private compositor and Quickshell sessions opt-in, like other components.
if (( $# > 1 )); then
    echo "Usage: $0 [--runtime]" >&2
    exit 2
fi
case "${1:-}" in
    ''|--runtime) ;;
    *) echo "Usage: $0 [--runtime]" >&2; exit 2 ;;
esac
python3 "$TASK_TEST_DIR/test_controller.py"
python3 "$TASK_TEST_DIR/test_monitor.py"
python3 "$TASK_TEST_DIR/test_shortcut.py"
node "$TASK_TEST_DIR/test_logic.js"
if [[ ${1:-} == --runtime ]]; then
    python3 "$TASK_TEST_DIR/test_pins.py"
    python3 "$TASK_TEST_DIR/test_service.py"
    python3 "$TASK_TEST_DIR/test_qml.py"
fi

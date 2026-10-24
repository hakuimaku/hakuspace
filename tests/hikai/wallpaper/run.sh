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
python3 "$TEST_DIR/test_settings.py"
if [[ ${1:-} == --runtime ]]; then
    bash "$TEST_DIR/test_runtime.sh"
    bash "$TEST_DIR/test_runtime.sh" --surface
fi

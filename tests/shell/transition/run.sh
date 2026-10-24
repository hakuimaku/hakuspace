#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Locate this component and its repository assets from any working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# The existing harness supports offscreen checks and an optional private compositor.
case "${1:-}" in
    ''|--headless) ;;
    *) echo "Usage: $0 [--headless]" >&2; exit 2 ;;
esac
exec bash "$TEST_DIR/test_runtime.sh" "$@"

#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Reuse the Dock runner's private compositor, HOME, launch fixtures and state.
export HAKUSPACE_HAKUMENU_TEST=1
exec bash tests/hikai/dock/test_runtime.sh "${1:---headless}"

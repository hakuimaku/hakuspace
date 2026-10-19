#!/usr/bin/env bash
set -euo pipefail

# Reuse the Dock runner's private compositor, HOME, launch fixtures and state.
export HAKUSPACE_HAKUMENU_TEST=1
exec bash scripts/test_hikai_dock.sh "${1:---headless}"

#!/usr/bin/env bash
# HakuSpace Root Wrapper for packages.sh
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
exec "$HAKU_DIR/scripts/packages.sh" "$@"

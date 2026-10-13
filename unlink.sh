#!/usr/bin/env bash
# HakuSpace Root Wrapper for unlink.sh
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
exec "$HAKU_DIR/scripts/unlink.sh" "$@"

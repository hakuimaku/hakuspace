#!/usr/bin/env bash
# HakuSpace Root Wrapper for link.sh
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
exec "$HAKU_DIR/scripts/link.sh" "$@"

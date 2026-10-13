#!/usr/bin/env bash
# HakuSpace Root Wrapper for doctor.sh
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
exec "$HAKU_DIR/scripts/doctor.sh" "$@"

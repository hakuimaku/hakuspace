#!/usr/bin/env bash
# Share the update run's backup location with the destination-only migration.
set -euo pipefail
HAKU_DIR="${HAKU_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HAKU_DIR/scripts/runtime.sh"
exec python3 -B "$HAKU_DIR/scripts/migrate.py" "$@"

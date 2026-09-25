#!/usr/bin/env bash
# Entry point: delegates to scripts/bootstrap.sh
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
exec "$SCRIPT_DIR/scripts/bootstrap.sh" "$@"

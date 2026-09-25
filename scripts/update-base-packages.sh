#!/usr/bin/env bash
# Idempotently updates apt package lists and upgrades installed packages.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

apt_update_once

log_info "Upgrading installed packages (apt-get upgrade)..."
if ! sudo apt-get upgrade -y; then
    require_sudo_hint "apt-get upgrade"
    exit 1
fi

log_ok "Base packages up to date."

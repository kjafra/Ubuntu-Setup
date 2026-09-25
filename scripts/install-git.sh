#!/usr/bin/env bash
# Idempotently installs git.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists git; then
    log_info "git already installed ($(git --version)), skipping."
    exit 0
fi

apt_update_once

log_info "Installing git..."
if ! sudo apt-get install -y git; then
    require_sudo_hint "apt-get install git"
    exit 1
fi

log_ok "git installed: $(git --version)"

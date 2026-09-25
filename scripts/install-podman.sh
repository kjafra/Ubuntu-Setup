#!/usr/bin/env bash
# Idempotently installs Podman.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists podman; then
    log_info "Podman already installed ($(podman --version)), skipping."
    exit 0
fi

apt_update_once

log_info "Installing podman..."
if ! sudo apt-get install -y podman; then
    require_sudo_hint "apt-get install podman"
    exit 1
fi

log_ok "Podman installed: $(podman --version)"

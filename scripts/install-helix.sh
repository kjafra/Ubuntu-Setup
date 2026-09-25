#!/usr/bin/env bash
# Idempotently installs the Helix editor (hx). Prefers apt (available on
# newer Ubuntu releases via universe); falls back to snap.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists hx; then
    log_info "Helix already installed ($(hx --version)), skipping."
    exit 0
fi

apt_update_once

log_info "Attempting to install helix via apt..."
if sudo apt-get install -y helix 2>/dev/null && command_exists hx; then
    log_ok "Helix installed via apt: $(hx --version)"
    exit 0
fi

log_warn "helix is not available via apt on this release; falling back to snap."
if command_exists snap; then
    if sudo snap install helix --classic; then
        log_ok "Helix installed via snap."
        exit 0
    fi
fi

log_err "Could not install helix via apt or snap. Install manually: https://docs.helix-editor.com/install.html"
exit 1

#!/usr/bin/env bash
# Idempotently installs slirp4netns via apt. It provides the user-mode
# networking that sandboxes (e.g. Bubblewrap-based, as used by Copilot CLI)
# and rootless containers need for a private network namespace. It relies
# on the setuid/user-namespace plumbing of the OS, so it stays on apt rather
# than Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists slirp4netns; then
    log_info "slirp4netns already installed, skipping."
    exit 0
fi

log_info "Installing slirp4netns via apt..."
apt_update_once
if ! sudo apt-get install -y slirp4netns; then
    require_sudo_hint "apt-get install slirp4netns"
    exit 1
fi
log_ok "Installed slirp4netns."

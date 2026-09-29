#!/usr/bin/env bash
# Idempotently installs Podman via Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

# Rootless Podman needs newuidmap/newgidmap to map subordinate UID/GID
# ranges into containers. These are setuid-root binaries that must come
# from the OS's own package manager (Homebrew intentionally can't ship
# setuid binaries), so this one piece stays on apt even though podman
# itself installs via brew.
if ! command_exists newuidmap; then
    log_info "Installing uidmap via apt (needed for rootless Podman)..."
    apt_update_once
    if ! sudo apt-get install -y uidmap; then
        require_sudo_hint "apt-get install uidmap"
        exit 1
    fi
fi

if command_exists podman; then
    log_info "Podman already installed ($(podman --version)), skipping."
    exit 0
fi

log_info "Installing podman via Homebrew..."
if ! brew install podman; then
    log_err "brew install podman failed."
    exit 1
fi

log_ok "Podman installed: $(podman --version)"

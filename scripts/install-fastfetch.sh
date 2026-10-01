#!/usr/bin/env bash
# Idempotently installs fastfetch via Homebrew. This script only installs
# the binary; it's invoked on every login shell (distro logo + machine
# info banner) by the dotfiles-provided .zshrc, not by this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists fastfetch; then
    log_info "fastfetch already installed ($(fastfetch --version | head -n1)), skipping install."
    exit 0
fi

log_info "Installing fastfetch via Homebrew..."
if ! brew install fastfetch; then
    log_err "brew install fastfetch failed."
    exit 1
fi

log_ok "fastfetch installed: $(fastfetch --version | head -n1)"

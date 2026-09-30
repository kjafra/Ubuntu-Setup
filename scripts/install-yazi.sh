#!/usr/bin/env bash
# Idempotently installs the Yazi terminal file manager via Homebrew.
#
# This script only installs the binary; the `y` cd-on-quit shell wrapper
# function and any further config come from the dotfiles-provided
# .zshrc, not this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists yazi; then
    log_info "yazi already installed ($(yazi --version)), skipping install."
    exit 0
fi

log_info "Installing yazi via Homebrew..."
if ! brew install yazi; then
    log_err "brew install yazi failed."
    exit 1
fi

log_ok "yazi installed: $(yazi --version)"

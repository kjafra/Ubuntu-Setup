#!/usr/bin/env bash
# Idempotently installs eza (a modern `ls` replacement) via Homebrew.
#
# This script only installs the binary; the ls/ll/la/lt aliases come from
# the dotfiles-provided .zshrc, not this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists eza; then
    log_info "eza already installed ($(eza --version | head -n1)), skipping install."
    exit 0
fi

log_info "Installing eza via Homebrew..."
if ! brew install eza; then
    log_err "brew install eza failed."
    exit 1
fi

log_ok "eza installed: $(eza --version | head -n1)"

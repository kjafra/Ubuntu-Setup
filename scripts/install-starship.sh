#!/usr/bin/env bash
# Idempotently installs starship (cross-shell prompt) via Homebrew.
#
# This script only installs the binary; the prompt config and init line come from
# the dotfiles-provided .zshrc, not this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists starship; then
    log_info "starship already installed ($(starship --version | head -n1)), skipping install."
    exit 0
fi

log_info "Installing starship via Homebrew..."
if ! brew install starship; then
    log_err "brew install starship failed."
    exit 1
fi

log_ok "starship installed: $(starship --version | head -n1)"

#!/usr/bin/env bash
# Idempotently installs lazygit via Homebrew.
#
# This script only installs the binary. lazygit's editor preference (Helix)
# is configured via ~/.config/lazygit/config.yml, which is deployed by the
# dotfiles bare-repo checkout (see install-dotfiles.sh), not by this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists lazygit; then
    log_info "lazygit already installed ($(lazygit --version | head -n1)), skipping install."
    exit 0
fi

log_info "Installing lazygit via Homebrew..."
if ! brew install lazygit; then
    log_err "brew install lazygit failed."
    exit 1
fi

log_ok "lazygit installed: $(lazygit --version | head -n1)"

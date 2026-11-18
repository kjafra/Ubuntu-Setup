#!/usr/bin/env bash
# Idempotently installs fd (fast file finder) via Homebrew.
#
# The dotfiles-provided .zshrc uses fd as fzf's file source, so Ctrl+T
# (fuzzy file picker) and Alt+C (fuzzy cd) respect .gitignore.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists fd; then
    log_info "fd already installed ($(fd --version)), skipping install."
    exit 0
fi

log_info "Installing fd via Homebrew..."
if ! brew install fd; then
    log_err "brew install fd failed."
    exit 1
fi

log_ok "fd installed: $(fd --version)"

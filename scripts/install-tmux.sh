#!/usr/bin/env bash
# Idempotently installs tmux via Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists tmux; then
    log_info "tmux already installed ($(tmux -V)), skipping."
    exit 0
fi

log_info "Installing tmux via Homebrew..."
if ! brew install tmux; then
    log_err "brew install tmux failed."
    exit 1
fi

log_ok "tmux installed: $(tmux -V)"

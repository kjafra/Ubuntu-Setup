#!/usr/bin/env bash
# Idempotently installs Zellij via Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists zellij; then
    log_info "Zellij already installed ($(zellij --version)), skipping."
    exit 0
fi

log_info "Installing zellij via Homebrew..."
if ! brew install zellij; then
    log_err "brew install zellij failed."
    exit 1
fi

log_ok "Zellij installed: $(zellij --version)"

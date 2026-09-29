#!/usr/bin/env bash
# Idempotently installs the Helix editor (hx) via Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists hx; then
    log_info "Helix already installed ($(hx --version)), skipping."
    exit 0
fi

log_info "Installing helix via Homebrew..."
if ! brew install helix; then
    log_err "brew install helix failed."
    exit 1
fi

log_ok "Helix installed: $(hx --version)"

#!/usr/bin/env bash
# Idempotently installs OpenSpec (https://openspec.dev/), the spec-driven
# development CLI for AI coding assistants, via Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists openspec; then
    log_info "openspec already installed ($(openspec --version 2>&1 | head -n1)), skipping."
    exit 0
fi

log_info "Installing openspec via Homebrew..."
if ! brew install openspec; then
    log_err "brew install openspec failed."
    exit 1
fi

log_ok "openspec installed: $(openspec --version 2>&1 | head -n1)"

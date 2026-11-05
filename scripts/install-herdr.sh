#!/usr/bin/env bash
# Idempotently installs herdr (https://herdr.dev/tui/), the terminal agent
# multiplexer, via Homebrew, and installs its GitHub Copilot CLI integration
# (`herdr integration install copilot`): a SessionStart hook in
# ~/.copilot/settings.json that lets herdr resume Copilot sessions after a
# server restart.
#
# herdr requires the Copilot config dir to already exist, so it is created
# here. Run after install-copilot-cli.sh. Re-running refreshes the hook.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists herdr; then
    log_info "herdr already installed ($(herdr --version 2>&1 | head -n1)), skipping install."
else
    log_info "Installing herdr via Homebrew..."
    if ! brew install herdr; then
        log_err "brew install herdr failed."
        exit 1
    fi
    log_ok "herdr installed: $(herdr --version 2>&1 | head -n1)"
fi

if ! command_exists copilot; then
    log_warn "copilot not found, skipping herdr Copilot CLI integration (run install-copilot-cli.sh, then re-run this script)."
    exit 0
fi

mkdir -p "${COPILOT_HOME:-$HOME/.copilot}"
log_info "Installing herdr Copilot CLI integration..."
if herdr integration install copilot; then
    log_ok "herdr Copilot CLI integration installed."
else
    log_warn "herdr integration install copilot failed; run it manually."
fi

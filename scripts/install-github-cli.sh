#!/usr/bin/env bash
# Idempotently installs the GitHub CLI (gh) via Homebrew, and the GitHub
# Copilot CLI extension (gh copilot) if the installed gh version needs it.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists gh; then
    log_info "GitHub CLI already installed ($(gh --version | head -n1)), skipping install."
else
    log_info "Installing GitHub CLI (gh) via Homebrew..."
    if ! brew install gh; then
        log_err "brew install gh failed."
        exit 1
    fi
    log_ok "GitHub CLI installed: $(gh --version | head -n1)"
fi

log_info "Checking GitHub Copilot CLI support..."
if gh copilot --help >/dev/null 2>&1; then
    # Recent gh versions (2.101+) bundle `copilot` as a built-in command
    # that lazily downloads the standalone Copilot CLI on first real use.
    # No separate extension is needed (and 'gh extension install
    # github/gh-copilot' now fails with "matches a built-in command").
    log_info "GitHub Copilot CLI available via the built-in 'gh copilot' command, skipping extension install."
elif gh extension list 2>/dev/null | grep -qi "gh-copilot"; then
    log_info "gh copilot extension already installed, skipping."
else
    log_info "Installing gh copilot extension (older gh version without built-in support)..."
    if ! gh extension install github/gh-copilot; then
        log_warn "Failed to install the gh copilot extension. You may need to run 'gh auth login' first, then re-run this script."
        exit 1
    fi
    log_ok "gh copilot extension installed."
fi

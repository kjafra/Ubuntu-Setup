#!/usr/bin/env bash
# Idempotently installs the GitHub CLI (gh) and the GitHub Copilot CLI
# extension (gh copilot).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists gh; then
    log_info "GitHub CLI already installed ($(gh --version | head -n1)), skipping install."
else
    log_info "Installing GitHub CLI (gh)..."

    if ! command_exists curl; then
        apt_update_once
        sudo apt-get install -y curl
    fi

    sudo mkdir -p -m 755 /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    fi

    if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    fi

    if ! sudo apt-get update -y; then
        require_sudo_hint "apt-get update (github-cli repo)"
        exit 1
    fi

    if ! sudo apt-get install -y gh; then
        require_sudo_hint "apt-get install gh"
        exit 1
    fi

    log_ok "GitHub CLI installed: $(gh --version | head -n1)"
fi

log_info "Checking gh copilot extension..."
if gh extension list 2>/dev/null | grep -qi "gh-copilot"; then
    log_info "gh copilot extension already installed, skipping."
else
    log_info "Installing gh copilot extension..."
    if ! gh extension install github/gh-copilot; then
        log_warn "Failed to install the gh copilot extension. You may need to run 'gh auth login' first, then re-run this script."
        exit 1
    fi
    log_ok "gh copilot extension installed."
fi

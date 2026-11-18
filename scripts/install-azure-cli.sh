#!/usr/bin/env bash
# Idempotently installs the Azure CLI (az) via Homebrew. This script only
# installs the binary - it deliberately does NOT run `az login` itself
# (that's an interactive, credentialed step left to the user; the
# dotfiles-provided .zshrc already nags about it on login if `az` is
# installed but not authenticated). Once logged in, the Azure DevOps MCP
# server (see install-azure-devops-mcp.sh) reuses this same `az login`
# session via `--authentication azcli` - no separate token/PAT needed.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists az; then
    log_info "Azure CLI already installed ($(az version --output tsv --query '\"azure-cli\"' 2>/dev/null || echo 'version unknown')), skipping."
    exit 0
fi

log_info "Installing Azure CLI via Homebrew..."
if ! brew install azure-cli; then
    log_err "brew install azure-cli failed."
    exit 1
fi

log_ok "Azure CLI installed."
log_info "Before using Azure DevOps tools, authenticate with: az login"

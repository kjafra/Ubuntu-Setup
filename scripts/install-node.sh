#!/usr/bin/env bash
# Idempotently installs Node.js (and its bundled npx) via Homebrew. Needed
# so Copilot CLI's MCP servers that run as `npx ...` (e.g. the Azure
# DevOps MCP server, see install-azure-devops-mcp.sh) can be launched
# on demand, without having to pre-install each server globally.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists node; then
    log_info "Node.js already installed ($(node --version)), skipping."
    exit 0
fi

log_info "Installing Node.js via Homebrew..."
if ! brew install node; then
    log_err "brew install node failed."
    exit 1
fi

log_ok "Node.js installed: $(node --version) (npx $(npx --version 2>/dev/null))"

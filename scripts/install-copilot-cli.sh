#!/usr/bin/env bash
# Idempotently installs the standalone GitHub Copilot CLI (`copilot`,
# npm package @github/copilot / github.com/github/copilot-cli) - the
# full agentic CLI that supports MCP servers (`/mcp`, `copilot mcp add`,
# etc.), unlike the older `gh copilot` built-in (install-github-cli.sh).
#
# There's no Homebrew cask for this on Linux (the official `copilot-cli`
# cask is macOS-only), so this uses GitHub's own official install script.
# It defaults to $HOME/.local/bin for a non-root user, which is already
# added to PATH by the dotfiles-provided .zshrc.
#
# Requires `gh` to be authenticated (or the /login flow on first launch)
# before first use - not run automatically by this script. MCP servers
# (e.g. Azure DevOps, see install-azure-devops-mcp.sh) are registered
# separately, after this script, since they need the `copilot` binary to
# already exist.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

COPILOT_CLI_BIN="$HOME/.local/bin/copilot"
COPILOT_CLI_INSTALL_URL="https://gh.io/copilot-install"

if command_exists copilot || [[ -x "$COPILOT_CLI_BIN" ]]; then
    log_info "GitHub Copilot CLI already installed ($("$COPILOT_CLI_BIN" --version 2>/dev/null || copilot --version 2>/dev/null || echo 'version unknown')), skipping install."
    exit 0
fi

log_info "Installing GitHub Copilot CLI from ${COPILOT_CLI_INSTALL_URL}..."
# shellcheck disable=SC1090
if ! curl -fsSL "$COPILOT_CLI_INSTALL_URL" | bash; then
    log_err "GitHub Copilot CLI install failed."
    exit 1
fi

log_ok "GitHub Copilot CLI installed."
log_info "Open a new shell and run: copilot"
log_info "On first launch, use /login if you're not already authenticated."

#!/usr/bin/env bash
# Idempotently installs the standalone GitHub Copilot CLI (`copilot`,
# npm package @github/copilot / github.com/github/copilot-cli) - the
# full agentic CLI that supports MCP servers (`/mcp`, `copilot mcp add`,
# etc.), unlike the older `gh copilot` built-in (install-github-cli.sh).
#
# Installed via the Homebrew `copilot-cli` formula so `brew upgrade` keeps it
# current. A previous curl-installed copy in ~/.local/bin is removed so it
# can't shadow the brew one.
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

ensure_brew_on_path

COPILOT_CLI_BIN="$HOME/.local/bin/copilot"

if [[ -e "$COPILOT_CLI_BIN" ]]; then
    log_info "Removing legacy curl-installed copilot at $COPILOT_CLI_BIN..."
    rm -rf "$COPILOT_CLI_BIN"
fi

if brew list copilot-cli >/dev/null 2>&1; then
    log_info "GitHub Copilot CLI already installed via Homebrew, skipping install."
    exit 0
fi

log_info "Installing GitHub Copilot CLI via Homebrew..."
if ! brew install copilot-cli; then
    log_err "brew install copilot-cli failed."
    exit 1
fi

log_ok "GitHub Copilot CLI installed."
log_info "Open a new shell and run: copilot"
log_info "On first launch, use /login if you're not already authenticated."

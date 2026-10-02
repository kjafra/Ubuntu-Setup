#!/usr/bin/env bash
# Idempotently registers Microsoft's official Azure DevOps MCP server
# (github.com/microsoft/azure-devops-mcp, npm package @azure-devops/mcp)
# with the standalone GitHub Copilot CLI (install-copilot-cli.sh), so
# Copilot can query/manage Azure DevOps projects, work items, repos,
# pipelines, wikis, etc. from the command line.
#
# Authentication: the server is registered with `--authentication azcli`,
# so it reuses the host's existing `az login` session (via
# install-azure-cli.sh) to talk to Azure DevOps - no PAT or other secret
# is ever generated or stored on disk by this script.
#
# The server needs your Azure DevOps organization name, which is
# personal/machine-specific and therefore NOT tracked in the dotfiles
# repo. Copy dotfiles/.azure-devops.local.example to
# $HOME/.azure-devops.local (first non-comment, non-blank line = org
# name) before running this script. If that file doesn't exist yet, this
# script logs instructions and exits 0 (skipped, not failed), so
# bootstrap.sh/install.sh still completes cleanly on a fresh machine.
#
# Requires `copilot` (install-copilot-cli.sh) and `node`/`npx`
# (install-node.sh) to already be installed.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

MCP_SERVER_NAME="azure-devops"
MCP_CONFIG_FILE="$HOME/.copilot/mcp-config.json"
ADO_ORG_FILE="$HOME/.azure-devops.local"

if ! command_exists copilot && [[ ! -x "$HOME/.local/bin/copilot" ]]; then
    log_warn "GitHub Copilot CLI ('copilot') not found. Run install-copilot-cli.sh first, then re-run this script."
    exit 0
fi
# Make sure `copilot` is callable even if PATH wasn't refreshed in this shell.
if ! command_exists copilot && [[ -x "$HOME/.local/bin/copilot" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if ! command_exists npx; then
    log_warn "npx (Node.js) not found. Run install-node.sh first, then re-run this script."
    exit 0
fi

if [[ -f "$MCP_CONFIG_FILE" ]] && grep -q "\"${MCP_SERVER_NAME}\"" "$MCP_CONFIG_FILE"; then
    log_info "Azure DevOps MCP server already registered in ${MCP_CONFIG_FILE}, skipping."
    exit 0
fi

if [[ ! -f "$ADO_ORG_FILE" ]]; then
    log_warn "Azure DevOps organization not configured."
    log_warn "Copy dotfiles/.azure-devops.local.example to ${ADO_ORG_FILE} and fill in your org name, then re-run this script."
    exit 0
fi

ADO_ORG="$(grep -v -E '^\s*(#|$)' "$ADO_ORG_FILE" | head -n1 | tr -d '[:space:]')"
if [[ -z "$ADO_ORG" ]]; then
    log_warn "${ADO_ORG_FILE} exists but has no organization name set. Fill it in, then re-run this script."
    exit 0
fi

log_info "Registering Azure DevOps MCP server for organization '${ADO_ORG}'..."
if ! copilot mcp add "$MCP_SERVER_NAME" -- npx -y @azure-devops/mcp "$ADO_ORG" --authentication azcli; then
    log_err "Failed to register the Azure DevOps MCP server."
    exit 1
fi

log_ok "Azure DevOps MCP server registered (org: ${ADO_ORG}, auth: az login via azcli)."
log_info "Make sure you've run 'az login' before using Azure DevOps tools in Copilot CLI."

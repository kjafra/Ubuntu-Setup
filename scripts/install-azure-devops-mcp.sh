#!/usr/bin/env bash
# Idempotently registers Microsoft's official Azure DevOps MCP server
# (github.com/microsoft/azure-devops-mcp, npm package @azure-devops/mcp)
# with the standalone GitHub Copilot CLI (install-copilot-cli.sh), so
# Copilot can query/manage Azure DevOps projects, work items, repos,
# pipelines, wikis, etc. from the command line.
#
# Authentication: each server is registered with `--authentication
# azcli`, so it reuses the host's existing `az login` session (via
# install-azure-cli.sh) to talk to Azure DevOps - no PAT or other secret
# is ever generated or stored on disk by this script.
#
# Multi-org support: list one or more Azure DevOps organization names
# per line in $HOME/.azure-devops.local, which is personal/
# machine-specific and therefore NOT tracked in the dotfiles repo. Every
# org listed gets its own MCP server (named "azure-devops-<org>"),
# registered simultaneously - no switching required, all orgs' tools are
# available to Copilot at once. Copy
# dotfiles/.azure-devops.local.example to $HOME/.azure-devops.local and
# fill in your org name(s) before running this script. If that file
# doesn't exist yet, or has no real org names set, this script logs
# instructions and exits 0 (skipped, not failed), so
# bootstrap.sh/install.sh still completes cleanly on a fresh machine.
#
# Requires `copilot` (install-copilot-cli.sh) and `node`/`npx`
# (install-node.sh) to already be installed.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

MCP_CONFIG_FILE="$HOME/.copilot/mcp-config.json"
ADO_ORG_FILE="$HOME/.azure-devops.local"
# Placeholders shipped in .azure-devops.local.example over time - ignored
# if left unedited, so a stale example copy doesn't get registered as a
# real org.
ADO_ORG_PLACEHOLDERS=("your-ado-org-name" "your-first-ado-org-name" "your-second-ado-org-name" "your-third-ado-org-name")

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

if [[ ! -f "$ADO_ORG_FILE" ]]; then
    log_warn "Azure DevOps organization(s) not configured."
    log_warn "Copy dotfiles/.azure-devops.local.example to ${ADO_ORG_FILE} and fill in your org name(s), then re-run this script."
    exit 0
fi

is_placeholder() {
    local candidate="$1"
    local placeholder
    for placeholder in "${ADO_ORG_PLACEHOLDERS[@]}"; do
        [[ "$candidate" == "$placeholder" ]] && return 0
    done
    return 1
}

# Collect every non-comment, non-blank, non-placeholder line, deduplicated.
declare -A seen_orgs=()
ADO_ORGS=()
while IFS= read -r line; do
    org="$(tr -d '[:space:]' <<<"$line")"
    [[ -z "$org" ]] && continue
    is_placeholder "$org" && continue
    [[ -n "${seen_orgs[$org]:-}" ]] && continue
    seen_orgs["$org"]=1
    ADO_ORGS+=("$org")
done < <(grep -v -E '^\s*(#|$)' "$ADO_ORG_FILE")

if [[ "${#ADO_ORGS[@]}" -eq 0 ]]; then
    log_warn "${ADO_ORG_FILE} exists but has no real organization name(s) set. Fill it in, then re-run this script."
    exit 0
fi

any_failed=0
for ADO_ORG in "${ADO_ORGS[@]}"; do
    # MCP server names should stay simple identifiers even if an org name
    # contains characters outside [a-zA-Z0-9-_].
    SERVER_NAME="azure-devops-$(printf '%s' "$ADO_ORG" | tr -c 'a-zA-Z0-9_-' '-')"

    if [[ -f "$MCP_CONFIG_FILE" ]] && grep -q "\"${SERVER_NAME}\"" "$MCP_CONFIG_FILE"; then
        log_info "Azure DevOps MCP server for '${ADO_ORG}' already registered as '${SERVER_NAME}', skipping."
        continue
    fi

    log_info "Registering Azure DevOps MCP server for organization '${ADO_ORG}' as '${SERVER_NAME}'..."
    if ! copilot mcp add "$SERVER_NAME" -- npx -y @azure-devops/mcp "$ADO_ORG" --authentication azcli; then
        log_err "Failed to register the Azure DevOps MCP server for '${ADO_ORG}'."
        any_failed=1
        continue
    fi
    log_ok "Azure DevOps MCP server registered (org: ${ADO_ORG}, server: ${SERVER_NAME}, auth: az login via azcli)."
done

log_info "Make sure you've run 'az login' before using Azure DevOps tools in Copilot CLI."

if [[ "$any_failed" -eq 1 ]]; then
    exit 1
fi

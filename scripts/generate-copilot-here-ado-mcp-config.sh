#!/usr/bin/env bash
# Generates ~/.config/copilot_here/azure-devops-mcp.json: an MCP server
# config entry per Azure DevOps organization listed in
# ~/.azure-devops.local (the same file/format already used by
# install-azure-devops-mcp.sh - no duplicated org configuration), wired up
# with `--authentication pat` instead of the host-side `azcli` auth.
#
# Why `pat` here: the HOST copilot CLI's MCP registration
# (install-azure-devops-mcp.sh) uses `--authentication azcli`, reusing the
# host's `az login` session. Inside a copilot_here container there is no
# `az` binary and no `~/.azure` token cache, so that auth mode can't work
# there. `--authentication pat` only needs a PERSONAL_ACCESS_TOKEN env var
# (base64 "<email>:<pat>"), which is supplied at container-run time via a
# Podman secret - see set-azure-devops-pat-secret.sh and the `copilot_ado` /
# `copilot_ado_yolo` wrapper functions in dotfiles/.zshrc.
#
# This generated file is fed to the containerized Copilot CLI via
# copilot_here's own `--additional-mcp-config @<file>` flag, so the
# container never needs ~/.copilot mounted in at all.
#
# Re-run this script any time ~/.azure-devops.local's org list changes -
# it always overwrites the generated file; don't hand-edit it.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

ADO_ORG_FILE="$HOME/.azure-devops.local"
OUT_DIR="$HOME/.config/copilot_here"
OUT_FILE="$OUT_DIR/azure-devops-mcp.json"
# Same placeholders install-azure-devops-mcp.sh ignores, kept in sync so an
# unedited .azure-devops.local.example copy doesn't produce a bogus entry.
ADO_ORG_PLACEHOLDERS=("your-ado-org-name" "your-first-ado-org-name" "your-second-ado-org-name" "your-third-ado-org-name")

if ! command_exists node && ! command_exists npx; then
    log_warn "npx (Node.js) not found. Run install-node.sh first - the generated config still works once Node is available in the copilot_here image (base image ships Node.js already)."
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

mkdir -p "$OUT_DIR"

{
    echo '{'
    echo '  "mcpServers": {'
    for i in "${!ADO_ORGS[@]}"; do
        org="${ADO_ORGS[$i]}"
        server_name="azure-devops-$(printf '%s' "$org" | tr -c 'a-zA-Z0-9_-' '-')"
        comma=","
        [[ $i -eq $(( ${#ADO_ORGS[@]} - 1 )) ]] && comma=""
        cat <<EOF
    "${server_name}": {
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "${org}", "--authentication", "pat"],
      "tools": ["*"]
    }${comma}
EOF
    done
    echo '  }'
    echo '}'
} >"$OUT_FILE"

log_ok "Generated ${OUT_FILE} with ${#ADO_ORGS[@]} org(s): ${ADO_ORGS[*]}"
log_info "This file is passed to the container via: copilot_here --additional-mcp-config @${OUT_FILE}"
log_info "Make sure the Podman secret the PAT lives in is set up: scripts/set-azure-devops-pat-secret.sh"
log_info "Then use 'copilot_ado' / 'copilot_ado_yolo' (dotfiles/.zshrc) instead of calling copilot_here directly."

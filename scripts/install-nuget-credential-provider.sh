#!/usr/bin/env bash
# Idempotently installs Microsoft's Azure Artifacts Credential Provider
# (github.com/microsoft/artifacts-credprovider, .NET 8+ build) into
# ~/.nuget/plugins/netcore, so `dotnet restore`/`nuget` can authenticate to
# private Azure DevOps NuGet feeds.
#
# No secret is handled here. The dotfiles .zshrc exports
# VSS_NUGET_EXTERNAL_FEED_ENDPOINTS per shell from the `azure-devops-pat`
# Podman secret and the orgs in ~/.azure-devops.local, which the provider
# reads to authenticate with that PAT.
#
# Requires the .NET SDK (install-dotnet.sh) and jq (via the dotfiles .zshrc).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

PLUGIN_DIR="$HOME/.nuget/plugins/netcore/CredentialProvider.Microsoft"
INSTALL_URL="https://aka.ms/install-artifacts-credprovider.sh"

if [[ -f "$PLUGIN_DIR/CredentialProvider.Microsoft.dll" ]]; then
    log_info "Azure Artifacts Credential Provider already installed (${PLUGIN_DIR}), skipping."
    exit 0
fi

if ! command_exists dotnet; then
    log_err "dotnet not found -- run install-dotnet.sh first."
    exit 1
fi

if ! command_exists jq; then
    log_info "Installing jq via Homebrew (used to build the feed endpoints JSON)..."
    brew install jq || { log_err "brew install jq failed."; exit 1; }
fi

log_info "Installing Azure Artifacts Credential Provider..."
if ! curl -fsSL "$INSTALL_URL" | bash; then
    log_err "Credential provider install script failed."
    exit 1
fi

if [[ ! -f "$PLUGIN_DIR/CredentialProvider.Microsoft.dll" ]]; then
    log_err "Credential provider not found at ${PLUGIN_DIR} after install."
    exit 1
fi

log_ok "Azure Artifacts Credential Provider installed."

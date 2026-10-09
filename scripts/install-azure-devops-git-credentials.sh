#!/usr/bin/env bash
# Idempotently configures a git credential helper for Azure DevOps
# (dev.azure.com) that supplies the PAT stored in the `azure-devops-pat`
# Podman secret (see README). No Git Credential Manager / Windows
# Credential Manager involved. Scoped ONLY to dev.azure.com -- other git
# hosts are untouched. Any git client (e.g. lazygit) picks it up.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

ADO_HELPER_KEY="credential.https://dev.azure.com.helper"
ADO_HTTPPATH_KEY="credential.https://dev.azure.com.useHttpPath"
HELPER_SRC="$SCRIPT_DIR/git-credential-azure-devops"
HELPER_DEST="$HOME/.local/bin/git-credential-azure-devops"

mkdir -p "$(dirname "$HELPER_DEST")"
if ! cmp -s "$HELPER_SRC" "$HELPER_DEST"; then
    install -m 755 "$HELPER_SRC" "$HELPER_DEST"
    log_ok "Installed ${HELPER_DEST}"
fi

if [[ "$(git config --global --get "$ADO_HELPER_KEY" 2>/dev/null || true)" == "$HELPER_DEST" ]]; then
    log_info "Azure DevOps git credential helper already configured, skipping."
    exit 0
fi

# Replace any previous (e.g. GCM) helper for this host.
git config --global --unset-all "$ADO_HELPER_KEY" 2>/dev/null || true
git config --global "$ADO_HELPER_KEY" "$HELPER_DEST"
git config --global "$ADO_HTTPPATH_KEY" true
log_ok "Azure DevOps git credential helper configured: ${HELPER_DEST}"

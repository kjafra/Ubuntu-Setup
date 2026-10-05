#!/usr/bin/env bash
# Stores an Azure DevOps Personal Access Token (PAT) as a Podman secret so
# it can be exposed to copilot_here containers (see
# generate-copilot-here-ado-mcp-config.sh and the `copilot_ado` /
# `copilot_ado_yolo` wrapper functions in dotfiles/.zshrc) without ever
# mounting host credentials or touching an on-disk env file.
#
# Why this exists: install-azure-devops-mcp.sh registers the Azure DevOps
# MCP server on the HOST copilot CLI using `--authentication azcli` (reuses
# `az login`). That doesn't work inside a copilot_here container, which has
# neither the `az` binary nor the host's `~/.azure` token cache. The
# container-side MCP server instead uses `--authentication pat`
# (github.com/microsoft/azure-devops-mcp), which only needs a
# PERSONAL_ACCESS_TOKEN env var containing base64("<email>:<pat>"). A
# Podman secret exposed via `--secret <name>,type=env,target=VAR` gets that
# value into the container without it ever appearing in shell history,
# `ps` output, or a dotfile on disk.
#
# The PAT value itself is expected to live in your own password manager
# (e.g. KeePass on Windows) - this script only asks for it once, at
# creation/rotation time, and pipes it straight into `podman secret
# create`. Nothing is written to disk by this script.
#
# NOTE: This only works when copilot_here is run in standard (non-Airlock)
# mode. Airlock mode converts SANDBOX_FLAGS into a fixed Docker Compose
# subset (--env/--cap-add/--cap-drop/--ulimit/--memory/--cpus only) and
# silently drops unrecognized flags like --secret.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

SECRET_NAME="${AZURE_DEVOPS_PAT_SECRET_NAME:-azure-devops-pat}"

if ! command_exists podman; then
    log_err "podman not found. Run install-podman.sh first, then re-run this script."
    exit 1
fi

if ! podman info >/dev/null 2>&1; then
    log_err "podman is installed but not usable right now (service not running?). Check 'brew services start podman' / the login-banner reminders, then re-run."
    exit 1
fi

log_info "This stores an Azure DevOps PAT as the Podman secret '${SECRET_NAME}'."
log_info "The PAT is never written to disk or shell history by this script - only piped into 'podman secret create'."
echo

read -r -p "Azure DevOps account email (any non-empty value is accepted by the MCP server): " ADO_EMAIL
if [[ -z "$ADO_EMAIL" ]]; then
    log_err "Email cannot be empty."
    exit 1
fi

read -r -s -p "Azure DevOps PAT (input hidden): " ADO_PAT
echo
if [[ -z "$ADO_PAT" ]]; then
    log_err "PAT cannot be empty."
    exit 1
fi

# @azure-devops/mcp's `pat` authentication mode requires PERSONAL_ACCESS_TOKEN
# to be the base64 encoding of "<email>:<pat>", not the raw PAT.
ENCODED_PAT="$(printf '%s:%s' "$ADO_EMAIL" "$ADO_PAT" | base64 -w0)"
unset ADO_PAT

if podman secret inspect "$SECRET_NAME" >/dev/null 2>&1; then
    log_info "Secret '${SECRET_NAME}' already exists, replacing it..."
    podman secret rm "$SECRET_NAME" >/dev/null
fi

if ! printf '%s' "$ENCODED_PAT" | podman secret create "$SECRET_NAME" - >/dev/null; then
    log_err "Failed to create Podman secret '${SECRET_NAME}'."
    unset ENCODED_PAT
    exit 1
fi
unset ENCODED_PAT

log_ok "Podman secret '${SECRET_NAME}' created."
log_info "Use 'copilot_ado' / 'copilot_ado_yolo' (dotfiles/.zshrc) to run copilot_here with Azure DevOps MCP tools available."
log_info "Re-run this script any time the PAT needs rotating."

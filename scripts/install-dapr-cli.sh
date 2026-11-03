#!/usr/bin/env bash
# Idempotently installs the Dapr CLI (dapr) via Homebrew, using the official
# dapr/tap tap (it is not in homebrew-core). This script only installs the
# binary - it deliberately does NOT run `dapr init`, which pulls container
# images and needs a running container runtime (Podman here).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists dapr; then
    log_info "Dapr CLI already installed ($(dapr version 2>/dev/null | head -n1 || echo 'version unknown')), skipping."
    exit 0
fi

log_info "Installing Dapr CLI via Homebrew (dapr/tap)..."
if ! brew install dapr/tap/dapr-cli; then
    log_err "brew install dapr/tap/dapr-cli failed."
    exit 1
fi

log_ok "Dapr CLI installed."
log_info "To set up the local runtime, run: dapr init --container-runtime podman"

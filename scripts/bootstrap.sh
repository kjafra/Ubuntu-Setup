#!/usr/bin/env bash
# Runs all setup scripts in order. Each individual script is independently
# idempotent, so re-running this is always safe.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

STEPS=(
    "update-base-packages.sh"
    "install-git.sh"
    "install-github-cli.sh"
    "install-helix.sh"
    "install-zellij.sh"
    "install-podman.sh"
)

for step in "${STEPS[@]}"; do
    log_info "==> Running ${step}"
    "$SCRIPT_DIR/${step}"
done

log_ok "Ubuntu setup complete."

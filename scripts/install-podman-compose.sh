#!/usr/bin/env bash
# Idempotently installs podman-compose via Homebrew, the compose provider
# used by `podman compose`. Runs after install-podman.sh.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists podman-compose; then
    log_info "podman-compose already installed ($(podman-compose --version 2>&1 | head -n1)), skipping install."
    exit 0
fi

log_info "Installing podman-compose via Homebrew..."
if ! brew install podman-compose; then
    log_err "brew install podman-compose failed."
    exit 1
fi

log_ok "podman-compose installed."

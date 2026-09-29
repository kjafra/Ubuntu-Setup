#!/usr/bin/env bash
# Idempotently installs git-delta (the `delta` binary) via Homebrew, used
# as core.pager in the dotfiles-provided .gitconfig.
#
# This script only installs the binary - the .gitconfig that points
# core.pager at delta comes from the dotfiles bare-repo checkout, not
# from this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists delta; then
    log_info "delta already installed ($(delta --version)), skipping install."
    exit 0
fi

log_info "Installing git-delta via Homebrew..."
if ! brew install git-delta; then
    log_err "brew install git-delta failed."
    exit 1
fi

log_ok "delta installed: $(delta --version)"

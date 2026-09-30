#!/usr/bin/env bash
# Idempotently installs ripgrep (rg) via Homebrew.
#
# Helix's global search (space+/) shells out to the `rg` binary, so it must
# be present on PATH for that feature to work.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists rg; then
    log_info "ripgrep already installed ($(rg --version | head -n1)), skipping install."
    exit 0
fi

log_info "Installing ripgrep via Homebrew..."
if ! brew install ripgrep; then
    log_err "brew install ripgrep failed."
    exit 1
fi

log_ok "ripgrep installed: $(rg --version | head -n1)"

#!/usr/bin/env bash
# Idempotently installs copilot_here (github.com/GordonBeeming/copilot_here):
# a shell-function wrapper that runs the GitHub Copilot CLI inside a
# sandboxed container (Docker/OrbStack/Podman, auto-detected - our
# rootless Podman install from install-podman.sh is natively supported, no
# extra wiring needed) with filesystem access limited to the current
# directory, using the host's existing `gh` credentials.
#
# This script only installs the binary + `.copilot_here.sh` via upstream's
# own official installer. It deliberately does NOT touch ~/.zshrc itself:
# the `copilot_here` shell-integration marker block that the installer
# would normally inject at runtime is instead pre-seeded as tracked
# content in the dotfiles repo's .zshrc (see that repo's commit adding it)
# so install-dotfiles.sh's bare-repo checkout never conflicts with it.
# When the installer below rewrites that block, the content is identical,
# so it's a no-op diff.
#
# Requires `gh` to be installed and logged in with the `copilot` and
# `read:packages` scopes before first use:
#   gh auth refresh -h github.com -s copilot,read:packages
# (not checked/run here - no credentials are expected to exist yet in a
# freshly provisioned environment).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

COPILOT_HERE_BIN="$HOME/.local/bin/copilot_here"
COPILOT_HERE_INSTALL_URL="https://github.com/GordonBeeming/copilot_here/releases/download/cli-latest/install.sh"

if [[ -x "$COPILOT_HERE_BIN" ]]; then
    log_info "copilot_here already installed ($("$COPILOT_HERE_BIN" --version 2>&1 | head -n1)), skipping install."
    log_info "To upgrade later, open a new shell and run: copilot_here --update"
    exit 0
fi

log_info "Installing copilot_here from ${COPILOT_HERE_INSTALL_URL}..."
# shellcheck disable=SC1090
if ! source <(curl -fsSL "$COPILOT_HERE_INSTALL_URL"); then
    log_err "copilot_here install failed."
    exit 1
fi

log_ok "copilot_here installed."
log_info "Before first use, make sure 'gh' is authenticated with the required scopes:"
log_info "  gh auth refresh -h github.com -s copilot,read:packages"
log_info "Then open a new shell and run: copilot_here --help"

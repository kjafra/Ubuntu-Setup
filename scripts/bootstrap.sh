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
    "install-homebrew.sh"
    "install-github-cli.sh"
    "install-helix.sh"
    "install-ripgrep.sh"
    "install-fd.sh"
    "install-tmux.sh"
    "install-podman.sh"
    "install-delta.sh"
    "install-lazygit.sh"
    "install-lazydocker.sh"
    "install-yazi.sh"
    "install-eza.sh"
    "install-zsh.sh"
    "install-node.sh"
    "install-dotnet.sh"
    "install-language-servers.sh"
    "install-azure-cli.sh"
    "install-dotfiles.sh"
    "install-git-hooks.sh"
    "install-copilot-cli.sh"
    "install-azure-devops-mcp.sh"
    "install-azure-devops-git-credentials.sh"
)

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

for step in "${STEPS[@]}"; do
    log_info "==> Running ${step}"
    "$SCRIPT_DIR/${step}"

    # install-homebrew.sh puts brew on PATH for its own subprocess, but
    # that doesn't propagate back to this script or later steps (each runs
    # as its own subprocess) - re-source it here once brew exists so every
    # later step can find `brew` on PATH without a fresh login shell.
    if [[ "$step" == "install-homebrew.sh" && -x "$BREW_BIN" ]]; then
        eval "$("$BREW_BIN" shellenv)"
    fi
done

log_ok "Ubuntu setup complete."

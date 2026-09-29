#!/usr/bin/env bash
# Idempotently deploys github.com/falwickster/dotfiles into $HOME using the
# bare-repo checkout pattern (see the dotfiles repo's own README): a bare
# clone lives at $HOME/.dotfiles.git, and its worktree is $HOME itself.
#
# This script only sets up the mechanics of the checkout - it contains no
# config content of its own. All actual config files (.zshrc,
# .config/lazygit/config.yml, .config/helix/config.toml, etc.) live in the
# dotfiles repo.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

DOTFILES_REPO_URL="https://github.com/falwickster/dotfiles.git"
DOTFILES_GIT_DIR="$HOME/.dotfiles.git"

dotfiles_git() {
    git --git-dir="$DOTFILES_GIT_DIR" --work-tree="$HOME" "$@"
}

if [[ -d "$DOTFILES_GIT_DIR" ]]; then
    log_info "dotfiles bare repo already present at $DOTFILES_GIT_DIR, skipping clone."
else
    log_info "Cloning dotfiles bare repo from $DOTFILES_REPO_URL to $DOTFILES_GIT_DIR..."
    if ! git clone --bare "$DOTFILES_REPO_URL" "$DOTFILES_GIT_DIR"; then
        log_err "Failed to clone $DOTFILES_REPO_URL."
        exit 1
    fi
    dotfiles_git config --local status.showUntrackedFiles no
fi

log_info "Checking out dotfiles into $HOME..."
if dotfiles_git checkout; then
    log_ok "dotfiles checked out into $HOME."
else
    log_err "dotfiles checkout reported conflicts (existing files would be overwritten)."
    log_err "Resolve manually: back up or remove the conflicting files listed above, then re-run this script."
    exit 1
fi

log_ok "dotfiles deployed. Use the 'dotfiles' shell function (pull/fetch/merge/status/log/diff) to sync future updates."

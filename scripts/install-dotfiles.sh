#!/usr/bin/env bash
# Idempotently deploys github.com/kjafra/dotfiles into $HOME with chezmoi.
# chezmoi keeps its own clone of the repo in ~/.local/share/chezmoi and
# copies files into $HOME, so $HOME is never a git work tree. Which files
# land on Linux is decided by the repo's home/.chezmoiignore (Windows-only
# paths are skipped).
#
# This script only sets up the mechanics - it contains no config content of
# its own. Existing files that differ from the repo are moved to
# ~/.dotfiles-backup/<timestamp> before being overwritten.
#
# Optional env: DOTFILES_REPO (default kjafra/dotfiles), DOTFILES_BRANCH.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

DOTFILES_REPO="${DOTFILES_REPO:-kjafra/dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-}"
export PATH="$HOME/.local/bin:$PATH"

if command_exists chezmoi; then
    log_info "chezmoi already installed ($(chezmoi --version | cut -d, -f1))."
else
    log_info "Installing chezmoi to ~/.local/bin (official installer, checksum-verified)..."
    if ! sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"; then
        log_err "Failed to install chezmoi."
        exit 1
    fi
fi

if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi/.git" ]]; then
    log_info "chezmoi source already present, skipping init."
else
    log_info "Initialising chezmoi from $DOTFILES_REPO..."
    init_args=("$DOTFILES_REPO")
    [[ -n "$DOTFILES_BRANCH" ]] && init_args+=(--branch "$DOTFILES_BRANCH")
    if ! chezmoi init "${init_args[@]}"; then
        log_err "chezmoi init failed."
        exit 1
    fi
fi

# Back up managed files that exist locally but differ from the repo.
backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
while IFS= read -r line; do
    [[ -z "$line" || "${line:1:1}" == " " ]] && continue
    rel="${line:3}"
    [[ -f "$HOME/$rel" ]] || continue
    mkdir -p "$backup/$(dirname "$rel")"
    cp -a "$HOME/$rel" "$backup/$rel"
    log_warn "Backed up $rel -> $backup/$rel"
done < <(chezmoi status)

log_info "Applying dotfiles into $HOME..."
if ! chezmoi apply --force; then
    log_err "chezmoi apply failed. Inspect with 'chezmoi diff'."
    exit 1
fi

# Identity/credential helpers are machine-specific and not managed.
if [[ ! -e "$HOME/.gitconfig.local" && -e "$HOME/.gitconfig.local.example" ]]; then
    cp "$HOME/.gitconfig.local.example" "$HOME/.gitconfig.local"
    log_warn "Created ~/.gitconfig.local from the example - fill in your name/email/credential helpers."
fi

# Retire the legacy bare-repo checkout once chezmoi has applied cleanly.
if [[ -d "$HOME/.dotfiles.git" ]]; then
    mkdir -p "$HOME/.dotfiles-backup"
    mv "$HOME/.dotfiles.git" "$HOME/.dotfiles-backup/legacy-dotfiles.git"
    log_warn "Moved legacy ~/.dotfiles.git to ~/.dotfiles-backup/legacy-dotfiles.git."
fi

log_ok "dotfiles deployed. Use the 'dotfiles' shell function (pull/diff/apply/status/verify) to sync future updates."

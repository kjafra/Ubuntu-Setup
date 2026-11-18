#!/usr/bin/env bash
# Idempotently installs Homebrew (Linuxbrew), which every other
# install-*.sh script in this repo (besides this one and install-git.sh)
# uses as its sole package manager for "tools".
#
# apt is used only for the handful of build dependencies Homebrew itself
# requires to bootstrap on Debian/Ubuntu (build-essential, procps, curl,
# file) - git is already installed by install-git.sh, which runs before
# this script. Everything else - the actual dev tools - installs via
# `brew install` in their own scripts.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
BREW_BIN="$BREW_PREFIX/bin/brew"
PROFILE_SNIPPET="/etc/profile.d/60-homebrew.sh"

if command_exists brew || [[ -x "$BREW_BIN" ]]; then
    log_info "Homebrew already installed ($("$BREW_BIN" --version 2>/dev/null | head -n1 || brew --version | head -n1)), skipping install."
else
    log_info "Installing Homebrew's Linux build dependencies via apt..."
    apt_update_once
    if ! sudo apt-get install -y build-essential procps curl file; then
        require_sudo_hint "apt-get install build-essential procps curl file"
        exit 1
    fi

    log_info "Running the official non-interactive Homebrew installer..."
    if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log_err "Homebrew installation failed."
        exit 1
    fi

    if [[ ! -x "$BREW_BIN" ]]; then
        log_err "Expected brew binary not found at $BREW_BIN after install."
        exit 1
    fi

    log_ok "Homebrew installed: $("$BREW_BIN" --version | head -n1)"
fi

# Make brew available to the rest of *this* script run and to bootstrap.sh
# (which sources this file's effect via its own `brew shellenv` call after
# invoking this script - see bootstrap.sh).
ensure_brew_on_path

log_info "Writing $PROFILE_SNIPPET so future login shells get brew on PATH..."
if ! sudo tee "$PROFILE_SNIPPET" >/dev/null <<EOF
# Puts Homebrew (Linuxbrew) on PATH for all users/shells.
# Managed by Ubuntu-Setup/scripts/install-homebrew.sh.
eval "\$($BREW_BIN shellenv)"
EOF
then
    require_sudo_hint "writing $PROFILE_SNIPPET"
    exit 1
fi
sudo chmod 644 "$PROFILE_SNIPPET"

log_ok "Homebrew ready: $(brew --version | head -n1) (PATH persisted via $PROFILE_SNIPPET)."

#!/usr/bin/env bash
# Shared helper functions for the setup scripts in this repository.
# Source this file; do not execute it directly.

set -euo pipefail

log_info() { printf '\033[36m%s\033[0m\n' "$*"; }
log_warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
log_ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
log_err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }

# Returns success if the given command is available on PATH.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Returns success if the given apt package is installed.
apt_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Prints a consistent hint pointing at sudo/permissions when a step fails.
require_sudo_hint() {
    local context="$1"
    log_warn "${context} failed. If this looks like a permissions error, re-run with sudo (or as a user with sudo rights) and try again."
}

# Runs `apt-get update` at most once per shell process tree, guarded by a
# marker file, so multiple scripts can call this without repeating the work.
apt_update_once() {
    local marker="/tmp/.ubuntu-setup-apt-updated"
    if [[ -f "$marker" ]]; then
        return 0
    fi
    log_info "Running apt-get update..."
    if ! sudo apt-get update -y; then
        require_sudo_hint "apt-get update"
        return 1
    fi
    touch "$marker"
}

# Ensures `brew` is callable in the current shell, even when this script is
# run standalone in a shell that predates install-homebrew.sh's
# /etc/profile.d/60-homebrew.sh (e.g. the same non-login shell that just
# ran install-homebrew.sh for the first time). No-ops if brew is already on
# PATH or isn't installed at all (the calling script's own install-homebrew
# dependency check will report that).
ensure_brew_on_path() {
    if command_exists brew; then
        return 0
    fi
    local brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
    if [[ -x "$brew_bin" ]]; then
        eval "$("$brew_bin" shellenv)"
    fi
}

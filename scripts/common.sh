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

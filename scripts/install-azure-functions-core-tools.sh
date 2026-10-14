#!/usr/bin/env bash
# Idempotently installs Azure Functions Core Tools v4 (`func`) via the
# official Homebrew tap (azure/functions).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

# func is a self-contained .NET app that aborts without ICU (libicu).
icu_pkg="$(apt-cache search --names-only '^libicu[0-9]+$' 2>/dev/null | awk '{print $1}' | sort -V | tail -n1)"
if [[ -n "$icu_pkg" ]] && ! apt_package_installed "$icu_pkg"; then
    apt_update_once
    log_info "Installing $icu_pkg (required by .NET apps such as func)..."
    if ! sudo apt-get install -y "$icu_pkg"; then
        require_sudo_hint "apt-get install $icu_pkg"
        exit 1
    fi
fi

if linux_command_exists func; then
    log_info "Azure Functions Core Tools already installed ($(func --version 2>/dev/null || echo 'version unknown')), skipping."
    exit 0
fi

log_info "Installing Azure Functions Core Tools via Homebrew..."
if ! brew tap azure/functions; then
    log_err "brew tap azure/functions failed."
    exit 1
fi
# Recent Homebrew refuses to load formulae from untrusted third-party taps.
if brew commands --quiet 2>/dev/null | grep -qx trust; then
    brew trust azure/functions || log_warn "brew trust azure/functions failed; install may be refused."
fi
if ! brew install azure-functions-core-tools@4; then
    log_err "brew install azure-functions-core-tools@4 failed."
    exit 1
fi

log_ok "Azure Functions Core Tools installed."

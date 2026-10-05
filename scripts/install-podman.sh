#!/usr/bin/env bash
# Idempotently installs Podman via Homebrew.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

# Rootless Podman needs newuidmap/newgidmap to map subordinate UID/GID
# ranges into containers. These are setuid-root binaries that must come
# from the OS's own package manager (Homebrew intentionally can't ship
# setuid binaries), so this one piece stays on apt even though podman
# itself installs via brew.
if ! command_exists newuidmap; then
    log_info "Installing uidmap via apt (needed for rootless Podman)..."
    apt_update_once
    if ! sudo apt-get install -y uidmap; then
        require_sudo_hint "apt-get install uidmap"
        exit 1
    fi
fi

if command_exists podman; then
    log_info "Podman already installed ($(podman --version)), skipping."
else
    log_info "Installing podman via Homebrew..."
    if ! brew install podman; then
        log_err "brew install podman failed."
        exit 1
    fi
    log_ok "Podman installed: $(podman --version)"
fi

# Homebrew's podman formula ships policy.json/registries.conf under
# $HOMEBREW_PREFIX/etc/containers/, but podman's compiled-in search paths
# for these files are the Linux-standard locations (~/.config/containers,
# /etc/containers, /usr/share/containers) - none of which point into the
# Homebrew prefix. Without a policy.json on one of those paths, every pull
# fails with "config file not found: no policy.json file found", even
# though the setup/network is otherwise fine. Symlink the Homebrew-provided
# files into the user-scope path podman checks first (no sudo needed,
# keeps this rootless-first like the rest of the script), but only if
# nothing already exists at any of podman's searched paths - never clobber
# a user's own config.
ensure_containers_config_symlink() {
    local filename="$1"
    local user_path="$HOME/.config/containers/$filename"
    local brew_path="$HOMEBREW_PREFIX/etc/containers/$filename"

    if [[ -e "$HOME/.config/containers/$filename" || -e "/etc/containers/$filename" || -e "/usr/share/containers/$filename" ]]; then
        return 0
    fi

    if [[ ! -e "$brew_path" ]]; then
        log_warn "Homebrew podman did not ship $filename at $brew_path, skipping symlink."
        return 0
    fi

    mkdir -p "$HOME/.config/containers"
    ln -s "$brew_path" "$user_path"
    log_ok "Linked $user_path -> $brew_path"
}

ensure_containers_config_symlink "policy.json"
ensure_containers_config_symlink "registries.conf"

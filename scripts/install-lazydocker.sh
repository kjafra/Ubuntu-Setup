#!/usr/bin/env bash
# Idempotently installs lazydocker and wires it up to talk to rootless
# Podman via Podman's Docker-API-compatible socket (lazydocker only knows
# how to speak the Docker Engine API, not the Podman CLI/API directly).
#
# lazydocker isn't packaged for apt or snap. `go install` was tried first,
# but as of writing it fails to build (upstream's pinned
# github.com/docker/docker dependency doesn't compile - see
# https://github.com/jesseduffield/lazydocker/issues for the current
# status), so this falls back to the same officially documented Linux
# install method upstream recommends in its own README: downloading a
# release binary directly from GitHub (mirroring the pattern already used
# for Zellij in install-zellij.sh).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

install_lazydocker_via_release_binary() {
    log_info "Looking up latest lazydocker release..."
    local version
    version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep -Po '"tag_name":\s*"v\K[^"]*')"
    if [[ -z "$version" ]]; then
        log_err "Could not determine the latest lazydocker version from the GitHub API."
        return 1
    fi

    local arch target
    arch="$(uname -m)"
    case "$arch" in
        x86_64) target="x86_64" ;;
        aarch64|arm64) target="arm64" ;;
        *)
            log_err "Unsupported architecture for the prebuilt lazydocker binary: $arch"
            return 1
            ;;
    esac

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    local download_url="https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${target}.tar.gz"
    log_info "Downloading lazydocker ${version} from $download_url..."
    if ! curl -fsSL "$download_url" -o "$tmp_dir/lazydocker.tar.gz"; then
        log_err "Failed to download lazydocker from $download_url"
        return 1
    fi

    tar -xzf "$tmp_dir/lazydocker.tar.gz" -C "$tmp_dir" lazydocker

    if ! sudo install -m 755 "$tmp_dir/lazydocker" /usr/local/bin/lazydocker; then
        require_sudo_hint "installing lazydocker to /usr/local/bin"
        return 1
    fi
}

# Enables the user-level podman.socket unit (Podman's rootless,
# Docker-API-compatible endpoint) and points DOCKER_HOST at it via a single
# static /etc/profile.d/ file, so lazydocker (and any other Docker-API
# client) can talk to Podman without needing Docker itself.
enable_podman_socket() {
    if ! command_exists podman; then
        log_warn "podman is not installed; skipping podman socket setup for lazydocker."
        return 0
    fi

    if ! command_exists systemctl; then
        log_warn "systemctl not available (no systemd?); cannot enable the podman.socket user service. lazydocker will not be able to reach podman until you start it manually."
        return 0
    fi

    log_info "Enabling the rootless podman.socket user service..."
    if ! systemctl --user enable --now podman.socket 2>/dev/null; then
        log_warn "Could not enable podman.socket via 'systemctl --user'. If this is WSL2, ensure systemd is enabled (systemd=true under [boot] in /etc/wsl.conf) and re-run this script."
        return 0
    fi

    # Let the podman.socket user service keep running after the interactive
    # session ends, so lazydocker can reach it reliably from any shell.
    if command_exists loginctl; then
        loginctl enable-linger "${USER:-$(id -un)}" 2>/dev/null || true
    fi

    local profile_snippet="/etc/profile.d/50-podman-docker-host.sh"
    log_info "Writing $profile_snippet to point DOCKER_HOST at the rootless podman socket..."
    if ! sudo tee "$profile_snippet" >/dev/null <<'EOF'
# Points Docker-API clients (lazydocker, etc.) at Podman's rootless socket.
# Managed by Ubuntu-Setup/scripts/install-lazydocker.sh.
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
EOF
    then
        require_sudo_hint "writing $profile_snippet"
        return 1
    fi
    sudo chmod 644 "$profile_snippet"

    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
    log_ok "podman.socket enabled; DOCKER_HOST set to $DOCKER_HOST (persisted for future login shells via $profile_snippet)."
}

if command_exists lazydocker; then
    log_info "lazydocker already installed ($(lazydocker --version 2>&1 | head -n1)), skipping install."
elif install_lazydocker_via_release_binary; then
    log_ok "lazydocker installed: $(lazydocker --version 2>&1 | head -n1)"
else
    log_err "Could not install lazydocker."
    exit 1
fi

enable_podman_socket

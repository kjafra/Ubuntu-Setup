#!/usr/bin/env bash
# Idempotently installs lazydocker via Homebrew and wires it up to talk to
# rootless Podman via Podman's Docker-API-compatible socket (lazydocker
# only knows how to speak the Docker Engine API, not the Podman CLI/API
# directly).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

# Starts podman's API service (Podman's rootless, Docker-API-compatible
# endpoint) as a Homebrew-managed background service, and points
# DOCKER_HOST at its socket via a single static /etc/profile.d/ file, so
# lazydocker (and any other Docker-API client) can talk to Podman without
# needing Docker itself.
#
# Homebrew's podman formula doesn't ship the systemd-socket-activation unit
# that apt's package does; instead its `service` block runs
# `podman system service --time 0` directly, kept alive via
# `brew services`. Podman's own default listening socket when run this way
# (no --uri given, invoked as a normal user) is still
# unix://$XDG_RUNTIME_DIR/podman/podman.sock - same path as the old
# socket-activated setup, just served by an always-on process instead of
# being activated on first connection.
enable_podman_socket() {
    if ! command_exists podman; then
        log_warn "podman is not installed; skipping podman socket setup for lazydocker."
        return 0
    fi

    log_info "Starting the podman API service via 'brew services'..."
    if ! brew services start podman 2>/dev/null; then
        log_warn "Could not start podman via 'brew services'. lazydocker will not be able to reach podman until you start it manually (podman system service --time 0 &)."
        return 0
    fi

    # brew services on Linux with systemd manages the service as a systemd
    # --user unit; enable linger so it (and the underlying user session)
    # keeps running after the interactive login session ends.
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
    log_ok "podman service started via brew services; DOCKER_HOST set to $DOCKER_HOST (persisted for future login shells via $profile_snippet)."
}

if command_exists lazydocker; then
    log_info "lazydocker already installed ($(lazydocker --version 2>&1 | head -n1)), skipping install."
else
    log_info "Installing lazydocker via Homebrew..."
    if ! brew install lazydocker; then
        log_err "brew install lazydocker failed."
        exit 1
    fi
    log_ok "lazydocker installed: $(lazydocker --version 2>&1 | head -n1)"
fi

enable_podman_socket

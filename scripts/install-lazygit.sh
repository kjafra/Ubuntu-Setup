#!/usr/bin/env bash
# Idempotently installs lazygit and configures it to use Helix (hx) as its
# default editor.
#
# Debian 13 / Ubuntu 25.10 and later ship lazygit in the apt archive, so we
# try that first. Older releases fall back to `go install`, which still
# resolves and verifies the module through the Go package proxy rather than
# downloading a raw GitHub release binary by hand.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# lazygit ships a built-in "helix (hx)" editor preset that invokes the `hx`
# binary, matching what install-helix.sh installs.
configure_lazygit_editor() {
    local config_dir="$HOME/.config/lazygit"
    local config_file="$config_dir/config.yml"
    mkdir -p "$config_dir"

    if [[ -f "$config_file" ]] && grep -q '^\s*editPreset:' "$config_file"; then
        log_info "lazygit editPreset already configured in $config_file, leaving as-is."
        return 0
    fi

    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" <<'EOF'
os:
  editPreset: "helix (hx)"
EOF
    else
        printf '\nos:\n  editPreset: "helix (hx)"\n' >> "$config_file"
    fi
    log_ok "Configured lazygit to use helix (hx) as its default editor ($config_file)."
}

install_lazygit_via_go() {
    log_warn "lazygit is not available via apt on this release; falling back to 'go install'."

    if ! command_exists go; then
        apt_update_once
        log_info "Installing golang-go (needed to build lazygit)..."
        if ! sudo apt-get install -y golang-go; then
            require_sudo_hint "apt-get install golang-go"
            return 1
        fi
    fi

    log_info "Building and installing lazygit via 'go install' (this can take a minute)..."
    if ! GOTOOLCHAIN=auto GOBIN="$(go env GOPATH)/bin" go install github.com/jesseduffield/lazygit@latest; then
        log_err "go install github.com/jesseduffield/lazygit@latest failed."
        return 1
    fi

    local built_binary
    built_binary="$(go env GOPATH)/bin/lazygit"
    if [[ ! -x "$built_binary" ]]; then
        log_err "Expected lazygit binary not found at $built_binary after go install."
        return 1
    fi

    if ! sudo install -m 755 "$built_binary" /usr/local/bin/lazygit; then
        require_sudo_hint "installing lazygit to /usr/local/bin"
        return 1
    fi
}

if command_exists lazygit; then
    log_info "lazygit already installed ($(lazygit --version | head -n1)), skipping install."
else
    apt_update_once

    log_info "Attempting to install lazygit via apt..."
    if sudo apt-get install -y lazygit 2>/dev/null && command_exists lazygit; then
        log_ok "lazygit installed via apt: $(lazygit --version | head -n1)"
    elif install_lazygit_via_go; then
        log_ok "lazygit installed via go install: $(lazygit --version | head -n1)"
    else
        log_err "Could not install lazygit via apt or go install."
        exit 1
    fi
fi

configure_lazygit_editor

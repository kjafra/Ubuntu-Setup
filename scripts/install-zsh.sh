#!/usr/bin/env bash
# Idempotently installs zsh plus the plugins/tools needed to mirror the
# Windows PowerShell profile's feature set (fzf Ctrl+R history search,
# ghost-text history autosuggestions), and sets zsh as the login shell.
#
# This script only installs and enables tools - it writes no shell config.
# All config content (.zshrc, key bindings, plugin sourcing) is deployed via
# the dotfiles bare-repo checkout; see install-dotfiles.sh.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

PLUGIN_DIR="$HOME/.local/share/zsh/plugins"

install_apt_package() {
    local package="$1"
    if apt_package_installed "$package"; then
        return 0
    fi
    apt_update_once
    log_info "Installing $package via apt..."
    if ! sudo apt-get install -y "$package"; then
        require_sudo_hint "apt-get install $package"
        return 1
    fi
}

install_zsh_autosuggestions() {
    if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
        || [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
        log_info "zsh-autosuggestions already installed, skipping."
        return 0
    fi

    if install_apt_package zsh-autosuggestions; then
        log_ok "zsh-autosuggestions installed via apt."
        return 0
    fi

    log_warn "apt install of zsh-autosuggestions failed; falling back to a git clone."
    local target="$PLUGIN_DIR/zsh-autosuggestions"
    if [[ -d "$target" ]]; then
        log_info "zsh-autosuggestions already cloned at $target, skipping."
        return 0
    fi
    mkdir -p "$PLUGIN_DIR"
    if ! git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "$target"; then
        log_err "Failed to clone zsh-autosuggestions."
        return 1
    fi
    log_ok "zsh-autosuggestions cloned to $target."
}

install_zsh_syntax_highlighting() {
    if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
        || [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
        log_info "zsh-syntax-highlighting already installed, skipping."
        return 0
    fi

    if install_apt_package zsh-syntax-highlighting; then
        log_ok "zsh-syntax-highlighting installed via apt."
        return 0
    fi

    log_warn "apt install of zsh-syntax-highlighting failed; falling back to a git clone."
    local target="$PLUGIN_DIR/zsh-syntax-highlighting"
    if [[ -d "$target" ]]; then
        log_info "zsh-syntax-highlighting already cloned at $target, skipping."
        return 0
    fi
    mkdir -p "$PLUGIN_DIR"
    if ! git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$target"; then
        log_err "Failed to clone zsh-syntax-highlighting."
        return 1
    fi
    log_ok "zsh-syntax-highlighting cloned to $target."
}

install_fzf() {
    if command_exists fzf; then
        log_info "fzf already installed ($(fzf --version)), skipping."
        return 0
    fi

    if install_apt_package fzf; then
        log_ok "fzf installed via apt: $(fzf --version)"
        return 0
    fi

    log_warn "apt install of fzf failed; falling back to the official install script."
    local target="$HOME/.fzf"
    if [[ ! -d "$target" ]]; then
        if ! git clone --depth 1 https://github.com/junegunn/fzf.git "$target"; then
            log_err "Failed to clone fzf."
            return 1
        fi
    fi
    if ! "$target/install" --bin --no-update-rc; then
        log_err "fzf install script failed."
        return 1
    fi
    sudo install -m 755 "$target/bin/fzf" /usr/local/bin/fzf || {
        require_sudo_hint "installing fzf to /usr/local/bin"
        return 1
    }
    log_ok "fzf installed to /usr/local/bin/fzf."
}

set_login_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"
    local current_shell
    current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"

    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_info "zsh is already the login shell for $(id -un), skipping."
        return 0
    fi

    log_info "Setting zsh as the login shell for $(id -un)..."
    if chsh -s "$zsh_path" "$(id -un)" 2>/dev/null; then
        log_ok "Login shell changed to $zsh_path (takes effect on next login)."
    elif sudo chsh -s "$zsh_path" "$(id -un)"; then
        log_ok "Login shell changed to $zsh_path via sudo (takes effect on next login)."
    else
        log_warn "Could not change the login shell automatically. Run 'chsh -s $zsh_path' manually."
    fi
}

if command_exists zsh; then
    log_info "zsh already installed ($(zsh --version)), skipping install."
else
    install_apt_package zsh
    log_ok "zsh installed: $(zsh --version)"
fi

install_zsh_autosuggestions
install_zsh_syntax_highlighting
install_fzf
set_login_shell

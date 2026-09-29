#!/usr/bin/env bash
# Idempotently installs zsh plus the plugins/tools needed to mirror the
# Windows PowerShell profile's feature set (fzf Ctrl+R history search,
# ghost-text history autosuggestions) via Homebrew, and sets zsh as the
# login shell.
#
# This script only installs and enables tools - it writes no shell config.
# All config content (.zshrc, key bindings, plugin sourcing) is deployed via
# the dotfiles bare-repo checkout; see install-dotfiles.sh.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

# zsh login shells do not read /etc/profile.d/*.sh the way bash login
# shells do, which silently breaks any /etc/profile.d/ infra wiring
# (Homebrew's PATH from install-homebrew.sh, Podman's DOCKER_HOST from
# install-lazydocker.sh) once zsh becomes the login shell below. Make zsh
# source /etc/profile (which sources /etc/profile.d/*.sh) on login.
#
# Note: this must be /etc/zprofile, NOT /etc/zsh/zprofile. Debian/Ubuntu's
# apt zsh package is patched to use /etc/zsh/ as its global rc directory,
# but Homebrew's zsh is a vanilla upstream build that looks for its global
# rc files directly under /etc/ (confirmed via strace: it opens
# /etc/zprofile, not /etc/zsh/zprofile) - verify with
# `strace -f -e trace=openat zsh -l -c true` if this ever needs re-checking
# against a future zsh build.
enable_profile_d_for_zsh() {
    local marker="# Ubuntu-Setup: source /etc/profile.d/*.sh for zsh login shells"
    local zprofile="/etc/zprofile"

    if [[ -f "$zprofile" ]] && grep -qF "$marker" "$zprofile"; then
        log_info "zsh already wired to read /etc/profile.d/*.sh, skipping."
        return 0
    fi

    log_info "Wiring zsh login shells to read /etc/profile.d/*.sh..."
    # Unlike apt's zsh package, Homebrew's zsh formula doesn't create
    # /etc/zsh/ or seed it with a default zprofile, so this directory/file
    # may not exist yet - create them if needed before appending.
    if ! sudo mkdir -p "$(dirname -- "$zprofile")"; then
        require_sudo_hint "creating $(dirname -- "$zprofile")"
        return 1
    fi
    if ! { printf '\n%s\n' "$marker"
           printf "emulate sh -c 'source /etc/profile'\n"
           printf 'emulate zsh\n'
         } | sudo tee -a "$zprofile" >/dev/null
    then
        require_sudo_hint "writing $zprofile"
        return 1
    fi
    log_ok "zsh login shells now read /etc/profile.d/*.sh (via $zprofile)."
}

install_zsh_autosuggestions() {
    if brew list zsh-autosuggestions >/dev/null 2>&1; then
        log_info "zsh-autosuggestions already installed, skipping."
        return 0
    fi
    log_info "Installing zsh-autosuggestions via Homebrew..."
    if ! brew install zsh-autosuggestions; then
        log_err "brew install zsh-autosuggestions failed."
        return 1
    fi
    log_ok "zsh-autosuggestions installed."
}

install_zsh_syntax_highlighting() {
    if brew list zsh-syntax-highlighting >/dev/null 2>&1; then
        log_info "zsh-syntax-highlighting already installed, skipping."
        return 0
    fi
    log_info "Installing zsh-syntax-highlighting via Homebrew..."
    if ! brew install zsh-syntax-highlighting; then
        log_err "brew install zsh-syntax-highlighting failed."
        return 1
    fi
    log_ok "zsh-syntax-highlighting installed."
}

install_fzf() {
    if command_exists fzf; then
        log_info "fzf already installed ($(fzf --version)), skipping."
        return 0
    fi
    log_info "Installing fzf via Homebrew..."
    if ! brew install fzf; then
        log_err "brew install fzf failed."
        return 1
    fi
    log_ok "fzf installed: $(fzf --version)"
}

# `chsh` refuses any shell path not listed in /etc/shells. apt-installed
# zsh's postinst adds /usr/bin/zsh automatically; a brew-installed zsh
# under /home/linuxbrew/.linuxbrew/bin isn't added by anything, so chsh
# would otherwise fail silently-ish ("not listed in /etc/shells").
register_shell_path() {
    local zsh_path="$1"
    if grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
        return 0
    fi
    log_info "Adding $zsh_path to /etc/shells..."
    if ! echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null; then
        require_sudo_hint "adding $zsh_path to /etc/shells"
        return 1
    fi
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

    register_shell_path "$zsh_path"

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
    log_info "Installing zsh via Homebrew..."
    if ! brew install zsh; then
        log_err "brew install zsh failed."
        exit 1
    fi
    log_ok "zsh installed: $(zsh --version)"
fi

install_zsh_autosuggestions
install_zsh_syntax_highlighting
install_fzf
enable_profile_d_for_zsh
set_login_shell

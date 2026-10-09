#!/usr/bin/env bash
# Idempotently installs the language servers Helix uses for this repo's
# primary languages: C# (csharp-ls), TypeScript (typescript-language-server)
# and YAML (yaml-language-server). Requires install-dotnet.sh and
# install-node.sh to have already run.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if ! command_exists dotnet; then
    log_err "dotnet not found on PATH. Run install-dotnet.sh first."
    exit 1
fi
if ! command_exists npm; then
    log_err "npm not found on PATH. Run install-node.sh first."
    exit 1
fi

# csharp-ls (C#) - installed as a dotnet global tool.
export PATH="$HOME/.dotnet/tools:$PATH"
if command_exists csharp-ls; then
    log_info "csharp-ls already installed, skipping."
else
    log_info "Installing csharp-ls via dotnet tool..."
    if ! dotnet tool install --global csharp-ls; then
        log_err "dotnet tool install --global csharp-ls failed."
        exit 1
    fi
    log_ok "csharp-ls installed."
fi

# dotnet global tools are installed to ~/.dotnet/tools, which needs to be on
# PATH for Helix (or any other process) to find csharp-ls.
dotnet_tools_profile="/etc/profile.d/50-dotnet-tools-path.sh"
if [[ ! -f "$dotnet_tools_profile" ]]; then
    log_info "Writing $dotnet_tools_profile to add ~/.dotnet/tools to PATH..."
    if ! sudo tee "$dotnet_tools_profile" >/dev/null <<'EOF'
# Adds dotnet global tools (e.g. csharp-ls) to PATH for all users.
# Managed by Ubuntu-Setup/scripts/install-language-servers.sh.
export PATH="$HOME/.dotnet/tools:$PATH"
EOF
    then
        require_sudo_hint "writing $dotnet_tools_profile"
        exit 1
    fi
    sudo chmod 644 "$dotnet_tools_profile"
fi
export PATH="$HOME/.dotnet/tools:$PATH"

# /etc/profile.d is not read by zsh or non-login processes (editors, agents),
# so also expose csharp-ls via ~/.local/bin, which the dotfiles put on PATH.
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.dotnet/tools/csharp-ls" "$HOME/.local/bin/csharp-ls"

# typescript-language-server + typescript (TypeScript/JavaScript).
if command_exists typescript-language-server; then
    log_info "typescript-language-server already installed, skipping."
else
    log_info "Installing typescript-language-server via npm..."
    if ! npm install -g typescript-language-server typescript; then
        log_err "npm install -g typescript-language-server typescript failed."
        exit 1
    fi
    log_ok "typescript-language-server installed."
fi

# yaml-language-server (YAML).
if command_exists yaml-language-server; then
    log_info "yaml-language-server already installed, skipping."
else
    log_info "Installing yaml-language-server via npm..."
    if ! npm install -g yaml-language-server; then
        log_err "npm install -g yaml-language-server failed."
        exit 1
    fi
    log_ok "yaml-language-server installed."
fi

log_ok "Language servers installed: csharp-ls, typescript-language-server, yaml-language-server."

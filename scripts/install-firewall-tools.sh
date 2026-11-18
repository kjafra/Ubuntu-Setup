#!/usr/bin/env bash
# Idempotently installs nftables and iptables via apt. Podman's netavark
# network backend shells out to `nft` (or `iptables`, depending on
# firewall_driver in containers.conf) and fails with "unable to execute
# nft" when neither is present in the WSL distro. These are root-level
# system tools, so they stay on apt rather than Homebrew. The driver choice
# itself lives in the dotfiles repo (.config/containers/containers.conf).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

missing=()
command_exists nft || missing+=("nftables")
command_exists iptables || missing+=("iptables")

if [[ ${#missing[@]} -eq 0 ]]; then
    log_info "nftables and iptables already installed, skipping."
    exit 0
fi

log_info "Installing ${missing[*]} via apt..."
apt_update_once
if ! sudo apt-get install -y "${missing[@]}"; then
    require_sudo_hint "apt-get install ${missing[*]}"
    exit 1
fi
log_ok "Installed ${missing[*]}."

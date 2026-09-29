#!/usr/bin/env bash
# Idempotently installs git-delta (the `delta` binary), used as
# core.pager in the dotfiles-provided .gitconfig. Prefers apt (available
# as the `git-delta` package on Ubuntu 24.04+/Debian 12+); falls back to
# downloading a prebuilt release binary from GitHub for older releases.
#
# This script only installs the binary - the .gitconfig that points
# core.pager at delta comes from the dotfiles bare-repo checkout, not
# from this script.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists delta; then
    log_info "delta already installed ($(delta --version)), skipping install."
    exit 0
fi

apt_update_once

log_info "Attempting to install git-delta via apt..."
if sudo apt-get install -y git-delta 2>/dev/null && command_exists delta; then
    log_ok "delta installed via apt: $(delta --version)"
    exit 0
fi

log_warn "git-delta is not available via apt on this release; falling back to a downloaded release binary."

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) TARGET="aarch64-unknown-linux-gnu" ;;
    *)
        log_err "Unsupported architecture for the prebuilt delta binary: $ARCH"
        exit 1
        ;;
esac

log_info "Looking up latest git-delta release..."
LATEST_VERSION="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"([0-9.]+)".*/\1/')"
if [[ -z "$LATEST_VERSION" ]]; then
    log_err "Could not determine the latest git-delta release version."
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ASSET="delta-${LATEST_VERSION}-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/dandavison/delta/releases/download/${LATEST_VERSION}/${ASSET}"
log_info "Downloading delta ${LATEST_VERSION} from ${DOWNLOAD_URL}..."
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/delta.tar.gz"; then
    log_err "Failed to download delta from $DOWNLOAD_URL"
    exit 1
fi

tar -xzf "$TMP_DIR/delta.tar.gz" -C "$TMP_DIR"

BINARY_PATH="$(find "$TMP_DIR" -type f -name delta | head -n1)"
if [[ -z "$BINARY_PATH" ]]; then
    log_err "Could not find the delta binary inside the downloaded archive."
    exit 1
fi

if ! sudo install -m 755 "$BINARY_PATH" /usr/local/bin/delta; then
    require_sudo_hint "installing delta to /usr/local/bin"
    exit 1
fi

log_ok "delta installed: $(delta --version)"

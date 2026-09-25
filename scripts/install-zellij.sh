#!/usr/bin/env bash
# Idempotently installs Zellij. Prefers snap; falls back to downloading a
# prebuilt release binary from GitHub (Zellij is not in Ubuntu's apt repos).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

if command_exists zellij; then
    log_info "Zellij already installed ($(zellij --version)), skipping."
    exit 0
fi

if command_exists snap; then
    log_info "Installing zellij via snap..."
    if sudo snap install zellij --classic; then
        log_ok "Zellij installed via snap: $(zellij --version)"
        exit 0
    fi
    log_warn "snap install zellij failed; falling back to a downloaded release binary."
fi

log_info "Downloading latest zellij release binary from GitHub..."
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) TARGET="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) TARGET="aarch64-unknown-linux-musl" ;;
    *)
        log_err "Unsupported architecture for the prebuilt zellij binary: $ARCH"
        exit 1
        ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DOWNLOAD_URL="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${TARGET}.tar.gz"
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/zellij.tar.gz"; then
    log_err "Failed to download zellij from $DOWNLOAD_URL"
    exit 1
fi

tar -xzf "$TMP_DIR/zellij.tar.gz" -C "$TMP_DIR"

if ! sudo install -m 755 "$TMP_DIR/zellij" /usr/local/bin/zellij; then
    require_sudo_hint "installing zellij to /usr/local/bin"
    exit 1
fi

log_ok "Zellij installed: $(zellij --version)"

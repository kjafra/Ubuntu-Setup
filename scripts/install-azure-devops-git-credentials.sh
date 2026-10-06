#!/usr/bin/env bash
# Idempotently configures a git credential helper for Azure DevOps
# (dev.azure.com) using Git Credential Manager (GCM,
# github.com/git-ecosystem/git-credential-manager), scoped ONLY to
# dev.azure.com -- GitHub and any other git host keep whatever credential
# helper (if any) they already use, untouched.
#
# This script is environment-aware and never assumes Windows is present,
# so the exact same script works unmodified on bare WSL today and on a
# future pure-Linux machine (e.g. a Fedora Silverblue distrobox) with no
# Windows at all:
#
#   - On WSL: does NOT install anything on the Linux side. Instead it
#     points dev.azure.com's git credential helper at the WINDOWS-side
#     git-credential-manager.exe (shipped with Git for Windows, or a
#     standalone GCM-for-Windows install), reachable via the /mnt/c
#     mount and WSL/Windows interop. Git in WSL then transparently shells
#     out to that Windows binary for every credential request, which
#     stores/retrieves secrets in the real Windows Credential Manager
#     (DPAPI-backed). This is Microsoft's own documented WSL setup for
#     GCM -- see https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/wsl.md
#   - On non-WSL Linux: installs the native Linux GCM binary via the
#     existing Homebrew/linuxbrew tooling (the git-credential-manager
#     cask has a genuine Linux variant -- plain binary artifact, not
#     macOS-only) and points the helper at that local binary instead.
#     GCM auto-picks its own Linux-native secure store (Secret
#     Service/libsecret if a keyring is available, otherwise its own
#     gpg-backed cache) -- deliberately not forced via
#     GCM_CREDENTIAL_STORE, so Windows Credential Manager is only ever a
#     WSL-side effect of interop, never a hard dependency of this script
#     or the repo.
#
# Requires `gh`-style secrets/PATs are NOT handled here at all -- GCM
# drives its own interactive OAuth/PAT prompt on first use of a cloned
# Azure DevOps repo, same as it would on native Windows.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

ADO_HELPER_KEY="credential.https://dev.azure.com.helper"
ADO_HTTPPATH_KEY="credential.https://dev.azure.com.useHttpPath"

is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
    grep -qi microsoft /proc/version 2>/dev/null
}

# Escapes spaces in a path the same way upstream's own WSL docs do, since
# git re-splits the credential.helper string through a shell before
# exec'ing it.
escape_path_spaces() {
    printf '%s' "${1// /\\ }"
}

configure_helper() {
    local helper_path="$1"
    local escaped
    escaped="$(escape_path_spaces "$helper_path")"

    if [[ "$(git config --global --get "$ADO_HELPER_KEY" 2>/dev/null || true)" == "$escaped" ]]; then
        log_info "Azure DevOps git credential helper already configured (${helper_path}), skipping."
        return 0
    fi

    git config --global "$ADO_HELPER_KEY" "$escaped"
    git config --global "$ADO_HTTPPATH_KEY" true
    log_ok "Azure DevOps git credential helper configured: ${helper_path}"
}

if is_wsl; then
    log_info "WSL detected -- looking for a Windows-side Git Credential Manager install..."

    # Priority order matches upstream's documented install locations.
    # The per-user installer path depends on the Windows username (which
    # isn't assumed to match the WSL username), so it's globbed.
    CANDIDATES=(
        "/mnt/c/Program Files/Git/ucrt64/bin/git-credential-manager.exe"
        "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
        "/mnt/c/Program Files/Git/clangarm64/bin/git-credential-manager.exe"
        "/mnt/c/Program Files/Git Credential Manager/git-credential-manager.exe"
        "/mnt/c/Program Files (x86)/Git Credential Manager/git-credential-manager.exe"
    )

    FOUND_PATH=""
    for candidate in "${CANDIDATES[@]}"; do
        if [[ -f "$candidate" ]]; then
            FOUND_PATH="$candidate"
            break
        fi
    done

    if [[ -z "$FOUND_PATH" ]]; then
        shopt -s nullglob
        USER_INSTALLS=(/mnt/c/Users/*/AppData/Local/Programs/"Git Credential Manager"/git-credential-manager.exe)
        shopt -u nullglob
        if [[ "${#USER_INSTALLS[@]}" -gt 0 ]]; then
            FOUND_PATH="${USER_INSTALLS[0]}"
        fi
    fi

    if [[ -z "$FOUND_PATH" ]]; then
        log_warn "Git Credential Manager not found on the Windows side."
        log_warn "Install Git for Windows (recommended, includes GCM) or standalone GCM for Windows, then re-run this script."
        exit 0
    fi

    configure_helper "$FOUND_PATH"
else
    log_info "Non-WSL Linux detected -- using a native Linux Git Credential Manager install."

    if ! command_exists git-credential-manager; then
        log_info "Installing Git Credential Manager via Homebrew..."
        if ! brew install --cask git-credential-manager; then
            log_err "brew install --cask git-credential-manager failed."
            exit 1
        fi
    fi

    if ! command_exists git-credential-manager; then
        log_err "git-credential-manager still not on PATH after install, giving up."
        exit 1
    fi

    configure_helper "$(command -v git-credential-manager)"
fi

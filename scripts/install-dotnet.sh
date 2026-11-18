#!/usr/bin/env bash
# Idempotently installs the .NET 10 (LTS) SDK via Homebrew's versioned
# `dotnet@10` formula, so `brew upgrade` only ever gets 10.x patches (the
# unversioned `dotnet` formula tracks the latest major, e.g. 11). The formula
# is keg-only, so it is force-linked onto PATH. Also points DOTNET_ROOT at
# Homebrew's install so other tools (e.g. editors, MSBuild-based tooling) can
# find it without a login shell re-source.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

# Migrate off the unversioned formula, which upgrades to newer majors.
if brew list --versions dotnet &>/dev/null; then
    log_info "Removing unversioned 'dotnet' formula (tracks latest major)..."
    brew uninstall dotnet || { log_err "brew uninstall dotnet failed."; exit 1; }
fi

if brew list --versions dotnet@10 &>/dev/null; then
    log_info ".NET 10 SDK already installed via Homebrew, ensuring it is linked."
else
    log_info "Installing .NET 10 SDK via Homebrew (dotnet@10)..."
    brew install dotnet@10 || { log_err "brew install dotnet@10 failed."; exit 1; }
fi
brew link --force --overwrite dotnet@10 >/dev/null

profile_snippet="/etc/profile.d/50-dotnet-root.sh"
log_info "Writing $profile_snippet to set DOTNET_ROOT..."
if ! sudo tee "$profile_snippet" >/dev/null <<'EOF'
# Points DOTNET_ROOT at Homebrew's dotnet install, as recommended by the
# formula itself. Managed by Ubuntu-Setup/scripts/install-dotnet.sh.
export DOTNET_ROOT="$(brew --prefix dotnet@10 2>/dev/null)/libexec"
EOF
then
    require_sudo_hint "writing $profile_snippet"
    exit 1
fi
sudo chmod 644 "$profile_snippet"

export DOTNET_ROOT="$(brew --prefix dotnet@10)/libexec"

log_ok ".NET SDK installed: $(dotnet --list-sdks | tr '\n' ' ')"

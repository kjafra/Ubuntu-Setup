#!/usr/bin/env bash
# Idempotently installs the .NET 10 SDK via Homebrew (the `dotnet` formula
# is aka'd `dotnet@10` upstream, i.e. it tracks the .NET 10 channel), and
# points DOTNET_ROOT at Homebrew's install so other tools (e.g. editors,
# MSBuild-based tooling) can find it without a login shell re-source.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path

if command_exists dotnet && dotnet --list-sdks 2>/dev/null | grep -q '^10\.'; then
    log_info ".NET 10 SDK already installed ($(dotnet --list-sdks | grep '^10\.' | tr '\n' ' ')), skipping."
    exit 0
fi

log_info "Installing .NET 10 SDK via Homebrew..."
if ! brew install dotnet; then
    log_err "brew install dotnet failed."
    exit 1
fi

profile_snippet="/etc/profile.d/50-dotnet-root.sh"
log_info "Writing $profile_snippet to set DOTNET_ROOT..."
if ! sudo tee "$profile_snippet" >/dev/null <<'EOF'
# Points DOTNET_ROOT at Homebrew's dotnet install, as recommended by the
# formula itself. Managed by Ubuntu-Setup/scripts/install-dotnet.sh.
export DOTNET_ROOT="$(brew --prefix dotnet 2>/dev/null)/libexec"
EOF
then
    require_sudo_hint "writing $profile_snippet"
    exit 1
fi
sudo chmod 644 "$profile_snippet"

export DOTNET_ROOT="$(brew --prefix dotnet)/libexec"

log_ok ".NET SDK installed: $(dotnet --list-sdks | tr '\n' ' ')"

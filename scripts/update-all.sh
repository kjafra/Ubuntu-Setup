#!/usr/bin/env bash
# Updates everything this repo installs: apt packages, Homebrew formulae/casks,
# the csharp-ls dotnet global tool, and the Azure Artifacts Credential
# Provider (which has no package-manager distribution). A failing section is
# reported at the end but doesn't stop the remaining ones.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"
ensure_brew_on_path
export PATH="$HOME/.dotnet/tools:$PATH"

failed=()

run_section() {
    local name="$1"
    shift
    log_info "==> Updating ${name}"
    if ! "$@"; then
        log_err "${name} update failed."
        failed+=("$name")
    fi
}

update_brew() {
    command_exists brew || { log_warn "brew not found, skipping."; return 0; }
    brew update && brew upgrade --greedy && brew cleanup
}

update_dotnet_tools() {
    command_exists dotnet || { log_warn "dotnet not found, skipping."; return 0; }
    command_exists csharp-ls || { log_warn "csharp-ls not installed, skipping."; return 0; }
    dotnet tool update --global csharp-ls
}

update_nuget_credprovider() {
    local plugin="$HOME/.nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll"
    [[ -f "$plugin" ]] || { log_warn "Credential provider not installed, skipping."; return 0; }
    command_exists dotnet || { log_warn "dotnet not found, skipping."; return 0; }
    # -f makes curl fail on HTTP errors instead of piping an error page to bash.
    curl -fsSL "https://aka.ms/install-artifacts-credprovider.sh" | bash
}

run_section "apt packages" "$SCRIPT_DIR/update-base-packages.sh"
run_section "Homebrew packages" update_brew
run_section "dotnet tools" update_dotnet_tools
run_section "Azure Artifacts Credential Provider" update_nuget_credprovider

if [[ "${#failed[@]}" -gt 0 ]]; then
    log_err "Update finished with failures: ${failed[*]}"
    exit 1
fi
log_ok "Everything is up to date."

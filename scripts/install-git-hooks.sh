#!/usr/bin/env bash
# Idempotently points git's global core.hooksPath at the commit-msg hook
# deployed by the dotfiles repo ($HOME/.git-hooks/commit-msg), which
# rejects any commit crediting Copilot (or another AI assistant) as a
# co-author. Applying this globally (rather than per-repo) means the
# safeguard also covers repos cloned fresh in the future, not just the
# ones provisioned by this setup.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

HOOKS_DIR="$HOME/.git-hooks"
HOOK_FILE="$HOOKS_DIR/commit-msg"

if [[ ! -f "$HOOK_FILE" ]]; then
    log_err "$HOOK_FILE not found (expected to be deployed by install-dotfiles.sh)."
    log_err "Run install-dotfiles.sh first, then re-run this script."
    exit 1
fi

chmod +x "$HOOK_FILE"

current_hooks_path="$(git config --global --get core.hooksPath || true)"
if [[ "$current_hooks_path" == "$HOOKS_DIR" ]]; then
    log_info "git core.hooksPath already set to $HOOKS_DIR, skipping."
else
    git config --global core.hooksPath "$HOOKS_DIR"
    log_ok "git core.hooksPath set to $HOOKS_DIR."
fi

log_ok "Copilot co-author commit-msg hook active globally for $(whoami)."

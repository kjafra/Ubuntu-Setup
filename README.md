# Ubuntu-Setup

In-distro provisioning for Ubuntu under WSL2 (the default distro used by
[WSL-Setup](https://github.com/falwickster/WSL-Setup)). This repository is
deliberately scoped to **Linux-side setup only** — everything on the
Windows side (registering the WSL2 distro itself, installing WezTerm) is
handled by WSL-Setup, which pulls this repository in as a git submodule.

Same design pattern as WSL-Setup, just in shell instead of PowerShell:

- One script per tool, each independently idempotent (checks whether its
  target is already installed and skips reinstalling it if so).
- A `bootstrap.sh` orchestrator that runs all of them in order.
- No step assumes it's running as root; each uses `sudo` only for the
  specific command that needs it, and prints a clear hint if that fails
  for permissions reasons.

## What gets installed

- Base `apt` package list/upgrade (`update-base-packages.sh`)
- `git` (`install-git.sh`)
- GitHub CLI (`gh`) + the GitHub Copilot CLI extension (`gh copilot`)
  (`install-github-cli.sh`)
- [Helix](https://helix-editor.com/) editor (`install-helix.sh`) — via
  `apt` where available, falling back to `snap`
- [Zellij](https://zellij.dev/) (`install-zellij.sh`) — via `snap` where
  available, falling back to a downloaded release binary

## Usage

Run everything in one go:

```bash
./install.sh
```

Or run steps individually:

```bash
./scripts/update-base-packages.sh
./scripts/install-git.sh
./scripts/install-github-cli.sh
./scripts/install-helix.sh
./scripts/install-zellij.sh
```

Re-running any script (or `install.sh` as a whole) is safe — already
installed tools are detected and skipped.

## Repository layout

```
install.sh                     # Entry point, delegates to scripts/bootstrap.sh
scripts/
  bootstrap.sh                 # Runs every install script in order
  common.sh                    # Shared helpers (logging, command/package checks, sudo hints)
  update-base-packages.sh      # apt-get update && apt-get upgrade
  install-git.sh
  install-github-cli.sh        # gh + gh copilot extension
  install-helix.sh
  install-zellij.sh
```

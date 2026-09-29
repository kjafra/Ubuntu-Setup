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
- [Podman](https://podman.io/) (`install-podman.sh`) — via `apt`
- [git-delta](https://github.com/dandavison/delta) (`install-delta.sh`) — via
  `apt` where available (Ubuntu 24.04+/Debian 12+), falling back to a
  downloaded release binary. Used as `core.pager` in the dotfiles-provided
  `.gitconfig` for syntax-highlighted diffs in `git diff`/`git log`/lazygit.
- [lazygit](https://github.com/jesseduffield/lazygit) (`install-lazygit.sh`)
  — via `apt` where available (Ubuntu 25.10+/Debian 13+), falling back to
  `go install`. This script only installs the binary; its default editor
  (Helix) is configured via the dotfiles-deployed config, not by this
  script.
- [lazydocker](https://github.com/jesseduffield/lazydocker) (`install-lazydocker.sh`)
  — not packaged for apt/snap and its `go install` path is currently broken
  upstream, so it's installed via its own officially documented Linux
  release-binary download (same pattern as Zellij); enables the rootless
  `podman.socket` user service and points `DOCKER_HOST` at it (via a static
  `/etc/profile.d/` file) so lazydocker talks to Podman's
  Docker-API-compatible endpoint
- `zsh` + [fzf](https://github.com/junegunn/fzf) +
  [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) +
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
  (`install-zsh.sh`) — via `apt` where available, falling back to a git
  clone of the upstream plugin repos or fzf's official install script; also
  sets `zsh` as the login shell. Tools only — no shell config is written by
  this script.
- The [dotfiles](https://github.com/falwickster/dotfiles) bare-repo
  checkout (`install-dotfiles.sh`) — deploys `.zshrc`,
  `.config/lazygit/config.yml`, `.config/helix/config.toml`, and anything
  else in that repo into `$HOME`, mirroring the same experience as the
  Windows PowerShell profile: fzf-powered `Ctrl+R` history search,
  ghost-text history autosuggestions, Helix as the default editor for
  lazygit/git, and a locked-down `dotfiles` shell function
  (`pull`/`fetch`/`merge`/`status`/`log`/`diff` only) for syncing future
  updates

This repo intentionally keeps a strict split: install scripts here only
install/enable *tools*; all actual config content lives in the
[dotfiles](https://github.com/falwickster/dotfiles) repo, checked out as a
git submodule at `dotfiles/` in this repository purely so an AI agent (or
you) can author/commit/push new Linux-path config files without touching a
live `$HOME` checkout. Deployment at runtime always goes through
`install-dotfiles.sh`'s bare-repo checkout, not this submodule.

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
./scripts/install-podman.sh
./scripts/install-delta.sh
./scripts/install-lazygit.sh
./scripts/install-lazydocker.sh
./scripts/install-zsh.sh
./scripts/install-dotfiles.sh
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
  install-podman.sh
  install-delta.sh              # git-delta (core.pager, config comes from the dotfiles checkout)
  install-lazygit.sh           # lazygit (config comes from the dotfiles checkout)
  install-lazydocker.sh        # lazydocker + rootless podman.socket wiring
  install-zsh.sh              # zsh + fzf + zsh-autosuggestions + zsh-syntax-highlighting, login shell
  install-dotfiles.sh          # bare-repo checkout of github.com/falwickster/dotfiles into $HOME
dotfiles/                      # git submodule: github.com/falwickster/dotfiles (authoring copy, see above)
```

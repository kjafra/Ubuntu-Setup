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

Everything installs through **one** consistent package manager —
[Homebrew](https://brew.sh/) (Linuxbrew) — except for the small handful of
things `apt` is strictly required for: Homebrew's own Linux bootstrap
dependencies, `git` (needed before Homebrew can even be installed), and
rootless Podman's `newuidmap`/`newgidmap` binaries (setuid-root, so they
have to come from the OS, not Homebrew). No tool install script falls back
to `snap`, `go install`, or a downloaded release binary anymore — every
tool in scope has an official Linux bottle on Homebrew.

**apt (essentials only):**

- Base package list/upgrade (`update-base-packages.sh`)
- `git` (`install-git.sh`)
- `build-essential procps curl file` — Homebrew's own Linux build
  dependencies (`install-homebrew.sh`)
- `uidmap` — provides `newuidmap`/`newgidmap`, required for rootless
  Podman; a setuid-root package that can't come from Homebrew
  (`install-podman.sh`)

**Homebrew (everything else):**

- Homebrew itself (`install-homebrew.sh`) — installs to
  `/home/linuxbrew/.linuxbrew` and writes a static `/etc/profile.d/` file
  so every future login shell has `brew` on `PATH`
- GitHub CLI (`gh`) + the GitHub Copilot CLI extension (`gh copilot`)
  (`install-github-cli.sh`)
- [Helix](https://helix-editor.com/) editor (`install-helix.sh`)
- [tmux](https://github.com/tmux/tmux) (`install-tmux.sh`) — this script
  only installs the binary; visuals/behavior (translucent Omarchy-inspired
  theme, default emacs-style keybindings, no plugins) come from the
  dotfiles-provided `.config/tmux/tmux.conf`, and `.zshrc` auto-starts a
  new tmux session on every interactive login shell
- [Podman](https://podman.io/) (`install-podman.sh`)
- [git-delta](https://github.com/dandavison/delta) (`install-delta.sh`) —
  used as `core.pager` in the dotfiles-provided `.gitconfig` for
  syntax-highlighted diffs in `git diff`/`git log`/lazygit
- [lazygit](https://github.com/jesseduffield/lazygit) (`install-lazygit.sh`)
  — this script only installs the binary; its default editor (Helix) is
  configured via the dotfiles-deployed config, not by this script
- [lazydocker](https://github.com/jesseduffield/lazydocker)
  (`install-lazydocker.sh`) — also starts Podman's Docker-API-compatible
  service via `brew services start podman` (a Homebrew-managed systemd
  **user** service, since Homebrew's podman formula doesn't ship apt's
  socket-activation unit) and points `DOCKER_HOST` at its rootless socket
  (via a static `/etc/profile.d/` file) so lazydocker can talk to it
- [Yazi](https://yazi-rs.github.io/) (`install-yazi.sh`) — this script
  only installs the binary; the `y` cd-on-quit shell wrapper function
  comes from the dotfiles-provided `.zshrc`
- [eza](https://eza.rocks/) (`install-eza.sh`) — a prettier `ls`
  replacement; this script only installs the binary, the `ls`/`ll`/`la`/`lt`
  aliases (with icons and git-status columns) come from the
  dotfiles-provided `.zshrc`
- [fastfetch](https://github.com/fastfetch-cli/fastfetch)
  (`install-fastfetch.sh`) — this script only installs the binary; the
  dotfiles-provided `.zshrc` runs it once per actual login shell (not on
  every tmux pane) to print the distro ASCII logo + machine info (OS,
  kernel, CPU, memory, disks, uptime, shell, etc.), immediately followed
  by a live-checked list of any manual setup steps still outstanding (see
  below) — printed before tmux auto-starts, since `exec tmux` replaces
  the shell process and nothing after it would run
- `zsh` + [fzf](https://github.com/junegunn/fzf) +
  [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) +
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
  (`install-zsh.sh`) — also sets `zsh` as the login shell, registers its
  path in `/etc/shells` (Homebrew's zsh isn't auto-registered the way
  apt's is), and patches `/etc/zprofile` so zsh login shells actually read
  `/etc/profile.d/*.sh` (Homebrew's vanilla zsh build doesn't source
  `/etc/profile` on login the way Debian's patched apt zsh package does —
  without this fix, Homebrew's own `PATH` wiring and Podman's `DOCKER_HOST`
  wiring above would silently never take effect in a zsh login shell).
  Tools only — no shell config is written by this script.
- The [dotfiles](https://github.com/falwickster/dotfiles) bare-repo
  checkout (`install-dotfiles.sh`) — deploys `.zshrc`,
  `.config/lazygit/config.yml`, `.config/helix/config.toml`,
  `.config/tmux/tmux.conf`, and anything else in that repo into `$HOME`,
  mirroring the same experience as the Windows PowerShell profile:
  fzf-powered `Ctrl+R` history search, ghost-text history autosuggestions,
  Helix as the default editor for lazygit/git, a translucent
  Omarchy-inspired tmux status bar/pane theme with tmux's stock
  keybindings (auto-started as a new session on every interactive login
  shell), `eza`-powered `ls`/`ll`/`la`/`lt` aliases with icons and
  git-status columns, a `y` shell function that opens Yazi and `cd`s to
  its last directory on quit, and a locked-down `dotfiles` shell function
  (`pull`/`fetch`/`merge`/`status`/`log`/`diff` only) for syncing future
  updates
- [copilot_here](https://github.com/GordonBeeming/copilot_here)
  (`install-copilot-here.sh`) — runs the GitHub Copilot CLI inside a
  sandboxed container (Docker/OrbStack/Podman, auto-detected; our
  rootless Podman install above is natively supported) with filesystem
  access limited to the current directory, using the host's existing
  `gh` credentials. This script only installs the `copilot_here` binary
  and its shell-function wrappers (`copilot_here`/`copilot_yolo`) via
  upstream's own official installer; the shell-integration marker block
  it would otherwise inject at runtime is pre-seeded as tracked content
  in the dotfiles-provided `.zshrc` instead, so it's always a no-op
  rewrite. Runs last, after `install-dotfiles.sh`, so that tracked
  `.zshrc` already exists before the installer touches it. Before first
  use, `gh` must be authenticated with the `copilot` and `read:packages`
  scopes (`gh auth refresh -h github.com -s copilot,read:packages`) —
  not run automatically by this script.

This repo intentionally keeps a strict split: install scripts here only
install/enable *tools*; all actual config content lives in the
[dotfiles](https://github.com/falwickster/dotfiles) repo, checked out as a
git submodule at `dotfiles/` in this repository purely so an AI agent (or
you) can author/commit/push new Linux-path config files without touching a
live `$HOME` checkout. Deployment at runtime always goes through
`install-dotfiles.sh`'s bare-repo checkout, not this submodule.

## Login banner & manual-setup reminders

Every interactive login shell (once per terminal, not per tmux pane)
prints the `fastfetch` ASCII logo/machine-info banner, followed by a
reminder for any of these one-time, interactive steps that nothing here
can safely automate (credentials, network, or a TTY prompt are needed) and
that haven't been done yet:

- **GitHub CLI** not authenticated, or authenticated without the
  `copilot`/`read:packages` scopes `copilot_here` needs
- **Azure CLI** not authenticated (only checked if `az` is installed —
  this repo doesn't install it)
- **Podman's API service** not running (`brew services start podman`)
- **Git identity** not set (`~/.gitconfig.local` missing — see
  `.gitconfig.local.example`)

Each check is live (re-evaluated every login, no "dismiss once" flag
file), so a reminder disappears for good the moment its underlying
condition is fixed, and network checks are capped with a short `timeout`
so being offline never hangs shell startup. The checks themselves live in
the dotfiles-provided `.zshrc`, not in a script here.

## Usage

Run everything in one go:

```bash
./install.sh
```

Or run steps individually:

```bash
./scripts/update-base-packages.sh
./scripts/install-git.sh
./scripts/install-homebrew.sh
./scripts/install-github-cli.sh
./scripts/install-helix.sh
./scripts/install-tmux.sh
./scripts/install-podman.sh
./scripts/install-delta.sh
./scripts/install-lazygit.sh
./scripts/install-lazydocker.sh
./scripts/install-yazi.sh
./scripts/install-eza.sh
./scripts/install-fastfetch.sh
./scripts/install-zsh.sh
./scripts/install-dotfiles.sh
./scripts/install-copilot-here.sh
```

If you run steps individually rather than via `bootstrap.sh`/`install.sh`,
run `install-homebrew.sh` first and then `eval "$(brew shellenv)"` (or open
a new shell) before running the rest — otherwise later steps in the *same*
shell won't see `brew` on `PATH` yet (`bootstrap.sh` handles this
automatically).

Re-running any script (or `install.sh` as a whole) is safe — already
installed tools are detected and skipped.

## Repository layout

```
install.sh                     # Entry point, delegates to scripts/bootstrap.sh
scripts/
  bootstrap.sh                 # Runs every install script in order
  common.sh                    # Shared helpers (logging, command/package checks, sudo hints, brew PATH)
  update-base-packages.sh      # apt-get update && apt-get upgrade
  install-git.sh
  install-homebrew.sh          # Homebrew (Linuxbrew) itself + its apt build deps + PATH wiring
  install-github-cli.sh        # gh + gh copilot extension (brew)
  install-helix.sh             # brew
  install-tmux.sh              # brew (config comes from the dotfiles checkout)
  install-podman.sh            # brew + apt uidmap (rootless UID/GID mapping)
  install-delta.sh             # git-delta (brew; config comes from the dotfiles checkout)
  install-lazygit.sh           # lazygit (brew; config comes from the dotfiles checkout)
  install-lazydocker.sh        # lazydocker (brew) + brew-services-managed rootless podman API service
  install-yazi.sh               # yazi (brew; `y` cd-on-quit wrapper comes from the dotfiles checkout)
  install-eza.sh                 # eza (brew; ls/ll/la/lt aliases come from the dotfiles checkout)
  install-fastfetch.sh          # fastfetch (brew; login banner + manual-setup reminders come from the dotfiles checkout)
  install-zsh.sh                # zsh + fzf + zsh-autosuggestions + zsh-syntax-highlighting (brew), login shell, /etc/zprofile fix
  install-dotfiles.sh          # bare-repo checkout of github.com/falwickster/dotfiles into $HOME
  install-copilot-here.sh      # copilot_here (brew-free; upstream's own installer) - sandboxed Copilot CLI wrapper, runs last
dotfiles/                      # git submodule: github.com/falwickster/dotfiles (authoring copy, see above)
```

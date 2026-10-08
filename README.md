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
  dotfiles-provided `.config/tmux/tmux.conf`. Run it manually with `tmux`
  whenever you want it — it's not auto-started on login, and session
  handling (detach, re-attach, kill) is tmux's own default behavior
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
- [fd](https://github.com/sharkdp/fd) (`install-fd.sh`) — fast file finder;
  the dotfiles `.zshrc` uses it as fzf's file source, so `Ctrl+T` fuzzy-picks
  files and `Alt+C` fuzzy-`cd`s (both `.gitignore`-aware). Also usable
  directly: `fd <pattern>`
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
  keybindings, `eza`-powered `ls`/`ll`/`la`/`lt` aliases with icons and
  git-status columns, a `y` shell function that opens Yazi and `cd`s to
  its last directory on quit, and a locked-down `dotfiles` shell function
  (`pull`/`fetch`/`merge`/`status`/`log`/`diff` only) for syncing future
  updates
- A global git `commit-msg` hook (`install-git-hooks.sh`) that rejects any
  commit crediting Copilot (or another AI assistant) as a co-author (see
  [Preventing AI co-author trailers](#preventing-ai-co-author-trailers)
  below). Runs after `install-dotfiles.sh`, since it points at the hook
  script the dotfiles checkout deploys to `$HOME/.git-hooks/commit-msg`.
- [Node.js](https://nodejs.org/) (`install-node.sh`) — only used for the
  `npx`-launched MCP servers below; no app code or shell config depends
  on it.
- [.NET 10 SDK](https://dotnet.microsoft.com/) (`install-dotnet.sh`) — the
  Homebrew `dotnet` formula is aka'd `dotnet@10` upstream (tracks the .NET
  10 channel); also writes `DOTNET_ROOT` via a static `/etc/profile.d/`
  file, same pattern as Podman's `DOCKER_HOST` above.
- [Azure CLI](https://learn.microsoft.com/cli/azure/) (`install-azure-cli.sh`)
  — this script only installs the `az` binary, it does **not** run
  `az login` (interactive/credentialed — left to the login-banner
  reminder below, same as the GitHub CLI's).
- The standalone [GitHub Copilot CLI](https://github.com/github/copilot-cli)
  (`install-copilot-cli.sh`, the `copilot` command) — unlike the `gh
  copilot` built-in (`install-github-cli.sh`), this is the full agentic
  CLI with MCP server support (`/mcp`, `copilot mcp add`). No Linux
  Homebrew cask exists for it, so this installs it via GitHub's own
  official install script into `$HOME/.local/bin`. Runs after
  `install-git-hooks.sh`. Requires `gh`/Copilot authentication (via the
  in-app `/login` flow) before first use — not run automatically by this
  script.
- The [Azure DevOps MCP server](https://github.com/microsoft/azure-devops-mcp)
  (`install-azure-devops-mcp.sh`) — registers Microsoft's official
  `@azure-devops/mcp` server with the Copilot CLI above. **Supports
  multiple orgs simultaneously**: every organization listed in
  `~/.azure-devops.local` gets its own MCP server, named
  `azure-devops-<org>` (e.g. `copilot mcp add azure-devops-contoso -- npx
  -y @azure-devops/mcp contoso --authentication azcli`), so Copilot can
  query/manage work items, repos, pipelines, and wikis across all of your
  orgs at once — no switching required. Authenticates by reusing the
  host's existing `az login` session — no PAT or other secret is ever
  generated or written to disk. Runs last, after `install-node.sh` and
  `install-copilot-cli.sh`. Org names are personal/machine-specific, so
  they're **not** tracked in the dotfiles repo: copy
  `dotfiles/.azure-devops.local.example` to `~/.azure-devops.local` and
  list one org per line (if that file is missing or only has placeholder
  org names, the script logs instructions and skips cleanly instead of
  failing). Re-run the script after adding a new org — it only registers
  orgs not already registered, so existing ones are left untouched.
- **Azure DevOps git credentials** (`install-azure-devops-git-credentials.sh`)
  — configures a git credential helper scoped *only* to `dev.azure.com`
  (`credential.https://dev.azure.com.helper`), using
  [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager)
  (GCM), so `git clone`/`fetch`/`push` against Azure DevOps repos over
  HTTPS authenticate without manually pasting a PAT every time. GitHub and
  any other git host are untouched. This script is environment-aware and
  never assumes Windows — the exact same script runs unmodified whether
  or not Windows is present:
  - **On WSL**: nothing is installed on the Linux side. Instead the
    helper is pointed straight at the **Windows-side**
    `git-credential-manager.exe` (shipped with Git for Windows, or a
    standalone GCM-for-Windows install), found under `/mnt/c/...`. Git in
    WSL transparently shells out to that Windows binary via WSL/Windows
    interop for every credential request, so secrets are stored in the
    real **Windows Credential Manager** (DPAPI-backed) — this is
    Microsoft's own documented WSL setup for GCM. If neither Git for
    Windows nor standalone GCM is found yet, the script logs instructions
    and skips cleanly; the login banner nags until it's resolved (see
    below).
  - **On non-WSL Linux** (e.g. a future Fedora Silverblue distrobox, no
    Windows at all): installs the native Linux GCM binary via the
    existing Homebrew/linuxbrew tooling (`brew install --cask
    git-credential-manager` — the cask has a genuine Linux variant) and
    points the helper at that local binary instead. GCM auto-picks its
    own Linux-native secure store (Secret Service/libsecret, or its own
    gpg-backed cache) — nothing is forced, and Windows Credential Manager
    is never a hard dependency of this script or the repo.

  Runs last, after `install-azure-devops-mcp.sh`. Idempotent: skips if the
  helper is already configured to the detected path.
- **Azure Artifacts NuGet credential provider**
  (`install-nuget-credential-provider.sh`) — installs Microsoft's
  [Artifacts Credential Provider](https://github.com/microsoft/artifacts-credprovider)
  into `~/.nuget/plugins/netcore` (plus `jq`) so `dotnet restore` can
  authenticate to private Azure DevOps NuGet feeds. The dotfiles
  `.zshrc` exports `VSS_NUGET_EXTERNAL_FEED_ENDPOINTS` in each
  interactive shell, with the PAT read from the `azure-devops-pat` Podman
  secret (below) and one `https://pkgs.dev.azure.com/<org>/` endpoint per
  org in `~/.azure-devops.local` (username `VssSessionToken`). The PAT
  needs the *Packaging → Read* scope. Nothing is written to disk. Runs
  last, after `install-azure-devops-git-credentials.sh`.
- **Azure DevOps PAT storage for future custom containers** — the
  host-side registration above uses `--authentication azcli`, which only
  works on the host (no `az` binary / `~/.azure` token cache inside a
  container). For sandboxed/containerized use later (e.g. a custom Docker
  image), store an Azure DevOps PAT as the Podman secret
  `azure-devops-pat`: `podman secret create azure-devops-pat -` (paste the
  PAT, then Ctrl-D; re-run to rotate). The PAT itself is expected to live
  in your own password manager (e.g. KeePass on Windows) and is never
  written to disk or shell history by this flow — only piped straight
  into `podman secret create`. The login banner reminds you if this
  secret isn't set yet (see below). There's no automation script for this
  on purpose, and no specific encoding/consumer is assumed — that's
  whatever the eventual custom image expects.

This repo intentionally keeps a strict split: install scripts here only
install/enable *tools*; all actual config content lives in the
[dotfiles](https://github.com/falwickster/dotfiles) repo, checked out as a
git submodule at `dotfiles/` in this repository purely so an AI agent (or
you) can author/commit/push new Linux-path config files without touching a
live `$HOME` checkout. Deployment at runtime always goes through
`install-dotfiles.sh`'s bare-repo checkout, not this submodule.

## Login banner & manual-setup reminders

Every interactive login shell prints a reminder for any of these one-time,
interactive steps that nothing here can safely automate (credentials,
network, or a TTY prompt are needed) and that haven't been done yet:

- **GitHub CLI** not authenticated
- **Azure CLI** not authenticated (only checked if `az` is installed)
- **Podman's API service** not running (`brew services start podman`;
  if no systemd user session exists yet, the reminder instead walks
  through enabling lingering and restarting WSL — see
  [Podman's systemd user session on WSL](#podmans-systemd-user-session-on-wsl))
- **Azure DevOps PAT not stored as a Podman secret** (only checked once
  Podman's API service is confirmed running — see
  [What gets installed](#what-gets-installed) above for the `podman
  secret create azure-devops-pat -` command)
- **Git identity** not set (`~/.gitconfig.local` missing — see
  `.gitconfig.local.example`)
- **Azure DevOps git credentials not configured** (WSL only — only
  checked when running under WSL; fires if Git for Windows/standalone
  GCM for Windows wasn't found yet when
  `install-azure-devops-git-credentials.sh` last ran — see [What gets
  installed](#what-gets-installed) above)
- **Azure DevOps org(s) not configured, or left as placeholder**, for
  the Copilot MCP server (only checked if the standalone Copilot CLI is
  installed — see `.azure-devops.local.example`; fires both when
  `~/.azure-devops.local` is missing and when it still only contains
  placeholder org names)

Each check is live (re-evaluated every login, no "dismiss once" flag
file), so a reminder disappears for good the moment its underlying
condition is fixed, and network checks are capped with a short `timeout`
so being offline never hangs shell startup. The checks themselves live in
the dotfiles-provided `.zshrc`, not in a script here.

### Podman's systemd user session on WSL

`brew services start podman` manages Podman's API service as a `systemd
--user` unit, which needs a real login session (user D-Bus +
`/run/user/<uid>`). WSL doesn't create one by default, so the command can
fail with:

```
Failed to connect to user scope bus via local transport: No such file or directory
Error: Failure while executing; `/usr/bin/env /usr/bin/systemctl --user daemon-reload` exited with 1.
```

Fix it once per machine:

```bash
sudo loginctl enable-linger $(whoami)
```

then, from Windows PowerShell, fully restart the WSL VM (a new
terminal/tab is **not** enough — lingering only takes effect on the next
VM boot):

```powershell
wsl --shutdown
```

Reopen the Ubuntu terminal and re-run `brew services start podman`.

## Keybindings: Ctrl+Left/Right word-jump

The dotfiles-provided `.zshrc` binds Ctrl+Left/Right to zsh's
`forward-word`/`backward-word` (covering the handful of escape-sequence
encodings xterm-compatible terminals actually send), and
`.config/tmux/tmux.conf` sets `xterm-keys on` so tmux forwards those
modified-arrow sequences through to the shell unmangled instead of
swallowing/mistranslating them.

## Preventing AI co-author trailers

`install-git-hooks.sh` sets git's **global** `core.hooksPath` (once per
WSL user, the same way `user.name`/`user.email` are configured globally —
not per-repo) to `$HOME/.git-hooks`, which the dotfiles checkout deploys a
`commit-msg` hook into. That hook rejects any commit whose message
contains a `Co-authored-by:` or `Signed-off-by:` trailer mentioning
"copilot" (case-insensitive). Because it's global rather than per-repo,
it applies to every repo in this distro, including ones cloned fresh
later — not just the ones this setup touches directly. The matching
Windows-side setup (`Install-GitHooks.ps1` in WSL-Setup) does the same for
git on Windows, pointing at `%USERPROFILE%\.git-hooks` there instead.

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
./scripts/install-zsh.sh
./scripts/install-node.sh
./scripts/install-dotnet.sh
./scripts/install-azure-cli.sh
./scripts/install-dotfiles.sh
./scripts/install-git-hooks.sh
./scripts/install-copilot-cli.sh
./scripts/install-azure-devops-mcp.sh
./scripts/install-azure-devops-git-credentials.sh
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
  install-fd.sh                # fd (brew; used by the dotfiles .zshrc as fzf's file source for Ctrl+T / Alt+C)
  install-tmux.sh              # brew (config comes from the dotfiles checkout)
  install-podman.sh            # brew + apt uidmap (rootless UID/GID mapping)
  install-delta.sh             # git-delta (brew; config comes from the dotfiles checkout)
  install-lazygit.sh           # lazygit (brew; config comes from the dotfiles checkout)
  install-lazydocker.sh        # lazydocker (brew) + brew-services-managed rootless podman API service
  install-yazi.sh               # yazi (brew; `y` cd-on-quit wrapper comes from the dotfiles checkout)
  install-eza.sh                 # eza (brew; ls/ll/la/lt aliases come from the dotfiles checkout)
  install-zsh.sh                # zsh + fzf + zsh-autosuggestions + zsh-syntax-highlighting (brew), login shell, /etc/zprofile fix
  install-node.sh                # Node.js + npx (brew) - needed to launch npx-based MCP servers
  install-dotnet.sh              # .NET 10 SDK (brew `dotnet` formula, aka dotnet@10) + DOTNET_ROOT /etc/profile.d wiring
  install-azure-cli.sh           # Azure CLI / az (brew) - auth left to the user (`az login`)
  install-nuget-credential-provider.sh # Azure Artifacts credential provider (~/.nuget/plugins) + jq
  install-dotfiles.sh          # bare-repo checkout of github.com/falwickster/dotfiles into $HOME
  install-git-hooks.sh         # Points global git core.hooksPath at the dotfiles-deployed commit-msg hook
  install-copilot-cli.sh       # standalone GitHub Copilot CLI (brew-free; upstream's own installer) - MCP-capable `copilot` command
  install-azure-devops-mcp.sh  # registers the Azure DevOps MCP server with Copilot CLI (`copilot mcp add`), runs last
  install-azure-devops-git-credentials.sh  # dev.azure.com-only git credential helper (GCM): Windows Credential Manager on WSL, native Linux GCM otherwise
dotfiles/                      # git submodule: github.com/falwickster/dotfiles (authoring copy, see above)
```

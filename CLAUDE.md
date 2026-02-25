# CLAUDE.md - AI Agent Context for Homebase

## Project Overview

Homebase provides a machine substrate for consistent development environments across macOS, Bazzite Linux (and other Universal Blue immutable distros), and WSL. Git worktrees and nix develop subshells provide per-agent workspace isolation and per-project toolchains.

**Status:** Implementation (not yet tested on clean machines)

**Owner:** J. Aaron Farr (farra)

**Repo:** `farra/homebase` (public, GitHub)

## Goals

1. Provision a new machine with a consistent set of tools
2. Keep configuration files synced (Doom Emacs, shell config, git config)
3. Support immutable Linux distros (Bazzite) without fighting their philosophy
4. Minimize manual steps and platform-specific knowledge
5. Make updates easy and non-destructive

## Non-Goals

- Project-level dependency management (handled by [cautomaton-develops](https://github.com/farra/cautomaton-develops))
- Full NixOS or home-manager (complexity concerns, past bad experience)
- Dev containers as the primary abstraction

## Architecture

### Layered Model

```
Layer 0: Host (OS-specific bootstrap)
├── Bazzite:  Homebrew → chezmoi, just, direnv, zsh, 1password-cli
├── WSL:      (future, same pattern)
└── macOS:    (future, Homebrew + nix native)

Layer 1: Homebase distrobox (baked image via Nix flake)
├── All dev tools pre-installed (ripgrep, fd, fzf, bat, eza, starship, etc.)
├── Emacs with vterm (exported to host desktop via distrobox-export)
├── Fedora toolbox:43 base (distrobox-compatible)
└── $HOME shared with host (chezmoi dotfiles visible in both)

Layer 2: Per-project nix flakes (cautomaton-develops, out of scope)
```

### Platform Matrix

| Platform | Host Substrate | Dev Environment | Emacs |
|----------|---------------|-----------------|-------|
| macOS | Homebrew | Nix (native) | Homebrew Cask |
| Bazzite | Homebrew (to ~/.linuxbrew) | Distrobox + Nix | In distrobox, exported to host |
| WSL (Fedora) | Homebrew | Distrobox + Nix | In distrobox, exported via WSLg |

### Why This Architecture

**Homebrew at Layer 0:** Only package manager that works everywhere without root. Installs to user directory on Linux (~/.linuxbrew). Works on immutable distros without modification.

**Distrobox on Linux/WSL:** Bazzite is immutable (rpm-ostree); Nix fights this. Distrobox provides a mutable Fedora environment inside the immutable host. $HOME is shared via bind mount.

**Nix inside Distrobox (not on host):** Universal Blue explicitly rejected Nix support (SELinux issues). Inside distrobox, Nix has full control.

**Native Nix on macOS:** Nix works well natively; no distrobox friction.

**Baked image:** All tools pre-installed via `nix profile install` during image build. No bootstrap step inside the container — `distrobox enter home` gives a fully equipped environment immediately.

## Key Files

| File | Purpose |
|------|---------|
| `homebase.toml` | Single source of truth for tool definitions |
| `flake.nix` | Nix flake defining all container tools |
| `images/Containerfile` | Baked distrobox image (fedora-toolbox base + Nix) |
| `bootstrap/bazzite.sh` | Layer 0 bootstrap (9 idempotent phases) |
| `scripts/render-brewfile.sh` | Generates ephemeral Homebrew bundle from `homebase.toml` |
| `justfile` | Project development commands (image build, flake check) |
| `dot_homebase/justfile` | User commands (setup, updates, worktrees, distrobox lifecycle) |
| `dot_zshrc.tmpl` | Shell config (zsh + starship + plugins + aliases) |
| `dot_zprofile` | Login shell checks (distrobox entry: chezmoi sync status, etc.) |
| `dot_config/starship.toml` | Starship prompt (Nerd Font Symbols + nix detect) |
| `dot_config/doom/` | Doom Emacs configuration |
| `dot_gitconfig.tmpl` | Git config (templated) |
| `run_once_before_import-gpg-keys.sh.tmpl` | Import GPG keys from 1Password for authinfo encryption |
| `run_onchange_create-authinfo-gpg.sh.tmpl` | Create encrypted `~/.authinfo.gpg` from 1Password PAT |
| `private_dot_ssh/` | SSH keys + config (from 1Password templates) |
| `.chezmoi.toml.tmpl` | chezmoi config with user data |
| `.chezmoiexternal.toml` | External repos (forge clone) |
| `.chezmoiignore` | Files excluded from chezmoi apply |
| `scripts/parse-toml-array.sh` | Pure-bash TOML array parser (used by flatpak recipes + bootstrap) |
| `secretspec.toml` | Runtime secrets declaration |
| `DECISIONS.md` | Design decisions and rationale |
| `.github/workflows/build-image.yml` | CI to build and push OCI image |

### homebase.toml

Declares tools per layer. Sections:

```toml
[host]        # Homebrew tools for all platforms
tools = ["git", "chezmoi", "zsh", "just", "direnv", "node"]

[container]   # Nix flake tools baked into the image
packages = ["ripgrep", "fd", "fzf", "bat", "eza", "starship", ...]
include = ["emacs-vterm"]  # special package expressions from flake.nix

[fonts]       # Host-level Nerd Fonts
nerd-fonts = ["FiraCode", "FiraMono"]

[macos]       # Homebrew casks (macOS only)
casks = ["emacs", "tailscale", "font-fira-code-nerd-font", "font-fira-mono-nerd-font"]

[flatpaks]    # Host-level desktop apps via Flatpak (Flathub, Bazzite/Linux)
apps = ["md.obsidian.Obsidian", "com.discordapp.Discord", ...]

[workspace]   # Directory layout docs
```

### Two Justfiles

- **`./justfile`** — Project development. Run from repo checkout. Image building, flake checks, dotfile staging.
- **`~/.homebase/justfile`** — User-facing. Run via `homebase` alias. Setup, updates, distrobox lifecycle, Doom Emacs, AI agents.

## Bootstrap Flow

### Bazzite (scripted)

`bootstrap/bazzite.sh` runs 9 idempotent phases (stamp files in `~/.homebase-bootstrap/`):

1. Install Homebrew (to `~/.linuxbrew`, no root)
2. Install host tools + set zsh as default shell
3. Authenticate to 1Password (`op signin`)
4. Import GPG keys from 1Password (for `~/.authinfo.gpg` encryption)
5. Apply dotfiles (`chezmoi init --apply` with PAT-embedded HTTPS URL)
6. Install Nerd Fonts (FiraCode, FiraMono to `~/.local/share/fonts/`)
7. Create distrobox (podman login to GHCR, pull image, `distrobox create`)
8. Enable Tailscale daemon
9. Install Flatpak apps from `homebase.toml` `[flatpaks]` section

SSH keys are *output* of chezmoi apply (from 1Password templates), not a prerequisite. This solves the bootstrap paradox.

### macOS (manual, future)

```bash
brew install chezmoi && brew install --cask 1password-cli
eval "$(op signin)"
chezmoi init --apply farra/homebase
~/.local/share/chezmoi/scripts/render-brewfile.sh ~/.local/share/chezmoi/homebase.toml > /tmp/homebase.Brewfile
brew bundle --file=/tmp/homebase.Brewfile --upgrade
```

## Secrets

1Password is the secrets provider. Two layers:

| Layer | Tool | Purpose |
|-------|------|---------|
| Bootstrap | chezmoi + 1Password | SSH keys, GPG keys, GitHub PAT → encrypted `.authinfo.gpg` |
| Runtime | secretspec + 1Password | API keys, tokens (injected at runtime) |

All templates use `op://Private/...` (1Password's default vault is "Private").

## Shell Environment

Zsh with:
- **Starship** prompt — Nerd Font Symbols preset, `nix_shell` heuristic for `nix develop` detection
- **Atuin** — shell history sync (replaces Ctrl-R)
- **Zoxide** — smart cd (`z` command)
- **fzf** — fuzzy finder with fd backend (Ctrl-T files, Alt-C dirs)
- **zsh-autosuggestions** — ghost-text from history
- **zsh-syntax-highlighting** — green/red command validation
- **Nushell** — available (not default)
- Smart aliases: `eza`→`ls`, `bat`→`cat`/`less`, `delta`→`diff`, `btm`→`top`, `lazygit`→`lg`, `tldr`→`help`, `glow`→`md`
- Git aliases: `gs`, `gd`, `gds`, `gl`, `gla`, `ga`, `gc`, `gco`, `gb`, `gw`, `gwl`
- FiraCode + FiraMono Nerd Fonts (host-level)

### Distrobox entry checks (`dot_zprofile`)

`~/.zprofile` runs once per login shell — including `distrobox enter`. It detects the container environment (`/run/.containerenv`) and runs lightweight checks:

- **chezmoi sync status** — warns if dotfiles are out of sync between source and `$HOME`

Add new checks inside the `if [[ -f /run/.containerenv ]]` block. Keep them fast and non-blocking.

## Workspace Model

Git worktrees provide per-agent workspace isolation:

```
~/dev/.worktrees/      # Bare clones (hidden)
~/dev/me/              # github.com/farra worktrees
~/dev/jmt/             # github.com/jamandtea worktrees
~/dev/ref/             # Third-party / reference worktrees
~/forge/               # Regular clone (not worktree pattern)
```

Managed via `homebase` alias: `homebase clone`, `homebase wt`, `homebase wt-rm`, `homebase wts`

## AI Agent Guidelines

When helping with this project:

1. **Prefer editing existing files** — Don't create new config files without discussion
2. **Keep homebase.toml in sync** — If adding tools, update `homebase.toml` and `dot_zshrc.tmpl` (if alias/init needed)
3. **Consider all platforms** — Changes should work on macOS, Bazzite, and WSL
4. **Respect immutability** — Don't assume root access or system-level changes on Bazzite
5. **Use the right justfile** — Project dev commands in `./justfile`, user-facing commands in `dot_homebase/justfile`
6. **Be greedy with chezmoi** — Default to managing config files in chezmoi, not ignoring them. The goal is full environment replication across workstations. When a file has machine-specific values, use chezmoi templates to make it portable rather than excluding it via `.chezmoiignore`.

### Common Tasks

**Add a new tool:**
1. Add to `homebase.toml` `[container]` `packages` (nixpkgs attr names only)
2. If it's a custom expression, add its name to `[container]` `include` and define it in `flake.nix` `specialIncludes`
3. If it needs shell init or alias, add to `dot_zshrc.tmpl`
4. Run `nix flake check`

**Add a host-only tool:**
1. Add to `homebase.toml` `[host]` tools (must be a brew formula, not a cask)
2. No checked-in Brewfile required; host commands render an ephemeral Brewfile at runtime
3. Note: `1password-cli` is a cask and handled directly in bootstrap scripts, not via `[host].tools`

**Add a new Flatpak app:**
1. Add the Flathub app ID to `homebase.toml` `[flatpaks]` apps
2. Run `homebase setup-flatpaks` to install

**Update Doom Emacs config:**
1. Edit files in `dot_config/doom/`
2. Run `chezmoi apply` to apply locally
3. Run `homebase doom-sync` to sync Doom

**Test distrobox image:**
```bash
just build-image
just test-local
distrobox enter homebase-test
which emacs rg fd fzf bat starship
```

**Debug bootstrap issues:**
- Check stamp files: `ls ~/.homebase-bootstrap/`
- Check nix: `which nix` and PATH includes `~/.nix-profile/bin`
- Check chezmoi: `chezmoi diff`
- Check 1Password: `op account list`

## Design Doc Workflow

This project uses design docs for task management. Design docs live in `docs/design/`.

### Key Files
- `backlog.org` - Working surface for active tasks
- `docs/design/*.org` - Design documents (source of truth)
- `README.org` - Project config (prefix: HB, categories, statuses)
- `org-setup.org` - Shared org-mode configuration

### Workflow
1. Create design docs with `/backlog:new-design-doc`
2. Queue tasks with `/backlog:task-queue <id>`
3. Start work with `/backlog:task-start <id>`
4. Complete with `/backlog:task-complete <id>`

### Task ID Format
`[HB-NNN-XX]` where:
- HB = project prefix
- NNN = design doc number
- XX = task sequence

## Related Projects

| Project | Relationship |
|---------|--------------|
| [cautomaton-develops](https://github.com/farra/cautomaton-develops) | Project-level Nix environments (Layer 2) |
| [agentboxes](https://github.com/farra/agentboxes) | AI agent environment definitions (OCI image patterns) |
| [forge](https://github.com/farra/forge) | Personal productivity system (journal + vault) |

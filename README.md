# Homebase

Machine substrate for consistent development environments across macOS, Bazzite Linux, and WSL.

Git worktrees and nix develop subshells provide per-agent workspace isolation and per-project toolchains.

**Status:** Implementation
**Repo:** `farra/homebase` (private)

## Architecture

```
Layer 0: Host (OS-specific bootstrap)
├── Bazzite:  Homebrew → chezmoi, just, direnv, zsh, 1password-cli
├── WSL:      (future, same pattern)
└── macOS:    (future, Homebrew + nix native)

Layer 1: Homebase distrobox (baked image via Nix flake)
├── All dev tools pre-installed (ripgrep, fd, fzf, bat, eza, starship, etc.)
├── Emacs with vterm (exported to host desktop)
├── Fedora toolbox base (distrobox-compatible)
└── $HOME shared with host (chezmoi dotfiles visible in both)

Layer 2: Per-project nix flakes (cautomaton-develops, out of scope)
```

## Prerequisites

You need these items in your 1Password **Private** vault:

| Item | Field/Files | Purpose |
|------|-------------|---------|
| `cautamaton-ssh-key` | `private key`, `public key` | SSH key pair |
| `github-pat` | `credential` | GitHub PAT with `repo` + `read:packages` scopes |
| `cautomaton-homebase-gpg` | `public.asc`, `secret.asc` | GPG key for encrypting `~/.authinfo.gpg` |

## Quick Start

### Bazzite (primary target)

Transfer `bootstrap/bazzite.sh` to the machine and run it:

```bash
bash bazzite.sh
```

See [BOOTSTRAP.md](./BOOTSTRAP.md) for the full walkthrough, verification steps, and troubleshooting.

### macOS (future)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi 1password-cli
eval "$(op signin)"
op read "op://Private/cautomaton-homebase-gpg/homebase-authinfo-public.asc" | gpg --batch --import
op read "op://Private/cautomaton-homebase-gpg/homebase-authinfo-secret.asc" | gpg --batch --import
echo "48CF4CDEC93AE47B93491C7A43EBD702731ECFAC:6:" | gpg --batch --import-ownertrust
chezmoi init --apply farra/homebase
brew bundle --file=~/.local/share/chezmoi/Brewfile
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

## Workspace Layout

After bootstrap and `homebase setup`, the workspace looks like:

```
~/
├── forge/                  # Cloned via .chezmoiexternal.toml (regular clone)
├── dev/
│   ├── .worktrees/         # Bare clones (hidden, not worked in directly)
│   ├── me/                 # github.com/farra — worktrees here
│   ├── jmt/                # github.com/jamandtea
│   └── ref/                # Third-party / reference
├── .homebase/
│   └── justfile            # User commands (setup, updates, worktrees, distrobox)
└── .ssh/                   # SSH keys from 1Password templates
```

### Git Worktree Model

Bare clones live in `~/dev/.worktrees/`. Working copies are worktrees checked out into group dirs. Each worktree = one branch = one agent. The branch is the artifact; the directory is disposable.

```bash
homebase clone farra/projectA              # bare clone → .worktrees/projectA.git
homebase wt projectA fix-auth              # worktree → me/projectA-fix-auth
homebase wt projectA add-search jmt        # worktree → jmt/projectA-add-search
homebase wts                               # list all active worktrees
homebase wt-rm me/projectA-fix-auth        # clean up (keeps branch)
```

Forge does *not* follow this pattern — it's a regular clone at `~/forge`.

## Two Justfiles

**`./justfile`** — for working *on* homebase (the project). Run from the repo checkout:

```bash
just build-image        # Build baked distrobox image
just test-local         # Build + create test distrobox
just check              # Run nix flake check
just dev                # Nix develop shell (macOS)
just re-add             # Stage changes back to chezmoi source
just push               # Commit and push
```

**`~/.homebase/justfile`** — for living *in* homebase. Run via the `homebase` shell alias:

```bash
homebase setup              # First-time: workspace + Doom + agents
homebase update             # Update everything (dotfiles + host + agents)
homebase doom-sync          # After Doom config changes
homebase distrobox-rebuild  # Pull fresh image + recreate distrobox
homebase                    # List all commands
```

## Repository Structure

```
.
├── flake.nix                     # Nix flake (all container tools)
├── flake.lock
├── images/Containerfile          # Baked distrobox image (fedora-toolbox base)
├── bootstrap/bazzite.sh          # Layer 0 bootstrap (7 phases, idempotent)
├── homebase.toml                 # Tool definitions (source of truth)
├── Brewfile                      # Host-only tools (Homebrew)
├── justfile                      # Project development commands
├── secretspec.toml               # Runtime secrets declaration
├── .chezmoi.toml.tmpl            # chezmoi config
├── .chezmoiexternal.toml         # External repos (forge)
├── .chezmoiignore                # Files excluded from chezmoi apply
├── dot_homebase/justfile          # → ~/.homebase/justfile (user commands + worktrees)
├── dot_config/
│   ├── doom/                     # Doom Emacs config
│   ├── starship.toml             # Starship prompt (Nerd Font Symbols + nix detect)
│   ├── git/ignore                # Global gitignore
│   ├── gh/config.yml             # GitHub CLI config
│   ├── zed/settings.json         # Zed editor config
│   └── glow/glow.yml             # Markdown viewer config
├── dot_zshrc.tmpl                # Shell config (zsh + plugins + aliases)
├── dot_gitconfig.tmpl            # Git config (templated)
├── run_once_before_import-gpg-keys.sh.tmpl  # Import GPG keys from 1Password
├── run_onchange_create-authinfo-gpg.sh.tmpl # Encrypted ~/.authinfo.gpg from PAT
├── private_dot_ssh/              # SSH keys + config (from 1Password)
├── dot_claude/                   # Claude Code settings
├── dot_codex/                    # Codex CLI settings
├── dot_gemini/                   # Gemini CLI settings
└── .github/workflows/            # CI: build + push image to GHCR
```

## Shell Environment

Zsh with:
- **Starship** prompt (Nerd Font Symbols, nix develop detection)
- **Atuin** for shell history sync
- **Zoxide** for smart directory jumping
- **fzf** with fd backend (Ctrl-T files, Alt-C dirs)
- **zsh-autosuggestions** and **zsh-syntax-highlighting**
- Smart aliases: `eza` as `ls`, `bat` as `cat`, `delta` as `diff`, `btm` as `top`
- Git aliases: `gs`, `gd`, `gl`, `gla`, `gw`, `gwl`, `lg` (lazygit)
- FiraCode + FiraMono Nerd Fonts (host-level install)
- Nushell available (not default)

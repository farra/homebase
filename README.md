# Homebase

Machine substrate for consistent development environments across macOS, Bazzite Linux, and WSL.

**Status:** Implementation
**Repo:** `farra/homebase` (private)

## Architecture

```
Layer 0: Host (OS-specific bootstrap)
├── Bazzite:  Homebrew → chezmoi, just, direnv, 1password-cli
├── WSL:      (future, same pattern)
└── macOS:    (future, Homebrew + nix native)

Layer 1: Homebase distrobox (baked image via Nix flake)
├── All dev tools pre-installed (ripgrep, fd, fzf, bat, eza, etc.)
├── Emacs (exported to host desktop)
└── $HOME shared with host (chezmoi dotfiles visible in both)

Layer 2: Per-project nix flakes (cautomaton-develops, out of scope)
```

## Prerequisites

You need these items in your 1Password **Private** vault:

| Item | Field | Purpose |
|------|-------|---------|
| `cautamaton-ssh-key` | `private key` | SSH private key |
| `cautamaton-ssh-key` | `public key` | SSH public key |
| `github-pat` | `credential` | GitHub PAT with `repo` + `read:packages` scopes |

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
chezmoi init --apply farra/homebase
brew bundle --file=~/.local/share/chezmoi/Brewfile
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

## Workspace Layout

`chezmoi apply` sets up the workspace automatically:

```
~/
├── forge/                  # Cloned via .chezmoiexternal.toml (regular clone)
├── dev/
│   ├── .worktrees/         # Bare clones (hidden, not worked in directly)
│   ├── me/                 # github.com/farra — worktrees here
│   ├── jmt/                # github.com/jamandtea
│   ├── ref/                # Third-party / reference
│   └── justfile            # Workspace commands (worktree lifecycle)
└── .ssh/                   # SSH keys from 1Password templates
```

### Git Worktree Model

Bare clones live in `~/dev/.worktrees/`. Working copies are worktrees checked out into group dirs. Each worktree = one branch = one agent. The branch is the artifact; the directory is disposable.

```bash
cd ~/dev
just clone farra/projectA              # bare clone → .worktrees/projectA.git
just wt projectA fix-auth              # worktree → me/projectA-fix-auth
just wt projectA add-search jmt        # worktree → jmt/projectA-add-search
just wts                               # list all active worktrees
just wt-rm me/projectA-fix-auth        # clean up (keeps branch)
```

Emacs + agents work in the copies under the group dirs. Forge does *not* follow this pattern — it's a regular clone at `~/forge`.

## Repository Structure

```
.
├── flake.nix                  # Nix flake (dev tools for container + macOS)
├── flake.lock                 # Nix flake lock
├── images/Containerfile       # Baked distrobox image
├── bootstrap/bazzite.sh       # Layer 0 bootstrap for Bazzite
├── homebase.toml              # Tool definitions (source of truth)
├── Brewfile                   # Host substrate tools
├── justfile                   # Orchestration commands
├── secretspec.toml            # Runtime secrets declaration
├── .chezmoi.toml.tmpl         # chezmoi config
├── .chezmoiexternal.toml      # External repos (forge)
├── .chezmoiignore             # Files excluded from chezmoi apply
├── run_once_create-workspace.sh  # Creates ~/dev/{.worktrees,me,jmt,ref}
├── dev/justfile               # Workspace commands (→ ~/dev/justfile)
├── dot_config/doom/           # Doom Emacs config
├── dot_gitconfig.tmpl         # Git config (templated)
├── dot_zshrc.tmpl             # Shell config
└── private_dot_ssh/
    ├── config.tmpl            # SSH config
    ├── private_id_rsa.tmpl    # Private key (from 1Password)
    └── id_rsa.pub.tmpl        # Public key (from 1Password)
```

## Commands

```bash
just                    # List available commands
just apply              # Apply dotfiles via chezmoi
just sync               # Full sync (pull + apply + host tools)
just build-image        # Build baked distrobox image
just test-local         # Build + create test distrobox
just distrobox-enter    # Enter homebase distrobox
just dev                # Nix develop shell (macOS)
```

## Development

### Making Changes

```bash
just apply              # Apply locally
just re-add             # Stage changes back to chezmoi source
just push               # Commit and push
```

### Testing the Image

```bash
just build-image        # Build locally
just test-local         # Create throwaway distrobox
distrobox enter homebase-test
# Verify: which emacs rg fd fzf bat just direnv chezmoi
```

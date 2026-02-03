# Homebase

Machine substrate for consistent development environments across macOS, Bazzite Linux, and WSL.

**Status:** Implementation
**Repo:** `farra/homebase` (private)

## Quick Start

### macOS

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Bootstrap tools + SSH keys from Bitwarden
brew install git chezmoi bitwarden-cli
bw login && export BW_SESSION=$(bw unlock --raw)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
bw get notes "ssh-keys/id_rsa" > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa
bw get notes "ssh-keys/id_rsa.pub" > ~/.ssh/id_rsa.pub && chmod 644 ~/.ssh/id_rsa.pub
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa

# Apply dotfiles + install tools
chezmoi init --apply farra/homebase
brew bundle --file=~/.local/share/chezmoi/Brewfile

# Install Nix (for project-level shells)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

### Bazzite / WSL (Fedora)

```bash
# Install Homebrew (to ~/.linuxbrew)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Bootstrap (same as macOS)
brew install git chezmoi bitwarden-cli
# ... SSH key setup same as above ...

# Apply dotfiles
chezmoi init --apply farra/homebase

# Create distrobox with homebase image
podman pull ghcr.io/farra/homebase:slim
distrobox create --image ghcr.io/farra/homebase:slim --name home

# First entry bootstraps tools
distrobox enter home
just bootstrap
```

## Architecture

See `vault/devenv/homebase/README.md` in forge for full documentation.

```
Layer 0: Homebrew (all platforms)
Layer 1: Distrobox + Nix (Linux) or Nix native (macOS)
Layer 2: Project-specific nix develop (cautomaton-develops)
```

## Repository Structure

```
.
├── .chezmoi.toml.tmpl      # chezmoi config with platform detection
├── homebase.toml           # Tool definitions (source of truth)
├── Brewfile                # Host substrate tools
├── Containerfile.slim      # Distrobox image (Nix-inside)
├── justfile                # Orchestration commands
├── secretspec.toml         # Runtime secrets declaration
├── dot_config/
│   └── doom/               # Doom Emacs config
├── dot_gitconfig.tmpl      # Git config (templated)
├── dot_zshrc.tmpl          # Shell config
└── private_dot_ssh/
    └── config.tmpl         # SSH config (NOT keys)
```

## Commands

```bash
just              # List available commands
just apply        # Apply dotfiles via chezmoi
just sync         # Full sync (pull + apply + tools)
just bootstrap    # Install tools via nix profile (Linux distrobox)
just build-slim   # Build slim distrobox image locally
just test-slim    # Test slim image in throwaway distrobox
```

## Development

### Initial Setup (one-time)

```bash
cd ~/dev/me/homebase

# Create private GitHub repo
gh repo create farra/homebase --private --source=. --push

# Or manually:
git commit -m "Initial scaffold"
git remote add origin git@github.com:farra/homebase
git push -u origin main
```

### Testing

```bash
# Test chezmoi apply locally (dry-run)
chezmoi init --apply --dry-run ~/dev/me/homebase

# Test distrobox image build
just build-slim
just test-slim
```

### Making Changes

```bash
# Edit dotfiles, then:
just apply              # Apply locally
just re-add             # Stage changes back to chezmoi source
just push               # Commit and push
```

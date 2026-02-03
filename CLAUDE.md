# CLAUDE.md - AI Agent Context for Homebase

## Project Overview

Homebase provides a machine substrate for consistent development environments across macOS, Bazzite Linux (and other Universal Blue immutable distros), and WSL. It replaces an older Dropbox-based setup (`~/dropbox/Home/wsl-setup-script.sh`) with a modern, cross-platform approach.

**Status:** Implementation (early stage, not yet tested on clean machines)

**Owner:** J. Aaron Farr (farra)

**Repo:** `farra/homebase` (private, GitHub)

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
Layer 0: Homebrew (universal substrate)
         All platforms: git, chezmoi, zsh, just, bitwarden-cli, direnv, ripgrep, fd, fzf...
         macOS only: Emacs (cask)
         Bazzite/WSL: distrobox (pre-installed or via package manager)

Layer 1: Primary Dev Environment
         macOS: Nix (native) + Homebrew GUI apps
         Bazzite/WSL: distrobox "home" container with Nix inside
                      Emacs exported to host via distrobox-export

Layer 2: Project-Specific (cautomaton-develops)
         nix develop with deps.toml
         Runs inside distrobox on Linux, native on macOS
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

## Key Files

| File | Purpose |
|------|---------|
| `DECISIONS.md` | Open decisions requiring resolution |
| `homebase.toml` | Single source of truth for tool definitions |
| `Brewfile` | Host substrate tools (macOS/Linux) |
| `Containerfile.slim` | Distrobox image with Nix pre-installed |
| `justfile` | Orchestration commands |
| `secretspec.toml` | Runtime secrets declaration |
| `.chezmoi.toml.tmpl` | chezmoi config with user data |
| `dot_config/doom/` | Doom Emacs configuration |
| `dot_gitconfig.tmpl` | Git config (templated) |
| `dot_zshrc.tmpl` | Shell config |
| `private_dot_ssh/config.tmpl` | SSH config (NOT keys) |
| `.github/workflows/build-image.yml` | CI to build and push OCI image |

### homebase.toml

Declares tools that should exist everywhere. Consumed by:
- Brewfile (for macOS/Linux host substrate)
- justfile bootstrap (for distrobox Nix profile)

```toml
[core]
tools = ["git", "chezmoi", "zsh", "just", "bitwarden-cli", ...]

[macos]
casks = ["emacs"]

[linux]
extra = ["emacs"]
```

## Bootstrap Flows

SSH keys are retrieved via chezmoi templates from your password manager — no separate key retrieval step.

### macOS Bootstrap

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install chezmoi and password manager CLI
brew install chezmoi
brew install --cask 1password-cli  # if using 1Password
# -or-
brew install bitwarden-cli         # if using Bitwarden

# 3. Authenticate to password manager
eval $(op signin)                              # 1Password
# -or-
bw login && export BW_SESSION=$(bw unlock --raw)  # Bitwarden

# 4. Bootstrap everything (SSH keys come from templates)
chezmoi init --apply farra/homebase

# 5. Install remaining tools
brew bundle --file=~/.local/share/chezmoi/Brewfile

# 6. Install Nix (for project-level shells)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

### Bazzite / WSL (Fedora) Bootstrap

```bash
# 1. Install Homebrew (to ~/.linuxbrew)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 2. Install chezmoi and password manager CLI
brew install chezmoi bitwarden-cli  # Bitwarden available via brew on Linux
# -or- for 1Password on Fedora:
# sudo dnf install https://downloads.1password.com/linux/rpm/stable/x86_64/1password-cli-latest.x86_64.rpm

# 3. Authenticate to password manager
eval $(op signin)                              # 1Password
# -or-
bw login && export BW_SESSION=$(bw unlock --raw)  # Bitwarden

# 4. Bootstrap dotfiles (SSH keys come from templates)
chezmoi init --apply farra/homebase

# 5. Create distrobox with homebase image
podman pull ghcr.io/farra/homebase:slim
distrobox create --image ghcr.io/farra/homebase:slim --name home

# 6. First entry bootstraps tools
distrobox enter home
just bootstrap
```

## Just Commands

```bash
just              # List available commands
just apply        # Apply dotfiles via chezmoi
just update       # Pull dotfiles from remote
just sync         # Full sync (pull + apply + tools)
just bootstrap    # Install tools via nix profile (Linux distrobox)
just build-slim   # Build slim distrobox image locally
just test-slim    # Test slim image in throwaway distrobox
just enter        # Enter distrobox (Linux only)
just re-add       # Stage changed dotfiles back to chezmoi
just push         # Commit and push dotfile changes
just doom-sync    # Doom Emacs sync after config changes
```

## Secrets Management

Two layers, one password manager (your choice of 1Password or Bitwarden):

| Layer | Tool | Purpose |
|-------|------|---------|
| Bootstrap | chezmoi + password manager | SSH keys (written to ~/.ssh/ during apply) |
| Runtime | secretspec + password manager | API keys, tokens (injected at runtime) |
| Team/project | Pulumi ESC | Infrastructure secrets |

### How Bootstrap Works

chezmoi clones via HTTPS (no SSH needed), then templates retrieve SSH keys from your password manager:

**With 1Password:**
```
private_dot_ssh/private_id_rsa.tmpl:
{{- onepasswordRead "op://Personal/ssh-key/private_key" -}}
```

**With Bitwarden:**
```
private_dot_ssh/private_id_rsa.tmpl:
{{- (bitwarden "item" "ssh-key").notes | b64dec -}}
```

This solves the "bootstrap paradox" — SSH keys are *output* of `chezmoi apply`, not a prerequisite.

### Password Manager Comparison

| Feature | 1Password | Bitwarden |
|---------|-----------|-----------|
| Cost | $36/year | Free |
| chezmoi syntax | `onepasswordRead "op://..."` | `(bitwarden "item" "name").notes` |
| SSH key handling | Clean | Needs base64 encode/decode |

See [DECISIONS.md](./DECISIONS.md) for full comparison.

### Runtime Secrets

API keys (Claude, OpenAI, GitHub) are declared in `secretspec.toml` and retrieved via secretspec. Both 1Password and Bitwarden work as secretspec providers.

## Testing Targets

The project needs testing on:

1. **Clean WSL Fedora** — `wsl --unregister Fedora && wsl --install -d Fedora`
2. **Clean Bazzite Linux** — Fresh Bazzite VM or hardware install

Testing checklist:
- [ ] Homebrew installs successfully
- [ ] Password manager CLI authenticates
- [ ] chezmoi init --apply retrieves SSH keys from password manager
- [ ] SSH keys have correct permissions (600 for private, 644 for public)
- [ ] distrobox image builds
- [ ] just bootstrap completes
- [ ] Emacs exports to host desktop
- [ ] dot_zshrc.tmpl applies correctly
- [ ] doom sync works

## Current Status

**Implemented:**
- homebase.toml tool definitions
- Brewfile for host substrate
- Containerfile.slim for distrobox image
- justfile with core commands
- chezmoi templates (gitconfig, zshrc, ssh config)
- Doom Emacs config files
- secretspec.toml declarations
- GitHub Actions workflow for image building

**Not Yet Tested:**
- Full bootstrap on clean WSL Fedora
- Full bootstrap on clean Bazzite
- macOS bootstrap
- distrobox image pull from ghcr.io
- Emacs export to host

**Open Decisions:** See [DECISIONS.md](./DECISIONS.md) for full analysis. Critical path:
1. Secrets provider (Bitwarden vs 1Password vs chezmoi-native)
2. Whether to keep Dropbox (for forge vault) or drop entirely
3. Testing on clean machines to validate the approach

## Related Projects

| Project | Relationship |
|---------|--------------|
| [cautomaton-develops](https://github.com/farra/cautomaton-develops) | Project-level Nix environments (Layer 2) |
| [agentboxes](https://github.com/farra/agentboxes) | AI agent environment definitions (OCI patterns) |
| [forge](https://github.com/farra/forge) | Personal productivity system (journal + vault) |
| `~/dropbox/Home` | Legacy setup being replaced |

## Design Documentation

Full design rationale is in `~/forge/vault/devenv/homebase/README.md`, including:
- Nix on Universal Blue research (why Nix on host is unsupported)
- `nix profile` vs `nix develop` concepts
- Slim vs Full image tradeoffs
- Secrets management architecture

## AI Agent Guidelines

When helping with this project:

1. **Test changes locally first** — Use `just build-slim` and `just test-slim`
2. **Prefer editing existing files** — Don't create new config files without discussion
3. **Keep homebase.toml in sync** — If adding tools, update both homebase.toml and Brewfile
4. **Check secretspec** — If a new secret is needed, declare it in secretspec.toml
5. **Consider all platforms** — Changes should work on macOS, Bazzite, and WSL
6. **Respect immutability** — Don't assume root access or system-level changes on Bazzite

### Common Tasks

**Add a new tool:**
1. Add to `homebase.toml` [core] tools
2. Add to `Brewfile`
3. Add to `justfile` bootstrap nix profile install line

**Update Doom Emacs config:**
1. Edit files in `dot_config/doom/`
2. Run `just apply` to apply via chezmoi
3. Run `just doom-sync` to sync Doom

**Test distrobox image:**
```bash
just build-slim
just test-slim
# Then: distrobox enter homebase-test
```

**Debug bootstrap issues:**
- Check `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` exists
- Check `~/.nix-profile/bin` is in PATH
- Check `~/.homebase-bootstrapped` marker file

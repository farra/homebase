# Homebase

Hello, I'm [J. Aaron Farr](https://github.com/farra). This is my homebase.

I bounce around a lot, between machines, between operating systems (mac, linux, wsl). I've spent years accumulating dotfiles, shell tweaks, and editor configs along with various scripts to quickly provision a new machine. I tried `nix home manager` and several other approaches. **Homebase** is my attempt to level this up into something repeatable and modern.

Homebase uses a layered approach (see below). The core is the host configuration, primarily with Homebrew (its one few package managers that really does live everywhere). From there, we leverage a potent mix of `chezmoi`, `nix`, `direnv`, `distrobox` to create a consistent home development environment. The final layer is [cautomaton-develops](https://github.com/farra/cautomaton-develops), a nix based system for managing project-level dependencies. It's my own take on `devbox` or similar systems. It also pairs with [agentboxes](https://github.com/farra/agentboxes), an experiment I'm running to manage AI agents and orchestrators in containers and distroboxes.

I'm also stealing a git worktree idea of [schmux](https://github.com/sergeknystautas/schmux) for my local `~/dev` directory, allowing for faster checkouts of branches. 

The heart of everything is still [(doom) emacs](https://github.com/doomemacs/doomemacs). It's ultimately where I live. You can see my emacs config here, particularly how I'm using [agent-shell](https://github.com/xenodium/agent-shell) and other tools for coding.

Homebase downloads my private `forge` repo, my digital "second brain" built on years of **`org-mode` + Obsidian vault** files. If you're not doing something similar, I recommend looking into Obsidian, particularly with how well it pairs with tools like Claude. Of course, if you _really_ want to improve your life, learn emacs and org-mode.

The philosophy here is clear layers, clear isolation, and secure repeatabilty. It may seem like a lot, but this keeps me sane when I'm quickly moving between different projects, testing out ideas, and doing so in a way that doesn't clutter up my machine. 

This repo is my personal config — it's not designed to be plug-and-play for someone else. But if you're interested in the patterns (immutable Linux + distrobox, chezmoi + 1Password, worktree-per-agent workflows), feel free to poke around and steal ideas.

## Architecture

```
Layer 0: Host (OS-specific bootstrap)
├── Bazzite:  Homebrew → chezmoi, just, direnv, zsh, 1password-cli
├── macOS:    Homebrew + Nix (native, no container)
└── WSL:      (future, same pattern as Bazzite)

Layer 1: Dev environment (baked OCI image via Nix flake)
├── All dev tools pre-installed (ripgrep, fd, fzf, bat, eza, starship, etc.)
├── Doom Emacs with vterm (exported to host desktop on Linux)
├── Fedora toolbox base (distrobox-compatible)
└── $HOME shared with host (chezmoi dotfiles visible in both)

Layer 2: Per-project toolchains (cautomaton-develops, separate repo)
└── Nix flakes per project, activated via direnv
```

## Prerequisites

You need these items in your 1Password **Private** vault (item names are configurable — see `.chezmoi.toml.tmpl` and `bootstrap/bazzite.sh`):

| Item (default name)       | Field/Files                 | Purpose                                         |
|---------------------------|-----------------------------|-------------------------------------------------|
| SSH key item              | `private key`, `public key` | SSH key pair                                    |
| GitHub PAT item           | `credential`                | GitHub PAT with `repo` + `read:packages` scopes |
| GPG key item              | `public.asc`, `secret.asc`  | GPG key for encrypting `~/.authinfo.gpg`        |

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
op read "op://Private/<your-gpg-key-item>/homebase-authinfo-public.asc" | gpg --batch --import
op read "op://Private/<your-gpg-key-item>/homebase-authinfo-secret.asc" | gpg --batch --import
echo "<your-gpg-fingerprint>:6:" | gpg --batch --import-ownertrust
chezmoi init --apply <your-github-user>/homebase
brew bundle --file=~/.local/share/chezmoi/Brewfile
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

> **Note:** Replace `<your-gpg-key-item>`, `<your-gpg-fingerprint>`, and `<your-github-user>` with your own values. On Bazzite, these are configured in `bootstrap/bazzite.sh`. For chezmoi templates, they're prompted during `chezmoi init`.

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
just build-variant gamedev                  # Build gamedev profile image (from homebase.toml)
just build-variant base                     # Build base profile image (from homebase.toml)
just test-local         # Build + create test distrobox
just test-variant-local gamedev             # Build + test variant image
just check              # Run nix flake check
just dev                # Nix develop shell (macOS)
just re-add             # Stage changes back to chezmoi source
just push               # Commit and push
```

**`~/.homebase/justfile`** — for living *in* homebase. Run via the `homebase` shell alias:

```bash
homebase setup              # First-time: workspace + Doom + agents
homebase setup gamedev      # First-time gamedev: base setup + gamedev extensions
homebase update             # Update everything (dotfiles + host + agents)
homebase doom-sync          # After Doom config changes
homebase box rebuild        # Pull fresh base image + recreate 'home'
homebase box create gamedev # Create gamedev box from profile image
homebase box enter gamedev  # Enter gamedev box
homebase                    # List all commands
```

## Container Profiles

Homebase supports multiple distrobox image profiles (flavors) built from the same Containerfile:

- **base**: default daily-driver profile (`homebase-base-env`)
- **gamedev**: base + game development stack (`homebase-gamedev-env`)

Current profile metadata is documented in `homebase.toml` under:

- `[profiles.base]`
- `[profiles.gamedev]`

Each profile can set:

- `flake_env` (which flake package output to install)
- `base_image` (container base distro/image)

The build pipeline is profile-aware:

- `images/Containerfile` accepts `BASE_IMAGE` and `FLAKE_ENV`
- `just build-variant <profile>` resolves profile metadata from `homebase.toml`
- images are tagged as `ghcr.io/farra/homebase:<profile>-latest`

## Input Remapper

Homebase tracks `input-remapper` configuration via chezmoi for reproducible mouse/controller mappings on Linux hosts.

- Presets are source-controlled under `dot_config/input-remapper-2/presets/...`
- Autoload is rendered from `dot_config/input-remapper-2/config.json.tmpl`
- Autoload should remain host-aware (template conditions by hostname/device availability)

Current test-case mapping:
- Device: `Razer Razer DeathAdder Elite`
- Preset: `desktop-nav`
- Mapping: extra mouse button (`BTN_SIDE` code `275`) -> `SUPER_L+W` (KDE Overview)

Recommended pattern for multi-machine portability:
- Keep presets backed up in git even if some devices are absent on other hosts.
- Gate autoload entries in `config.json.tmpl` so only matching hosts enable specific devices.

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
│   ├── input-remapper-2/         # input-remapper presets + host-aware autoload template
│   ├── zed/settings.json         # Zed editor config
│   └── glow/glow.yml             # Markdown viewer config
├── dot_zshrc.tmpl                # Shell config (zsh + plugins + aliases)
├── dot_gitconfig.tmpl            # Git config (templated)
├── dot_config/input-remapper-2/config.json.tmpl   # input-remapper autoload (host-aware)
├── dot_config/input-remapper-2/presets/...        # device-specific mapping presets
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

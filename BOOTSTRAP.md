# Bootstrap Guide

Canonical walkthrough for bootstrapping a new machine with homebase. This guide covers
both Bazzite Linux and macOS. If you're reading this months from now and have forgotten
everything, start here.

---

## Prerequisites

You need a **1Password account** with these items in your **Private** vault:

| Item name                  | Type / Fields                            | Purpose                                |
|----------------------------|------------------------------------------|----------------------------------------|
| `cautomaton-ssh-key`       | SSH Key: `private key`, `public key`     | SSH key pair for GitHub                |
| `github-pat`               | Login: `credential` field                | GitHub PAT (`repo` + `read:packages`)  |
| `cautomaton-homebase-gpg`  | Secure Note: `public.asc`, `secret.asc`  | GPG key for `~/.authinfo.gpg`          |

These item names are configured at the top of each bootstrap script (`OP_SSH_KEY`,
`OP_GITHUB_PAT`, `OP_GPG_KEY`). Change them there if your items are named differently.

You also need **network access** to GitHub, Homebrew, 1Password, and (for Nix)
the Determinate Systems installer.

---

## macOS

### Quick Start

The script is self-contained — no repo checkout needed. Copy-paste into a fresh terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/farra/homebase/main/bootstrap/macos.sh -o /tmp/macos.sh
bash /tmp/macos.sh
```

Or with a profile: `bash /tmp/macos.sh gamedev`

### Phases

The script runs 8 idempotent phases, each guarded by a stamp file in `~/.homebase-bootstrap/`.
Completed phases are skipped on re-run.

| Phase | What | Details |
|-------|------|---------|
| 1. Homebrew | Package manager | `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel) |
| 2. Bootstrap tools | `chezmoi`, `1password-cli`, `gnupg` | Minimum needed before chezmoi can clone the repo and import GPG keys |
| 3. 1Password | `op signin` | Opens browser for authentication. Verifies vault access. |
| 4. GPG keys | Import from 1Password | Public + secret key for `~/.authinfo.gpg` encryption |
| 5. Dotfiles | `chezmoi init --apply` | Clones homebase repo, writes SSH keys, applies all config, clones `~/forge`. See [What chezmoi apply Does](#what-chezmoi-apply-does). |
| 6. Host tools | Full `brew bundle` | Remaining formulas (`just`, `direnv`, `node`, `gum`), casks (`tailscale`, Nerd Fonts, extra fonts). Sets zsh as default shell if needed. |
| 7. Nix | Determinate Systems installer | Native macOS install. Enables flakes by default. |
| 8. Dev tools | `nix profile add` from flake | Same tools as the Linux distrobox image (ripgrep, fd, fzf, bat, eza, starship, emacs+vterm, etc.) installed directly into `~/.nix-profile/`. |

The chosen profile (`base` or `gamedev`) is saved to `~/.homebase/profile` so
`homebase update` rebuilds the correct nix environment.

### After Bootstrap

```bash
# Open a NEW terminal (so zsh + starship + all nix tools load)

# First-time setup: workspace dirs + Doom Emacs + AI agents
homebase setup

# Verify tools
which emacs rg fd fzf bat just direnv chezmoi starship

# Connect to Tailscale (GUI app — open from Applications)
```

### 1Password Desktop App (recommended)

Install **1Password 8** from the App Store or 1password.com. Then enable CLI integration:

**Settings > Developer > CLI integration**

This lets the `op` CLI authenticate via Touch ID instead of manual sign-in. Without this,
you'll see auth prompts or failures on every new terminal window (because `.zshrc`
auto-loads runtime secrets via `op`).

### Gamedev on macOS

The Linux gamedev profile (Godot binary, dotnet-sdk, export templates) is baked into a
custom Containerfile and doesn't translate to macOS. Install the gamedev stack directly:

```bash
brew install --cask godot-mono
brew install dotnet
```

This variance is acceptable — the Containerfile gamedev layer is custom enough that
1:1 parity isn't worth the abstraction cost.

---

## Bazzite Linux

### Getting the Script to the Machine

The repo is public, so you can clone it directly:

```bash
# If git is available (e.g. from a previous install)
git clone https://github.com/farra/homebase.git ~/homebase-bootstrap
cd ~/homebase-bootstrap && bash bootstrap/bazzite.sh
```

If git isn't available yet, copy `bootstrap/bazzite.sh` to the machine via USB, SCP,
or copy-paste. The script needs to run from within the repo (it references
`scripts/render-brewfile.sh` and `homebase.toml`).

### Phases

The script runs 9 idempotent phases, each guarded by a stamp file in `~/.homebase-bootstrap/`.

| Phase | What | Details |
|-------|------|---------|
| 1. Homebrew | Package manager | Installs to `~/.linuxbrew` (no root, no rpm-ostree) |
| 2. Host tools | `brew bundle` + shell | Formulas from `[host].tools`, `1password-cli` cask, sets zsh as default shell via `chsh` |
| 3. 1Password | `op signin` | Opens browser for authentication. Verifies vault access. |
| 4. GPG keys | Import from 1Password | Public + secret key for `~/.authinfo.gpg` encryption |
| 5. Dotfiles | `chezmoi init --apply` | Same as macOS — clones repo, writes SSH keys, applies config, clones `~/forge`. See [What chezmoi apply Does](#what-chezmoi-apply-does). |
| 6. Fonts | Download Nerd Fonts + extras | FiraCode, FiraMono to `~/.local/share/fonts/NerdFonts/`. Extra fonts (Lato, iA Writer) from URLs in `homebase.toml`. Runs `fc-cache`. |
| 7. Distrobox | Pull image + create container | Logs into GHCR, pulls baked image, creates `home` distrobox. Mounts `/home/linuxbrew` into container. |
| 8. Tailscale | Enable daemon | `systemctl enable --now tailscaled`. You still need to run `sudo tailscale up` manually. |
| 9. Flatpaks | Install desktop apps | Apps from `[flatpaks]` in homebase.toml (Obsidian, Discord, Zed, etc.) |

### After Bootstrap

```bash
# Enter the dev environment (all tools pre-installed in the image)
distrobox enter home

# First-time setup: workspace dirs + Doom Emacs + AI agents
homebase setup

# Export Emacs to the KDE desktop
homebase doom-export

# Verify tools (inside distrobox)
which emacs rg fd fzf bat just direnv chezmoi starship

# Connect to Tailscale
sudo tailscale up
```

### Note: Bazzite Requires the Repo

Unlike the macOS script (which is self-contained), `bazzite.sh` must run from within
the repo checkout because phase 2 uses `scripts/render-brewfile.sh` and `homebase.toml`
before chezmoi has cloned the repo. This is a known limitation — the macOS script avoids
it by deferring the full Brewfile to after chezmoi apply.

---

## Re-running / Resuming

Both scripts are fully idempotent. Completed phases are skipped:

```bash
bash bootstrap/macos.sh     # Skips all completed phases
bash bootstrap/bazzite.sh   # Same
```

To re-run a specific phase, delete its stamp file:

```bash
ls ~/.homebase-bootstrap/                    # See completed phases
rm ~/.homebase-bootstrap/05-dotfiles         # Re-run dotfiles phase
bash bootstrap/macos.sh                      # Only phase 5 runs
```

---

## What chezmoi apply Does

A single `chezmoi apply` handles all of these (on both platforms):

| What               | How                                                                     |
|--------------------|-------------------------------------------------------------------------|
| SSH keys           | `private_dot_ssh/` templates + `run_once_before_` script from 1Password |
| SSH config         | `private_dot_ssh/config.tmpl` — `UseKeychain yes` on macOS             |
| Git config         | `dot_gitconfig.tmpl` — name, email, signing                            |
| Shell config       | `dot_zshrc.tmpl` — zsh + starship + plugins + aliases (platform-aware) |
| Login checks       | `dot_zprofile` — chezmoi sync status on all platforms, nix daemon in distrobox |
| Starship prompt    | `dot_config/starship.toml` — Nerd Font Symbols + nix shell detection   |
| Doom Emacs config  | `dot_config/doom/` — packages, config, init                            |
| Emacs auth-source  | `run_onchange_create-authinfo-gpg.sh.tmpl` — GPG-encrypted `~/.authinfo.gpg` |
| Forge repo         | `.chezmoiexternal.toml` — `git clone` to `~/forge`                     |
| Homebase justfile  | `dot_homebase/justfile` — user commands, worktrees, updates             |
| GitHub CLI         | `dot_config/gh/config.yml` — aliases and settings                      |
| AI tool configs    | `dot_claude/`, `dot_codex/`, `dot_gemini/` — settings (not credentials)|

Externals (forge clone) run after file templates, so SSH keys are already on disk
when the git clone happens.

---

## Updating

After initial bootstrap, use the `homebase` alias to keep the machine current.
This is what you run when you sit down at a machine after working elsewhere:

```bash
homebase update                # Everything: dotfiles + brew + nix tools + flatpaks + agents
```

Or update individual layers:

```bash
homebase update-dotfiles       # Pull + apply latest dotfiles (chezmoi update)
homebase update-host           # Homebrew bundle (host tools + casks)
homebase update-nix-tools      # Rebuild nix profile from latest flake (macOS only)
homebase update-flatpaks       # Update Flatpak apps (Linux only)
homebase agent update          # Update AI agents (claude, codex, gemini, ACP)
homebase box rebuild           # Pull fresh image + recreate container (Linux only)
```

On macOS, the flow is: `chezmoi update` pulls the latest flake.nix + homebase.toml
from git, then `update-nix-tools` rebuilds the nix profile from the updated flake.
This is how changes made on your Bazzite workstation propagate to the Mac.

On Linux, dev tools live in the container image (rebuilt by CI). Run `homebase box rebuild`
to pull the latest image.

---

## Verification Checklist

### Host (all platforms)

- [ ] `brew --version` works
- [ ] `echo $SHELL` shows zsh
- [ ] `op account list` shows your account
- [ ] `ssh -T git@github.com` authenticates as `farra`
- [ ] `ls -la ~/.ssh/id_ed25519` — permissions `600`
- [ ] `git config user.name` returns your name
- [ ] `gpg --list-secret-keys` shows the homebase GPG key
- [ ] `ls -la ~/.authinfo.gpg` exists
- [ ] `chezmoi status` shows no pending changes
- [ ] `~/forge/` exists and is a git repo
- [ ] `~/.homebase/justfile` exists
- [ ] `homebase` alias works (try `homebase --list`)

### macOS specific

- [ ] `nix --version` works
- [ ] `which rg fd fzf bat eza starship emacs` — all resolve to `~/.nix-profile/bin/`
- [ ] `starship --version` runs
- [ ] `cat ~/.homebase/profile` shows `base` or `gamedev`
- [ ] Tailscale app opens from Applications
- [ ] Nerd Fonts visible in terminal font picker (FiraCode Nerd Font)
- [ ] 1Password desktop app: Settings > Developer > CLI integration is enabled

### Bazzite specific

- [ ] `distrobox enter home` works
- [ ] `which brew` — host Homebrew available inside container
- [ ] `which emacs rg fd fzf bat just direnv chezmoi starship nu` — all found
- [ ] `emacs --version` runs
- [ ] `homebase doom-export` — Emacs appears in KDE desktop menu
- [ ] `ls ~/.local/share/fonts/NerdFonts/` shows FiraCode and FiraMono files
- [ ] `tailscale status` shows connected
- [ ] Flatpak apps installed (check `flatpak list`)

### Shell (all platforms)

- [ ] Starship prompt shows git branch in a repo
- [ ] `nix develop` inside a project shows nix indicator in prompt
- [ ] Tab completion works (case-insensitive)
- [ ] Typing shows autosuggestions (ghost text from history)
- [ ] Invalid commands highlighted red, valid commands green
- [ ] `homebase setup` completes (workspace dirs + Doom Emacs + AI agents)
- [ ] `doom doctor` — no critical issues

### Idempotency

- [ ] Re-run bootstrap script — all phases skip
- [ ] Re-run `chezmoi apply` — no changes

---

## macOS vs Bazzite Architecture

On macOS there's no distrobox. Dev tools from `[container].packages` in homebase.toml
are installed directly via `nix profile add` rather than baked into a container image.
The same `flake.nix` (reading the same `homebase.toml`) drives both paths, so tool
parity is maintained.

| Layer | Bazzite | macOS |
|-------|---------|-------|
| Host tools | Homebrew (`~/.linuxbrew`) | Homebrew (`/opt/homebrew`) |
| Dev tools | Distrobox image (Nix inside) | Nix profile (native) |
| Desktop apps | Flatpak | Homebrew casks |
| Fonts | Manual download to `~/.local/share/fonts/` | Homebrew cask |
| Emacs | Nix in distrobox, exported to host | Nix profile |
| Per-project envs | `nix develop` | `nix develop` |

---

## Architecture Notes

### Why chezmoi clones via HTTPS (then switches to SSH)

SSH keys don't exist until *after* `chezmoi apply` writes them from 1Password. So the
bootstrap uses a PAT-embedded HTTPS URL for the initial clone. After apply, the script
switches the chezmoi remote to SSH. All subsequent `chezmoi update` calls use the SSH
key — no PAT needed.

### Why the distrobox image is baked (Linux)

All tools are pre-installed via Nix during the container image build. `distrobox enter home`
gives you a fully equipped environment immediately — no bootstrap step inside the container.
Doom Emacs and AI agents install into `$HOME` (via `homebase setup`) since they persist
across container rebuilds.

### distrobox shares $HOME and Homebrew (Linux)

The `home` distrobox bind-mounts your real `$HOME`. Dotfiles applied by chezmoi on the
host are visible inside the container. SSH keys, git config, fonts, all configs work in
both contexts.

Homebrew installs to `/home/linuxbrew/.linuxbrew` (outside `$HOME`). The distrobox is
created with `--volume /home/linuxbrew:/home/linuxbrew` so `brew` works inside the
container too.

### 1Password vault name

1Password's default vault is "Private" (not "Personal"). All templates use
`op://Private/...`.

### Three copies of dotfiles

There are three copies of managed files:
1. **Live file** — e.g. `~/.config/doom/config.el`
2. **chezmoi source** — `~/.local/share/chezmoi/dot_config/doom/config.el`
3. **Dev worktree** — `~/dev/me/homebase/dot_config/doom/config.el`

Changes in the dev worktree must be pushed to git and pulled into the chezmoi source
separately. Use `chezmoi re-add <file>` to copy live files back into the chezmoi source.

---

## Troubleshooting

### 1Password CLI won't authenticate

```bash
op account list          # Check if an account is configured
eval "$(op signin)"      # Re-authenticate (browser/Touch ID)
op whoami                # Verify session is active
```

On macOS: make sure 1Password desktop app is running and CLI integration is enabled
(Settings > Developer > CLI integration).

### SSH key not working

```bash
ssh -T git@github.com    # Test authentication
ls -la ~/.ssh/            # id_ed25519 should be 600, pub should be 644
ssh-add -l               # Check if key is loaded in agent
```

On macOS: if the key doesn't persist across reboots, verify `~/.ssh/config` has
`UseKeychain yes` and `AddKeysToAgent yes` (managed by chezmoi).

### chezmoi template errors

```bash
chezmoi diff             # Preview what chezmoi would change
chezmoi doctor           # Check chezmoi health
chezmoi status           # Show files that differ from source
```

### Distrobox image pull fails (Linux)

If GHCR is unreachable or the image isn't published, build locally:

```bash
cd ~/dev/me/homebase     # or wherever the repo is checked out
just build-image
homebase box create
```

### Forge clone fails during chezmoi apply

SSH keys must be installed before the forge clone (which uses SSH). chezmoi handles
this ordering automatically (`run_once_before_` scripts run before externals). If it
still fails:

```bash
ssh -T git@github.com    # Verify SSH works
chezmoi apply            # Re-run (the external clone will retry)
```

### Starship prompt not showing

```bash
which starship           # Should be in ~/.nix-profile/bin/
starship --version       # Verify it runs
cat ~/.config/starship.toml           # Check config exists
cat ~/.config/starship.conservative.toml  # Default profile
```

If starship is missing, the nix profile may not be installed:

```bash
# macOS: reinstall nix tools
rm ~/.homebase-bootstrap/08-nix-tools
bash bootstrap/macos.sh

# Linux: enter distrobox (tools are in the image)
distrobox enter home
```

### Nix tools missing or outdated (macOS)

```bash
homebase update-nix-tools    # Rebuild from latest flake
# Or manually:
nix profile list             # See what's installed
nix profile add ~/.local/share/chezmoi#homebase-base-env
```

---

## Post-Bootstrap: Working with Worktrees

Use `homebase` to manage projects via git worktrees. Bare clones live hidden in
`~/dev/.worktrees/`; working copies are checked out into group dirs.

### First-time setup for a project

```bash
homebase clone farra/homebase          # bare clone → .worktrees/homebase.git
homebase clone farra/agentboxes        # bare clone → .worktrees/agentboxes.git
homebase clone jamandtea/some-project  # bare clone → .worktrees/some-project.git
```

### Starting work (one worktree per task/agent)

```bash
homebase wt homebase fix-auth          # → ~/dev/me/homebase-fix-auth (new branch)
homebase wt homebase add-search        # → ~/dev/me/homebase-add-search (new branch)
homebase wt some-project refactor jmt  # → ~/dev/jmt/some-project-refactor
```

Each worktree gets its own branch. Open a persp-mode workspace in Emacs for each,
spawn an agent-shell session, and the agent works in isolation.

### Checking status

```bash
homebase wts        # list all active worktrees across all bare clones
homebase clones     # list all bare clones
```

### Finishing work

```bash
homebase wt-rm me/homebase-fix-auth   # removes worktree, keeps branch
```

The branch and any pushed commits survive. The directory is disposable.

---

## Open Issues

- [ ] **Bazzite script requires repo checkout** — unlike macOS, `bazzite.sh` can't be
  curled standalone (phase 2 needs the Brewfile renderer). Could restructure like macOS
  (defer full brew bundle to after chezmoi).
- [ ] **GHCR package visibility** — may need `podman login` or GitHub package visibility
  settings for private images.

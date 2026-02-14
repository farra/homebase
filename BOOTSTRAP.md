# Bootstrap Guide

Canonical walkthrough for bootstrapping a new machine with homebase.

## Prerequisites

1. **1Password account** with these items in your **Private** vault:

   | Item                      | Field/Files                | Purpose                                         |
   |---------------------------|----------------------------|-------------------------------------------------|
   | `cautomaton-ssh-key`      | `private key`, `public key`| SSH key pair                                    |
   | `github-pat`              | `credential`               | GitHub PAT with `repo` + `read:packages` scopes |
   | `cautomaton-homebase-gpg` | `public.asc`, `secret.asc` | GPG key for encrypting `~/.authinfo.gpg`        |

2. **Network access** to GitHub, Homebrew, and 1Password

## Bazzite (Primary Target)

### Getting the Script to the Machine

Since the repo is private, you can't `curl` the bootstrap script. Options:
- Copy-paste from another machine
- USB drive
- SCP from an already-bootstrapped machine
- Dropbox / cloud storage

### Running the Bootstrap

```bash
bash bazzite.sh
```

The script runs 7 idempotent phases, each guarded by a stamp file in `~/.homebase-bootstrap/`:

**Phase 1: Homebrew** — Installs to `~/.linuxbrew` (no root, no rpm-ostree)

**Phase 2: Host tools** — `brew install chezmoi just direnv git zsh 1password-cli`. Sets zsh as default shell via `chsh` (distrobox inherits host `$SHELL`).

**Phase 3: 1Password** — `op signin` (opens browser for authentication)

**Phase 4: GPG keys** — Imports public and secret GPG keys from 1Password for authinfo encryption

**Phase 5: Dotfiles** — Retrieves GitHub PAT from 1Password, runs `chezmoi init --apply` with PAT-embedded HTTPS URL. This:
  - Clones the private repo via HTTPS (no SSH needed yet)
  - Writes SSH keys to `~/.ssh/` from 1Password templates
  - Switches chezmoi remote to SSH (so future `chezmoi update` uses SSH key, no PAT needed)
  - Applies all dotfiles (zshrc, gitconfig, starship, Doom Emacs config)
  - Creates encrypted `~/.authinfo.gpg` for Emacs/magit (GitHub PAT from 1Password, GPG-encrypted)
  - Clones `~/forge` via `.chezmoiexternal.toml`
  - Installs `~/.homebase/justfile` (user commands + worktree lifecycle)
  - Installs AI tool configs (claude, codex, gemini settings)

**Phase 6: Fonts** — Downloads FiraCode and FiraMono Nerd Fonts to `~/.local/share/fonts/NerdFonts/`

**Phase 7: Distrobox** — Logs into GHCR with the PAT, pulls the baked image, creates distrobox `home`. Mounts host Homebrew (`/home/linuxbrew`) into the container so `brew` works inside distrobox.

### After Bootstrap

```bash
# Enter the dev environment (all tools pre-installed)
distrobox enter home

# First-time setup (workspace dirs + Doom Emacs + AI agents)
homebase setup

# Export Emacs to the KDE desktop
homebase doom-export

# Verify tools
which emacs rg fd fzf bat just direnv chezmoi starship
starship --version
```

### Re-running

The script is fully idempotent. Completed phases are skipped:

```bash
bash bazzite.sh    # Skips all completed phases
```

To re-run a specific phase, delete its stamp file:

```bash
ls ~/.homebase-bootstrap/    # See completed phases
rm ~/.homebase-bootstrap/05-dotfiles    # Re-run dotfiles phase
bash bazzite.sh
```

---

## macOS (Future)

Manual steps until a bootstrap script is written.

### Steps

```bash
# 1. Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. Core tools + 1Password
brew install chezmoi
brew install --cask 1password-cli

# 3. Authenticate
eval "$(op signin)"

# 4. Import GPG key for authinfo encryption
op read "op://Private/cautomaton-homebase-gpg/homebase-authinfo-public.asc" | gpg --batch --import
op read "op://Private/cautomaton-homebase-gpg/homebase-authinfo-secret.asc" | gpg --batch --import
echo "48CF4CDEC93AE47B93491C7A43EBD702731ECFAC:6:" | gpg --batch --import-ownertrust

# 5. Dotfiles (SSH keys, forge clone, encrypted authinfo, all configs)
chezmoi init --apply farra/homebase

# 6. Remaining Homebrew packages (including Nerd Fonts)
brew bundle --file=~/.local/share/chezmoi/Brewfile

# 7. Nix (for project-level shells)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

On macOS there's no distrobox — Nix runs natively. Use `just dev` for a nix develop shell, or use per-project flakes via cautomaton-develops.

---

## WSL / Fedora (Future)

Same flow as Bazzite. The `bazzite.sh` script should work on WSL Fedora with minimal changes (Homebrew path is the same).

---

## What chezmoi apply Does

A single `chezmoi apply` handles:

| What               | How                                                                     |
|--------------------|-------------------------------------------------------------------------|
| SSH keys           | `private_dot_ssh/` templates → 1Password `onepasswordRead`              |
| Git config         | `dot_gitconfig.tmpl` → templated with name/email                        |
| Shell config       | `dot_zshrc.tmpl` → zsh + starship + plugins + aliases                   |
| Login checks       | `dot_zprofile` → distrobox entry checks (chezmoi sync status)           |
| Starship prompt    | `dot_config/starship.toml` → Nerd Font Symbols + nix shell detection    |
| Doom Emacs config  | `dot_config/doom/`                                                      |
| Emacs auth-source  | `run_onchange_create-authinfo-gpg.sh.tmpl` → GPG-encrypted `~/.authinfo.gpg` |
| Forge repo         | `.chezmoiexternal.toml` → `git clone` to `~/forge`                      |
| Homebase justfile  | `dot_homebase/justfile` → `~/.homebase/justfile` (user commands + worktrees) |
| GitHub CLI         | `dot_config/gh/config.yml` → aliases and settings                       |
| AI tool configs    | `dot_claude/`, `dot_codex/`, `dot_gemini/` → settings (not credentials) |

Externals (forge clone) run after file templates, so SSH keys are already on disk when the git clone happens.

---

## Verification Checklist

### Host (Layer 0)

- [ ] `brew --version` works
- [ ] `echo $SHELL` shows zsh
- [ ] `op account list` shows your account
- [ ] `ssh -T git@github.com` authenticates as `farra`
- [ ] `ls -la ~/.ssh/id_rsa` shows permissions `600`
- [ ] `git config user.name` returns your name
- [ ] `gpg --list-secret-keys` shows the homebase key
- [ ] `ls -la ~/.authinfo.gpg` exists (GPG-encrypted)
- [ ] `chezmoi status` shows no pending changes
- [ ] `~/forge/` exists and is a git repo
- [ ] `ls ~/.local/share/fonts/NerdFonts/` shows FiraCode and FiraMono files
- [ ] `~/.homebase/justfile` exists

### Distrobox (Layer 1, Linux only)

- [ ] `distrobox enter home` works
- [ ] `which brew` — host Homebrew available via volume mount
- [ ] `which emacs rg fd fzf bat just direnv chezmoi starship` — all found
- [ ] `which nu` — nushell available
- [ ] `emacs --version` runs
- [ ] `starship --version` runs
- [ ] `homebase setup` — workspace dirs + Doom + agents install
- [ ] `doom doctor` — no critical issues
- [ ] `homebase doom-export` — Emacs appears in desktop menu
- [ ] Doom Emacs loads without errors from missing `~/forge/` paths

### Shell

- [ ] Starship prompt shows git branch in a repo
- [ ] `nix develop` inside a project shows nix indicator in prompt
- [ ] Tab completion works (case-insensitive)
- [ ] Typing shows autosuggestions (ghost text from history)
- [ ] Invalid commands highlighted red, valid commands green

### Idempotency

- [ ] Re-run `bash bazzite.sh` — all phases skip
- [ ] Re-run `chezmoi apply` — no changes

---

## Updating

After initial bootstrap, use the `homebase` alias:

```bash
homebase update             # Update everything (dotfiles + host tools + agents)
homebase update-dotfiles    # Just dotfiles
homebase update-host        # Just Homebrew
homebase update-agents      # Just AI agents (claude, codex, gemini)
homebase distrobox-rebuild  # Pull fresh image + recreate container
```

---

## Post-Bootstrap: Working with Worktrees

Use `homebase` to manage projects via git worktrees. Bare clones live hidden in `~/dev/.worktrees/`; working copies are checked out into group dirs where Emacs and agents operate.

### First-time setup for a project

```bash
homebase clone farra/homebase          # bare clone → .worktrees/homebase.git
homebase clone farra/agentboxes        # bare clone → .worktrees/agentboxes.git
homebase clone jamandtea/some-project  # bare clone → .worktrees/some-project.git
```

### Starting work (one worktree per task/agent)

```bash
homebase wt homebase fix-auth          # → me/homebase-fix-auth (new branch)
homebase wt homebase add-search        # → me/homebase-add-search (new branch)
homebase wt some-project refactor jmt  # → jmt/some-project-refactor
```

Each worktree gets its own branch. Open a persp-mode workspace in Emacs for each, spawn an agent-shell session, and the agent works in isolation.

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

## Troubleshooting

### 1Password CLI won't authenticate

```bash
op account list          # Check if signed in
eval "$(op signin)"      # Re-authenticate
```

### SSH key permissions wrong

chezmoi sets these automatically, but verify:
```bash
ls -la ~/.ssh/
# id_rsa should be 600, id_rsa.pub should be 644
```

### chezmoi template errors

```bash
chezmoi diff             # Preview what chezmoi will do
chezmoi execute-template < ~/.local/share/chezmoi/private_dot_ssh/private_id_rsa.tmpl
```

### Distrobox image pull fails

If GHCR is unreachable or the image isn't published, build locally:
```bash
cd ~/dev/homebase   # or wherever the repo is checked out
just build-image
homebase distrobox-create
```

### Forge clone fails during chezmoi apply

If SSH keys aren't working yet (first apply), chezmoi external will fail. Fix:
```bash
# Verify SSH works first
ssh -T git@github.com

# Then re-apply
chezmoi apply
```

### Starship prompt not showing

```bash
which starship           # Should be in ~/.nix-profile/bin/
starship --version       # Verify it runs
cat ~/.config/starship.toml   # Check config exists
```

---

## Architecture Notes

### Why chezmoi clones via HTTPS (then switches to SSH)

`chezmoi init farra/homebase` uses HTTPS, not SSH. This is intentional — SSH keys don't exist until *after* `chezmoi apply` writes them. The bootstrap script uses a PAT-embedded URL for the private repo, then automatically switches the remote to SSH once keys are installed. All subsequent `chezmoi update` calls use SSH — no PAT needed.

### Why the image is baked

All tools are pre-installed via Nix in the container image. `distrobox enter home` gives you a fully equipped environment immediately — no bootstrap step inside the container. Only Doom Emacs and AI agents install into `$HOME` (via `homebase setup`) since they persist across container rebuilds.

### distrobox shares $HOME (and Homebrew)

The `home` distrobox bind-mounts your real `$HOME`. Dotfiles applied by chezmoi on the host are visible inside the container. SSH keys, git config, fonts, and all configs work in both contexts.

On Linux, Homebrew installs to `/home/linuxbrew/.linuxbrew` (outside `$HOME`). The distrobox is created with `--volume /home/linuxbrew:/home/linuxbrew` so `brew` is available inside the container too. The zshrc automatically detects this path and adds it to `$PATH`.

### 1Password vault name

1Password's default vault is "Private" (not "Personal"). All templates use `op://Private/...`.

---

## Open Issues

- [ ] **1Password CLI via Homebrew on Linux** — `brew install 1password-cli` needs verification. Fallback: direct binary download to `~/.local/bin/`
- [ ] **GHCR package visibility** — Private repo defaults to private packages. May need `podman login` (which the bootstrap script does) or package visibility settings in GitHub
- [ ] **Nothing tested on clean machines** — Full flow is untested on fresh Bazzite, WSL, or macOS

# Bootstrap Guide

Canonical walkthrough for bootstrapping a new machine with homebase.

## Prerequisites

1. **1Password account** with these items in your **Private** vault:

   | Item                 | Field         | Purpose                                         |
   |----------------------|---------------|-------------------------------------------------|
   | `cautamaton-ssh-key` | `private key` | SSH private key                                 |
   | `cautamaton-ssh-key` | `public key`  | SSH public key                                  |
   | `github-pat`         | `credential`  | GitHub PAT with `repo` + `read:packages` scopes |

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

The script runs 5 idempotent phases, each guarded by a stamp file in `~/.homebase-bootstrap/`:

**Phase 1: Homebrew** — Installs to `~/.linuxbrew` (no root, no rpm-ostree)

**Phase 2: Host tools** — `brew install chezmoi just direnv git zsh 1password-cli`

**Phase 3: 1Password** — `op signin` (opens browser for authentication)

**Phase 4: Dotfiles** — Retrieves GitHub PAT from 1Password, runs `chezmoi init --apply` with PAT-embedded HTTPS URL. This:
  - Clones the private repo via HTTPS (no SSH needed yet)
  - Writes SSH keys to `~/.ssh/` from 1Password templates
  - Applies all dotfiles (git config, zsh config, Doom Emacs config)
  - Clones `~/forge` via `.chezmoiexternal.toml`
  - Creates `~/dev/{me,jmt,ref}` via `run_once_` script

**Phase 5: Distrobox** — Logs into GHCR with the PAT, pulls the baked image, creates distrobox `home`

### After Bootstrap

```bash
# Enter the dev environment (all tools pre-installed)
distrobox enter home

# First-time container setup (installs Doom Emacs)
cd ~/.homebase && just setup

# Export Emacs to the KDE desktop
just doom-export

# Verify tools
which emacs rg fd fzf bat just direnv chezmoi
```

### Re-running

The script is fully idempotent. Completed phases are skipped:

```bash
bash bazzite.sh    # Skips all completed phases
```

To re-run a specific phase, delete its stamp file:

```bash
ls ~/.homebase-bootstrap/    # See completed phases
rm ~/.homebase-bootstrap/04-dotfiles    # Re-run dotfiles phase
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

# 4. Dotfiles (SSH keys, forge clone, workspace dirs — all handled)
chezmoi init --apply farra/homebase

# 5. Remaining Homebrew packages
brew bundle --file=~/.local/share/chezmoi/Brewfile

# 6. Nix (for project-level shells)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

On macOS there's no distrobox — Nix runs natively. Use `just dev` for a nix develop shell, or use per-project flakes via cautomaton-develops.

---

## WSL / Fedora (Future)

Same flow as Bazzite. When ready, the `bazzite.sh` script should work on WSL Fedora with minimal changes (Homebrew path is the same).

---

## What chezmoi apply Does

A single `chezmoi apply` handles:

| What               | How                                                                     |
|--------------------|-------------------------------------------------------------------------|
| SSH keys           | `private_dot_ssh/` templates → 1Password `onepasswordRead`              |
| Git config         | `dot_gitconfig.tmpl` → templated with name/email                        |
| Shell config       | `dot_zshrc.tmpl`                                                        |
| Doom Emacs config  | `dot_config/doom/`                                                      |
| Forge repo         | `.chezmoiexternal.toml` → `git clone` to `~/forge`                      |
| Workspace dirs     | `run_once_create-workspace.sh` → `~/dev/{.worktrees,me,jmt,ref}`        |
| Workspace justfile | `dev/justfile` → `~/dev/justfile` (worktree lifecycle commands)         |
| Container justfile | `dot_homebase/justfile` → `~/.homebase/justfile` (Doom install, etc.)   |
| AI tool configs    | `dot_claude/`, `dot_codex/`, `dot_gemini/` → settings (not credentials) |

Externals (forge clone) run after file templates, so SSH keys are already on disk when the git clone happens.

---

## Verification Checklist

### Host (Layer 0)

- [ ] `brew --version` works
- [ ] `op account list` shows your account
- [ ] `ssh -T git@github.com` authenticates as `farra`
- [ ] `ls -la ~/.ssh/id_rsa` shows permissions `600`
- [ ] `git config user.name` returns your name
- [ ] `chezmoi status` shows no pending changes
- [ ] `~/forge/` exists and is a git repo
- [ ] `~/dev/.worktrees/`, `~/dev/me/`, `~/dev/jmt/`, `~/dev/ref/` exist
- [ ] `~/dev/justfile` exists (worktree commands)

### Distrobox (Layer 1, Linux only)

- [ ] `distrobox enter home` works
- [ ] `which emacs rg fd fzf bat just direnv chezmoi` — all found
- [ ] `emacs --version` runs (should include vterm support)
- [ ] `cd ~/.homebase && just setup` — Doom installs successfully
- [ ] `doom doctor` — no critical issues
- [ ] `just doom-export` — Emacs appears in desktop menu
- [ ] Doom Emacs loads without errors from missing `~/forge/` paths

### Idempotency

- [ ] Re-run `bash bazzite.sh` — all phases skip
- [ ] Re-run `chezmoi apply` — no changes

---

## Post-Bootstrap: Working with Worktrees

After bootstrap, use the workspace justfile at `~/dev/justfile` to manage projects via git worktrees. Bare clones live hidden in `~/dev/.worktrees/`; working copies are checked out into group dirs where Emacs and agents operate.

### First-time setup for a project

```bash
cd ~/dev
just clone farra/homebase          # bare clone → .worktrees/homebase.git
just clone farra/agentboxes        # bare clone → .worktrees/agentboxes.git
just clone jamandtea/some-project  # bare clone → .worktrees/some-project.git
```

### Starting work (one worktree per task/agent)

```bash
cd ~/dev
just wt homebase fix-auth          # → me/homebase-fix-auth (new branch)
just wt homebase add-search        # → me/homebase-add-search (new branch)
just wt some-project refactor jmt  # → jmt/some-project-refactor
```

Each worktree gets its own branch. Open a persp-mode workspace in Emacs for each, spawn an agent-shell session, and the agent works in isolation.

### Checking status

```bash
cd ~/dev
just wts        # list all active worktrees across all bare clones
just clones     # list all bare clones
```

### Finishing work

```bash
cd ~/dev
just wt-rm me/homebase-fix-auth   # removes worktree, keeps branch
```

The branch and any pushed commits survive. The directory is disposable.

### What's next

The worktree justfile handles the git plumbing. The Emacs layer (elisp, likely `forge-agent-worktree.el`) will wrap this with:
- `forge-agent-start` — prompts for project + task, creates worktree + persp workspace + agent session
- `forge-agent-finish` — commits, pushes, cleans up worktree + workspace
- `forge-agent-list` — dashboard of active agent worktrees and their status

Forge stays a regular clone at `~/forge` — it doesn't follow the worktree pattern.

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
just build-image
distrobox create --image ghcr.io/farra/homebase:latest --name home
```

### Forge clone fails during chezmoi apply

If SSH keys aren't working yet (first apply), chezmoi external will fail. Fix:
```bash
# Verify SSH works first
ssh -T git@github.com

# Then re-apply
chezmoi apply
```

---

## Architecture Notes

### Why chezmoi clones via HTTPS

`chezmoi init farra/homebase` uses HTTPS, not SSH. This is intentional — SSH keys don't exist until *after* `chezmoi apply` writes them. The bootstrap script uses a PAT-embedded URL for the private repo. After bootstrap, the remote can be switched to SSH:

```bash
cd ~/.local/share/chezmoi
git remote set-url origin git@github.com:farra/homebase.git
```

### Why the image is baked

The old flow required `just bootstrap` inside the distrobox to install tools via `nix profile`. The new baked image has everything pre-installed — `distrobox enter home` gives you a fully equipped environment immediately.

### distrobox shares $HOME

The `home` distrobox bind-mounts your real `$HOME`. Dotfiles applied by chezmoi on the host are visible inside the container. SSH keys, git config, and Doom Emacs config all work in both contexts.

### 1Password vault name

1Password's default vault is "Private" (not "Personal"). All templates use `op://Private/...`.

---

## Open Issues

- [ ] **1Password CLI via Homebrew on Linux** — `brew install 1password-cli` needs verification. Fallback: direct binary download to `~/.local/bin/`
- [ ] **GHCR package visibility** — Private repo defaults to private packages. May need `podman login` (which the bootstrap script does) or package visibility settings in GitHub
- [ ] **Nothing tested on clean machines** — Full flow is untested on fresh Bazzite, WSL, or macOS

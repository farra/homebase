# Bootstrap Guide

This is the canonical walkthrough for bootstrapping a new machine with homebase.

## Prerequisites

Before you begin, ensure you have:

1. **1Password account** with these items in your Private vault:
   - `cautamaton-ssh-key` — SSH key (with `private key` and `public key` fields)
   - `GITHUB_TOKEN` — GitHub personal access token

2. **Network access** — Need to reach GitHub, Homebrew, and 1Password

## Quick Reference

| Platform | Time | Reboots |
|----------|------|---------|
| macOS | ~10 min | 0 |
| WSL (Fedora) | ~15 min | 0 |
| Bazzite | ~15 min | 0 |

---

## Shared Steps (All Platforms)

These steps are identical across macOS, WSL, and Bazzite.

### Step 1: Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the post-install instructions to add Homebrew to your PATH.

**macOS:**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Linux/WSL:**
```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

### Step 2: Install chezmoi and 1Password CLI

```bash
brew install chezmoi 1password-cli
```

### Step 3: Authenticate to 1Password

```bash
eval $(op signin)
```

This opens a browser or prompts for your master password. You should now be able to run `op vault list` and see your vaults.

### Step 4: Bootstrap with chezmoi

```bash
chezmoi init --apply farra/homebase
```

This single command:
- Clones the repo via HTTPS (no SSH needed yet)
- Runs templates that fetch SSH keys from 1Password
- Writes SSH keys to `~/.ssh/` with correct permissions
- Applies all dotfiles (git config, zsh config, etc.)

### Step 5: Verify SSH works

```bash
ssh -T git@github.com
```

Expected output: `Hi farra! You've successfully authenticated...`

### Step 6: Install Homebrew packages

```bash
brew bundle --file=~/.local/share/chezmoi/Brewfile
```

---

## Platform-Specific: macOS

After the shared steps, macOS is done for the host substrate.

### Optional: Install Nix (for project-level shells)

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

This enables `nix develop` for project-specific environments (see [cautomaton-develops](https://github.com/farra/cautomaton-develops)).

---

## Platform-Specific: WSL (Fedora)

After the shared steps, set up the distrobox dev environment.

### Step 7: Create the homebase distrobox

```bash
podman pull ghcr.io/farra/homebase:slim
distrobox create --image ghcr.io/farra/homebase:slim --name home
```

### Step 8: Bootstrap inside distrobox

```bash
distrobox enter home
just bootstrap
```

This installs Nix-based tools to `~/.nix-profile` inside the container. The tools persist across container recreations because `$HOME` is bind-mounted.

### Step 9: Export Emacs to host (optional)

From inside the distrobox:
```bash
distrobox-export --app emacs
```

Emacs will appear in your Windows Start menu via WSLg.

---

## Platform-Specific: Bazzite

Bazzite is an immutable Fedora variant. The flow is identical to WSL.

After the shared steps:

### Step 7: Create the homebase distrobox

```bash
podman pull ghcr.io/farra/homebase:slim
distrobox create --image ghcr.io/farra/homebase:slim --name home
```

### Step 8: Bootstrap inside distrobox

```bash
distrobox enter home
just bootstrap
```

### Step 9: Export Emacs to host

From inside the distrobox:
```bash
distrobox-export --app emacs
```

Emacs will appear in your desktop environment's application menu.

---

## Verification Checklist

After bootstrap, verify everything works:

- [ ] `git config user.name` returns your name
- [ ] `git config user.email` returns your email
- [ ] `ssh -T git@github.com` authenticates successfully
- [ ] `chezmoi status` shows no uncommitted changes
- [ ] `doom doctor` reports no critical issues (after Doom Emacs sync)

**Linux/WSL additional checks:**
- [ ] `distrobox enter home` works
- [ ] Inside distrobox: `which emacs` returns a path
- [ ] Exported apps appear in host menu

---

## Troubleshooting

### 1Password CLI won't authenticate

```bash
# Check if signed in
op account list

# Re-authenticate
eval $(op signin)
```

### SSH key permissions wrong

chezmoi should set these automatically, but verify:
```bash
ls -la ~/.ssh/
# id_rsa should be 600
# id_rsa.pub should be 644
```

### chezmoi template errors

Preview what chezmoi will do:
```bash
chezmoi diff
```

Check template output:
```bash
chezmoi execute-template < ~/.local/share/chezmoi/private_dot_ssh/private_id_rsa.tmpl
```

### Distrobox image pull fails

If ghcr.io is unreachable, build locally:
```bash
just build-slim
distrobox create --image localhost/homebase:slim --name home
```

---

## Post-Bootstrap

### Set up Doom Emacs

```bash
# macOS
brew install --cask emacs
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
~/.config/emacs/bin/doom install

# Linux (inside distrobox)
doom install
```

### Clone forge (optional)

```bash
git clone git@github.com:farra/forge.git ~/forge
```

### Configure runtime secrets

For API keys (Claude, OpenAI, etc.), see `secretspec.toml`. These are injected at runtime, not stored in dotfiles.

---

## Updating

After initial bootstrap, keep things in sync:

```bash
just sync      # Pull latest dotfiles and apply
just apply     # Apply without pulling
just re-add    # Stage local changes back to chezmoi
just push      # Commit and push dotfile changes
```

---

## Open Issues

Things that need resolution or haven't been tested yet.

### Blocking

- [ ] **Nothing tested on clean machines** — The entire flow is theoretical until validated on fresh WSL Fedora, Bazzite, and macOS installs

- [ ] **1Password CLI on Linux** — `brew install 1password-cli` may not work on Linux. Fedora may require the RPM:
  ```bash
  sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
  sudo dnf install 1password-cli
  ```
  Need to test and update Step 2 accordingly.

- [ ] **ghcr.io image not publishing** — Repo is private, so GitHub Actions may not be pushing to ghcr.io. Need to either:
  - Make repo public (templates don't contain secrets)
  - Configure GitHub Container Registry for private repos
  - Document local build as primary path

### Non-Blocking

- [ ] **Doom Emacs install is manual** — Post-bootstrap section requires manual git clone and `doom install`. Could be automated in `just bootstrap` or a separate `just doom` command.

- [ ] **secretspec + 1Password integration** — Runtime secrets (API keys) declared in `secretspec.toml` but no documentation on how to configure secretspec to use 1Password as provider.

- [ ] **WSL Fedora availability** — Is "Fedora" in the Microsoft Store, or does it require manual import? Document the exact install path.

- [ ] **Homebrew on immutable Linux** — Homebrew installs to `/home/linuxbrew/.linuxbrew` and may require `sudo` for initial setup. Bazzite's immutability might complicate this. Untested.

- [ ] **Time estimates are guesses** — The "~10 min / ~15 min" estimates in Quick Reference are not based on actual testing.

### Design Questions

- [ ] **Should Doom Emacs config be in homebase or separate?** — Currently `dot_config/doom/` is here, but Doom itself requires manual install. Is this the right split?

- [ ] **distrobox "home" vs project-specific containers** — Is one "home" distrobox the right model, or should there be per-project containers? (May be out of scope for homebase, belongs to cautomaton-develops)

---

## Call-Outs

Important notes for anyone using or maintaining this.

### chezmoi clones via HTTPS

The `chezmoi init farra/homebase` command uses HTTPS, not SSH. This is intentional — SSH keys don't exist yet. After `chezmoi apply`, the remote can be switched to SSH if desired:
```bash
cd ~/.local/share/chezmoi
git remote set-url origin git@github.com:farra/homebase.git
```

### Private vault name is "Private", not "Personal"

1Password's default vault is called "Private". All templates use `op://Private/...`. If you see "Personal" in examples, that's wrong.

### SSH key is shared across machines

One SSH key (`cautamaton-ssh-key`) is used everywhere. This is a simplicity trade-off. If a machine is compromised, rotate the key in 1Password and re-run `chezmoi apply` on all machines.

### Homebrew on Linux goes to ~/.linuxbrew

Unlike macOS (`/opt/homebrew`), Linux Homebrew installs to `/home/linuxbrew/.linuxbrew`. The PATH setup differs between platforms. The `dot_zshrc.tmpl` should handle this, but verify.

### distrobox shares $HOME

The `home` distrobox bind-mounts your real `$HOME`. Changes inside the container (like files in `~/.nix-profile`) persist. This is intentional — tools installed via `just bootstrap` survive container recreation.

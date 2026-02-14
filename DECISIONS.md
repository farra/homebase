# Open Decisions

Decisions that need resolution before homebase is ready for real use.

---

## 1. Secrets Provider (Critical Path) — DECIDED

**The Bootstrap Paradox:** Need SSH keys to clone private repo, but keys are in the repo.

### Decision: Option D — chezmoi-native bootstrap

Use chezmoi's built-in password manager integration. SSH keys are *output* of `chezmoi apply`, not a prerequisite. Works with **either 1Password or Bitwarden**.

### Why This Works

chezmoi clones via **HTTPS by default** — no SSH needed. Templates retrieve SSH keys from your password manager during apply:

```
Fresh Machine
     │
     ▼
1. brew install chezmoi <password-manager-cli>
     │
     ▼
2. Authenticate to password manager
     │
     ▼
3. chezmoi init --apply farra/homebase
   ├── Clones via HTTPS (no SSH)
   ├── Templates call password manager
   └── SSH keys written to ~/.ssh/
     │
     ▼
SSH now works for future git ops
```

### Template Structure

```
private_dot_ssh/
├── config.tmpl                    # SSH config (existing)
├── private_id_rsa.tmpl            # Retrieves private key from password manager
└── id_rsa.pub.tmpl                # Retrieves public key from password manager
```

### Provider Comparison

| Feature | 1Password | Bitwarden |
|---------|-----------|-----------|
| Cost | $36/year | Free (or $10/year premium) |
| CLI UX | Clean (`op read` syntax) | Session tokens (`BW_SESSION`) |
| chezmoi template | `onepasswordRead "op://..."` | `(bitwarden "item" "name").notes` |
| Newline handling | Clean | Needs base64 encode/decode |
| Biometric unlock | Yes | Yes (premium only) |

**1Password** has cleaner chezmoi integration. **Bitwarden** is free but requires a base64 workaround for SSH keys.

### Template Examples

**With 1Password:**
```
{{- onepasswordRead "op://Personal/ssh-key/private_key" -}}
```

**With Bitwarden:**
```
{{- (bitwarden "item" "ssh-key").notes | b64dec -}}
```
(Store the key base64-encoded in Bitwarden to avoid newline issues)

### Private Repo Handling

**Option A: Make homebase public** (recommended)
- Templates reference secrets by name, not values
- Someone seeing `{{ onepasswordRead "op://Personal/ssh-key" }}` gains nothing
- Actual secrets stay in password manager

**Option B: GitHub PAT for initial clone**
- Store PAT in password manager
- Retrieve first, then clone with PAT

### What About secretspec?

Keep secretspec for **runtime secrets** (API keys for Claude, OpenAI, etc.). It serves a different purpose:
- **chezmoi + password manager** — Bootstrap secrets (SSH keys, written to disk once)
- **secretspec** — Runtime secrets (API keys, injected into environment)

Both secretspec and chezmoi support multiple providers, so use whichever password manager you prefer for both.

### Simplified Secret Layers

| Layer | Tool | Purpose |
|-------|------|---------|
| Bootstrap | chezmoi + (1Password or Bitwarden) | SSH keys (one-time, written to ~/.ssh/) |
| Runtime | secretspec + (1Password or Bitwarden) | API keys (injected at runtime) |
| Team/project | Pulumi ESC | Infrastructure secrets |

### Open: Which Password Manager?

**Not yet decided.** Either works. Considerations:

- Already have 1Password? Use it.
- Want free? Use Bitwarden (with base64 workaround).
- Starting fresh? 1Password has better DX, Bitwarden is free.

### Action Items

- [x] Decision made: chezmoi-native bootstrap (Option D)
- [ ] Choose password manager (1Password or Bitwarden)
- [ ] Store SSH keys in chosen vault
- [ ] Create `private_dot_ssh/private_id_rsa.tmpl` with appropriate template
- [ ] Create `private_dot_ssh/id_rsa.pub.tmpl`
- [ ] Test on fresh machine
- [ ] Configure secretspec with same provider

---

## 2. SSH Keys Specifically — DECIDED

**Approach:** Store in password manager, retrieve via chezmoi templates.

### Storage

**In 1Password:**
- **Type:** Secure Note or Login with custom fields
- **Name:** `ssh-key`
- **Fields:** `private_key`, `public_key`

**In Bitwarden:**
- **Type:** Secure Note
- **Name:** `ssh-key`
- **Notes:** Base64-encoded private key
- Create separate item for public key, or store both in one note

### Shared vs Per-Machine

**Decision: Shared key** for simplicity.

- One SSH key across all machines
- Registered with GitHub, GitLab, etc.
- Rotation is a future problem (update password manager, re-run chezmoi)

### Template Files to Create

**With 1Password:**
```
private_dot_ssh/private_id_rsa.tmpl:
{{- onepasswordRead "op://Personal/ssh-key/private_key" -}}

private_dot_ssh/id_rsa.pub.tmpl:
{{- onepasswordRead "op://Personal/ssh-key/public_key" -}}
```

**With Bitwarden:**
```
private_dot_ssh/private_id_rsa.tmpl:
{{- (bitwarden "item" "ssh-key-private").notes | b64dec -}}

private_dot_ssh/id_rsa.pub.tmpl:
{{- (bitwarden "item" "ssh-key-public").notes -}}
```

The `{{- -}}` syntax trims whitespace to avoid extra newlines.

---

## 3. Dropbox: Keep or Drop? — OPEN

### Current Thinking: Keep for Forge Vault Only

Dropbox is **no longer needed for bootstrap** (1Password handles that). But it's still useful for forge vault.

### Role After This Change

| Before | After |
|--------|-------|
| Bootstrap layer (SSH keys) | ~~Removed~~ → 1Password |
| Forge vault storage | **TBD** — Dropbox has issues on Bazzite |

### Forge Vault Use Case

The vault contains:
- PDFs (research papers, manuals)
- Images and diagrams
- Large files that shouldn't be in git

Currently syncs via Dropbox to `~/Dropbox/Vault`, symlinked to `~/forge/vault`.

### Open Issue: Dropbox on Bazzite

Dropbox has reliability problems on Bazzite (immutable Fedora). This reopens the question of whether to keep Dropbox or migrate the vault elsewhere.

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| **Dropbox (status quo)** | Works on macOS/WSL, already set up | Unreliable on Bazzite, paid service |
| **GitHub + Git LFS** | Single tool (git), works everywhere | Complexity, storage costs at scale, binary diffs are useless |
| **Syncthing** | Self-hosted, no cloud dependency | More setup, need a "hub" device always on |
| **iCloud/OneDrive** | May work better on Linux? | Vendor lock-in, same class of problem |

**Needs resolution:**
- [ ] Investigate Dropbox on Bazzite — Is it fixable? Flatpak version? Running in distrobox?
- [ ] Estimate vault size — Is Git LFS viable cost-wise?
- [ ] Decide if forge vault is even needed on Bazzite (maybe macOS-only is fine?)

### Bootstrap No Longer Needs Dropbox

Old flow:
```
Dropbox → SSH keys → git clone
```

New flow:
```
1Password → chezmoi templates → SSH keys
```

Dropbox can be installed later (post-bootstrap) when setting up forge — if we keep it.

---

## 4. Brewfile: Generated or Manual?

### Options

**Generated from homebase.toml:**
- Single source of truth
- Need a script to generate
- Adds build step

**Manual with validation:**
- Two files to maintain
- `just check-sync` warns on drift
- Simpler, no build step

### Recommendation

**Manual with validation.** The tool lists are small and change rarely. Over-engineering.

---

## 5. Emacs on macOS

### Options

- **Homebrew Cask** (current plan): `brew install --cask emacs`
- **Nix**: Consistent with Linux, but Nix GUI apps on macOS can be finicky

### Recommendation

**Homebrew Cask.** It's the standard way on macOS. Don't fight it.

---

## 6. Slim vs Full Distrobox Image

### Slim (current implementation)

- ~150MB image with Nix pre-installed
- `just bootstrap` installs tools to `~/.nix-profile` on first run
- Tools persist in $HOME across image upgrades

### Full

- ~500MB+ image with all tools baked in
- Instant startup, no bootstrap step
- Must rebuild image to update tools

### Trade-offs

| Aspect | Slim | Full |
|--------|------|------|
| Image size | ~150MB | ~500MB+ |
| First-run time | ~5 min (bootstrap) | Instant |
| Adding tools | `nix profile install` | Rebuild image |
| Disk usage | Nix store grows in $HOME | Fixed in image |

### Recommendation

**Start with Slim.** It's simpler to build and more flexible. Switch to Full only if first-run time becomes a problem.

---

## 7. Forge Clone: Part of Bootstrap?

### Question

Should `git clone farra/forge ~/forge` be automated, or left as a manual post-bootstrap step?

### Considerations

- Forge is essential to the workflow
- But it's a separate repo, not part of homebase
- Vault symlink (`~/forge/vault → ~/Dropbox/Vault`) assumes Dropbox exists

### Recommendation

**Document it, don't automate it.** Keep bootstrap focused on the substrate. Forge is "use the substrate."

---

## 8. Windows Native (No WSL)

### Question

If WSL is unavailable (corporate lockdown), is there a fallback?

### Options

- Git Bash + limited toolset
- Scoop as Windows package manager
- Just don't support it

### Recommendation

**Out of scope.** WSL covers Windows. If WSL is blocked, that's a larger problem.

---

## 9. Shell: zsh vs bash

### Current Plan

zsh everywhere (default on macOS, easy to install elsewhere)

### Question

Is this worth the switch from current bash setup?

### Pros of zsh

- Default on macOS (no install)
- Better completion, globbing
- oh-my-posh / starship work great

### Cons

- One more thing to learn/configure
- bash is more universal (scripts)

### Recommendation

**zsh for interactive, bash for scripts.** This is already standard practice.

---

## Summary

### Decided

| Decision | Choice |
|----------|--------|
| Bootstrap approach | chezmoi-native (Option D) |
| Password manager | 1Password |
| SSH key storage | 1Password (shared key: `cautomaton-ssh-key`) |
| Brewfile | Manual with validation |
| Emacs on macOS | Homebrew Cask |
| Distrobox image | Slim (bootstrap on first run) |
| Forge clone | Document, don't automate |
| Windows native | Out of scope |
| Shell | zsh interactive, bash scripts |

### Open

| Decision | Status |
|----------|--------|
| Dropbox / forge vault | Dropbox unreliable on Bazzite — evaluate alternatives |

### Next Actions

1. ~~Choose password manager~~ — Done (1Password)
2. ~~Store SSH keys~~ — Done (`cautomaton-ssh-key` in Private vault)
3. ~~Create SSH templates~~ — Done (`private_id_rsa.tmpl`, `id_rsa.pub.tmpl`)
4. **Configure secretspec** — Set up 1Password as provider for runtime secrets
5. **Test on clean WSL Fedora** — Validates the whole approach
6. **Test on clean Bazzite** — Validates distrobox strategy
7. **Resolve Dropbox on Bazzite** — Fix it or migrate vault to Git LFS/Syncthing

### Simplified Bootstrap (Final)

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install chezmoi and password manager CLI
brew install chezmoi
# + install 1password-cli or bitwarden-cli

# 3. Authenticate to password manager
eval $(op signin)        # 1Password
# -or-
bw login && export BW_SESSION=$(bw unlock --raw)  # Bitwarden

# 4. Bootstrap everything
chezmoi init --apply farra/homebase

# Done. SSH keys are in ~/.ssh/, everything else applied.
```

Four steps. No Dropbox dependency. No separate SSH key retrieval step.

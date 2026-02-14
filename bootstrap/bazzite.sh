#!/usr/bin/env bash
# Homebase Layer 0 bootstrap for Bazzite KDE
#
# Idempotent: each phase is guarded by a stamp file in ~/.homebase-bootstrap/
# Re-run safely at any time to pick up where it left off.
#
# Prerequisites:
#   - 1Password account with these items in the Private vault:
#     - cautamaton-ssh-key (fields: "private key", "public key")
#     - github-pat (field: "credential") — PAT with repo + read:packages scopes
#
# Usage:
#   bash bazzite.sh

set -euo pipefail

STAMP_DIR="$HOME/.homebase-bootstrap"
mkdir -p "$STAMP_DIR"

info()  { echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
skip()  { echo -e "\033[1;33m  →\033[0m $* (already done)"; }

stamp_done() { touch "$STAMP_DIR/$1"; }
stamp_check() { [[ -f "$STAMP_DIR/$1" ]]; }

# ── Phase 1: Homebrew ────────────────────────────────────────────────────────

info "Phase 1: Homebrew"

if stamp_check "01-homebrew"; then
    skip "Homebrew already installed"
else
    if command -v brew &>/dev/null; then
        ok "Homebrew already on PATH"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # Ensure brew is on PATH for the rest of this script
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    stamp_done "01-homebrew"
    ok "Homebrew installed"
fi

# Make sure brew is on PATH even if phase was already stamped
if ! command -v brew &>/dev/null; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ── Phase 2: Host tools ─────────────────────────────────────────────────────

info "Phase 2: Host tools"

if stamp_check "02-host-tools"; then
    skip "Host tools already installed"
else
    brew install chezmoi just direnv git zsh 1password-cli
    # Set zsh as default shell (distrobox inherits host $SHELL)
    if [[ "$SHELL" != *zsh ]]; then
        ZSH_PATH="$(which zsh)"
        # Ensure our zsh is in /etc/shells
        grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null || echo "$ZSH_PATH" | sudo tee -a /etc/shells
        chsh -s "$ZSH_PATH"
        ok "Default shell set to $ZSH_PATH"
    fi
    stamp_done "02-host-tools"
    ok "Host tools installed"
fi

# ── Phase 3: 1Password authentication ───────────────────────────────────────

info "Phase 3: 1Password authentication"

if stamp_check "03-op-auth"; then
    skip "1Password already authenticated"
fi

# Always ensure we have a live session (tokens expire)
if ! op account list &>/dev/null 2>&1; then
    echo "  Please sign in to 1Password (this will open a browser)..."
    eval "$(op signin)"
fi

# Verify we can read from the vault
if op item get "cautamaton-ssh-key" --fields label="private key" &>/dev/null 2>&1; then
    ok "1Password session active"
    stamp_done "03-op-auth"
else
    echo "ERROR: Cannot read from 1Password vault. Is 'cautamaton-ssh-key' in Private vault?"
    exit 1
fi

# ── Phase 4: Dotfiles (chezmoi + 1Password) ─────────────────────────────────

info "Phase 4: Dotfiles via chezmoi"

if stamp_check "04-dotfiles"; then
    skip "Dotfiles already applied"
else
    # Retrieve GitHub PAT from 1Password
    GITHUB_PAT="$(op item get "github-pat" --fields label="credential")"

    # chezmoi init with PAT-embedded HTTPS URL (private repo, no SSH needed yet)
    chezmoi init --apply "https://${GITHUB_PAT}@github.com/farra/homebase.git"

    # Verify SSH key landed
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        ok "SSH private key installed"
    else
        echo "WARNING: ~/.ssh/id_rsa not found after chezmoi apply"
    fi

    stamp_done "04-dotfiles"
    ok "Dotfiles applied"
fi

# ── Phase 5: Fonts ────────────────────────────────────────────────────────

info "Phase 5: Nerd Fonts"

if stamp_check "05-fonts"; then
    skip "Nerd Fonts already installed"
else
    FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$FONT_DIR"
    NERD_FONTS_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    for font in FiraCode FiraMono; do
        echo "  Downloading ${font} Nerd Font..."
        curl -fLo "/tmp/${font}.zip" "${NERD_FONTS_BASE}/${font}.zip"
        unzip -o "/tmp/${font}.zip" -d "$FONT_DIR/"
        rm -f "/tmp/${font}.zip"
    done
    fc-cache -f
    stamp_done "05-fonts"
    ok "Nerd Fonts installed to $FONT_DIR (FiraCode, FiraMono)"
fi

# ── Phase 6: Distrobox ──────────────────────────────────────────────────────

info "Phase 6: Distrobox container"

if stamp_check "06-distrobox"; then
    skip "Distrobox 'home' already created"
else
    # Retrieve PAT again (may have been cleared from env)
    GITHUB_PAT="$(op item get "github-pat" --fields label="credential")"

    # Login to GHCR for private image pull
    echo "$GITHUB_PAT" | podman login ghcr.io -u farra --password-stdin

    # Pull the baked image
    podman pull ghcr.io/farra/homebase:latest

    # Create distrobox (--home shares host $HOME)
    distrobox create --image ghcr.io/farra/homebase:latest --name home

    stamp_done "06-distrobox"
    ok "Distrobox 'home' created"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
info "Bootstrap complete!"
echo ""
echo "  Next steps:"
echo "    1. distrobox enter home"
echo "    2. distrobox-export --app emacs"
echo "    3. just setup-workspace  (future — clone repos, set up ~/dev)"
echo ""
echo "  To re-run any phase, delete its stamp file:"
echo "    ls $STAMP_DIR/"
echo ""

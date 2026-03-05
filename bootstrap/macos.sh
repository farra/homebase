#!/usr/bin/env bash
# Homebase Layer 0 bootstrap for macOS
#
# Self-contained: no repo checkout required. The script installs chezmoi and
# 1Password CLI directly, then chezmoi clones the repo. All subsequent phases
# use the chezmoi source (~/.local/share/chezmoi/) for homebase.toml, the
# Brewfile renderer, and the Nix flake.
#
# On macOS there is no distrobox. Dev tools are installed directly via Nix
# profile from the same flake that builds the container image on Linux.
# This gives tool-level parity across platforms.
#
# Prerequisites:
#   - 1Password account with these items in the Private vault:
#     - SSH key item (fields: "private key", "public key") — see OP_SSH_KEY below
#     - GitHub PAT item (field: "credential") — see OP_GITHUB_PAT below
#     - GPG key item (files: public.asc, secret.asc) — see OP_GPG_KEY below
#
# Quick start (copy-paste into a fresh Mac terminal):
#   curl -fsSL https://raw.githubusercontent.com/farra/homebase/main/bootstrap/macos.sh -o /tmp/macos.sh
#   bash /tmp/macos.sh
#
# Usage:
#   bash macos.sh              # base profile (default)
#   bash macos.sh gamedev      # base + gamedev nix env

set -euo pipefail

PROFILE="${1:-base}"

# ── Configuration (change these for your own setup) ──────────────────────────
OP_SSH_KEY="cautomaton-ssh-key"
OP_GITHUB_PAT="github-pat"
OP_GPG_KEY="cautomaton-homebase-gpg"
GPG_KEY_FPR="48CF4CDEC93AE47B93491C7A43EBD702731ECFAC"
GITHUB_USER="farra"
# ─────────────────────────────────────────────────────────────────────────────

STAMP_DIR="$HOME/.homebase-bootstrap"
CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
mkdir -p "$STAMP_DIR"

info()  { echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
skip()  { echo -e "\033[1;33m  →\033[0m $* (already done)"; }
warn()  { echo -e "\033[1;31m  !\033[0m $*"; }

stamp_done() { touch "$STAMP_DIR/$1"; }
stamp_check() { [[ -f "$STAMP_DIR/$1" ]]; }

brew_ensure_path() {
    if ! command -v brew &>/dev/null; then
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

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
    brew_ensure_path
    stamp_done "01-homebrew"
    ok "Homebrew installed"
fi

brew_ensure_path

# ── Phase 2: Bootstrap tools ─────────────────────────────────────────────────
# Minimal: just chezmoi + 1Password CLI. The full Brewfile runs in phase 6
# after chezmoi has cloned the repo (which contains the renderer + homebase.toml).

info "Phase 2: Bootstrap tools (chezmoi + 1Password)"

if stamp_check "02-bootstrap-tools"; then
    skip "Bootstrap tools already installed"
else
    if ! command -v chezmoi &>/dev/null; then
        brew install chezmoi
    fi
    if ! command -v op &>/dev/null; then
        brew install --cask 1password-cli
    fi
    # gnupg is needed in phase 4 (GPG key import) — macOS doesn't ship it
    if ! command -v gpg &>/dev/null; then
        brew install gnupg
    fi

    for cmd in chezmoi op gpg; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: $cmd not found after brew install."
            exit 1
        fi
    done

    stamp_done "02-bootstrap-tools"
    ok "chezmoi, 1Password CLI, and gnupg installed"
fi

# ── Phase 3: 1Password authentication ───────────────────────────────────────

info "Phase 3: 1Password authentication"

if stamp_check "03-op-auth"; then
    skip "1Password already authenticated"
fi

# Add account if none configured
if ! op account list 2>/dev/null | grep -q .; then
    echo "  No 1Password accounts configured."
    echo "  Follow the prompts to add your account:"
    op account add
fi

# Sign in (tokens expire, so always check)
if ! op whoami &>/dev/null 2>&1; then
    echo "  Signing in to 1Password..."
    eval "$(op signin)"
fi

# Verify we can read from the vault
if op item get "$OP_SSH_KEY" --fields label="private key" &>/dev/null 2>&1; then
    ok "1Password session active"
    stamp_done "03-op-auth"
else
    echo "ERROR: Cannot read from 1Password vault. Is '$OP_SSH_KEY' in Private vault?"
    exit 1
fi

# ── Phase 4: GPG keys ──────────────────────────────────────────────────────

info "Phase 4: GPG keys for authinfo encryption"

if stamp_check "04-gpg-keys"; then
    skip "GPG keys already imported"
else
    if gpg --list-secret-keys "$GPG_KEY_FPR" &>/dev/null; then
        ok "GPG key already in keyring (re-stamping)"
    else
        op read "op://Private/${OP_GPG_KEY}/homebase-authinfo-public.asc" | \
            gpg --batch --import
        op read "op://Private/${OP_GPG_KEY}/homebase-authinfo-secret.asc" | \
            gpg --batch --import
        echo "${GPG_KEY_FPR}:6:" | gpg --batch --import-ownertrust
        ok "GPG keys imported and trusted"
    fi
    stamp_done "04-gpg-keys"
fi

# ── Phase 5: Dotfiles (chezmoi + 1Password) ─────────────────────────────────

info "Phase 5: Dotfiles via chezmoi"

if stamp_check "05-dotfiles"; then
    skip "Dotfiles already applied"
else
    # Pre-create chezmoi config so promptStringOnce variables are already set
    CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"
    mkdir -p "$CHEZMOI_CONFIG_DIR"
    if [[ ! -f "$CHEZMOI_CONFIG_DIR/chezmoi.toml" ]]; then
        cat > "$CHEZMOI_CONFIG_DIR/chezmoi.toml" <<TOML
[data]
    op_ssh_key = "$OP_SSH_KEY"
    op_github_pat = "$OP_GITHUB_PAT"
    op_gpg_key = "$OP_GPG_KEY"
    gpg_key_fingerprint = "$GPG_KEY_FPR"
    op_anthropic_key = ""
    op_openai_key = ""
TOML
        ok "Pre-seeded chezmoi config with 1Password item names"
    fi

    # Retrieve GitHub PAT from 1Password
    GITHUB_PAT="$(op read "op://Private/${OP_GITHUB_PAT}/credential")"

    # Pre-populate known_hosts so chezmoi externals (forge clone via SSH) don't hang
    mkdir -p "$HOME/.ssh"
    if ! grep -q 'github\.com' "$HOME/.ssh/known_hosts" 2>/dev/null; then
        ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    fi

    # chezmoi init with HTTPS URL (SSH keys don't exist yet)
    export GIT_ASKPASS="$(mktemp)"
    chmod 700 "$GIT_ASKPASS"
    trap 'rm -f "$GIT_ASKPASS"' EXIT
    printf '#!/bin/sh\necho "%s"\n' "$GITHUB_PAT" > "$GIT_ASKPASS"
    chezmoi init --apply "https://${GITHUB_USER}@github.com/${GITHUB_USER}/homebase.git"
    rm -f "$GIT_ASKPASS"
    trap - EXIT
    unset GIT_ASKPASS

    # Switch chezmoi remote to SSH (now that SSH keys are installed)
    chezmoi git -- remote set-url origin "git@github.com:${GITHUB_USER}/homebase.git"
    ok "Chezmoi remote switched to SSH (future updates use SSH key)"

    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        ok "SSH private key installed"
    else
        warn "~/.ssh/id_ed25519 not found after chezmoi apply"
    fi

    stamp_done "05-dotfiles"
    ok "Dotfiles applied"
fi

# ── Phase 6: Host tools (full Brewfile) ───────────────────────────────────────
# Now that chezmoi has cloned the repo, we have access to the Brewfile renderer
# and homebase.toml. Install the full set of host tools, casks, and fonts.

info "Phase 6: Host tools (Homebrew)"

if stamp_check "06-host-tools"; then
    skip "Host tools already installed"
else
    RENDERER="${CHEZMOI_SOURCE}/scripts/render-brewfile.sh"
    TOML="${CHEZMOI_SOURCE}/homebase.toml"

    if [[ ! -x "$RENDERER" ]]; then
        echo "ERROR: Brewfile renderer not found: $RENDERER"
        echo "  Did chezmoi apply complete? Check: ls $CHEZMOI_SOURCE/"
        exit 1
    fi

    tmp_brewfile="$(mktemp)"
    trap 'rm -f "$tmp_brewfile"' EXIT
    "$RENDERER" "$TOML" > "$tmp_brewfile"
    brew bundle --file="$tmp_brewfile"
    rm -f "$tmp_brewfile"
    trap - EXIT

    # Verify key tools landed
    for cmd in just direnv git; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: $cmd not found after brew bundle."
            exit 1
        fi
    done

    # Set zsh as default shell if not already (macOS defaults to zsh, but guard it)
    if [[ "$SHELL" != *zsh ]]; then
        ZSH_PATH="$(command -v zsh)"
        chsh -s "$ZSH_PATH" || warn "chsh failed — set your shell to zsh manually"
        ok "Default shell set to $ZSH_PATH (log out and back in to take effect)"
    fi

    stamp_done "06-host-tools"
    ok "Host tools installed (formulas + macOS casks + fonts)"
fi

# ── Phase 7: Nix ──────────────────────────────────────────────────────────────

info "Phase 7: Nix package manager"

if stamp_check "07-nix"; then
    skip "Nix already installed"
else
    if command -v nix &>/dev/null; then
        ok "Nix already on PATH ($(nix --version))"
    else
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
        # Source nix for the rest of this script
        if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
    fi
    stamp_done "07-nix"
    ok "Nix installed"
fi

# Make sure nix is on PATH even if phase was already stamped
if ! command -v nix &>/dev/null; then
    if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
fi

# ── Phase 8: Dev tools (Nix profile) ─────────────────────────────────────────
# On macOS, dev tools from [container] in homebase.toml are installed directly
# via nix profile, rather than baked into a distrobox image.
# The flake supports macOS natively (eachDefaultSystem + platform-conditional Emacs).

info "Phase 8: Dev tools via Nix"

if stamp_check "08-nix-tools"; then
    skip "Nix dev tools already installed"
else
    # Determine which flake env to install based on profile
    if [[ "$PROFILE" == "base" ]]; then
        FLAKE_ENV="homebase-base-env"
    elif [[ "$PROFILE" == "gamedev" ]]; then
        FLAKE_ENV="homebase-gamedev-env"
    else
        echo "ERROR: Unknown profile '$PROFILE'. Use 'base' or 'gamedev'."
        exit 1
    fi

    if [[ -f "$CHEZMOI_SOURCE/flake.nix" ]]; then
        echo "  Installing $FLAKE_ENV from chezmoi source..."
        nix profile add "${CHEZMOI_SOURCE}#${FLAKE_ENV}"
        ok "Dev tools installed via nix profile ($FLAKE_ENV)"
    else
        warn "flake.nix not found in chezmoi source: $CHEZMOI_SOURCE"
        warn "Re-run after chezmoi apply: rm $STAMP_DIR/08-nix-tools && bash $0"
        exit 1
    fi

    stamp_done "08-nix-tools"
fi

# ── Persist profile choice ───────────────────────────────────────────────────

mkdir -p "$HOME/.homebase"
echo "$PROFILE" > "$HOME/.homebase/profile"
ok "Profile '$PROFILE' saved to ~/.homebase/profile"

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
info "Bootstrap complete! (profile: $PROFILE)"
echo ""
echo "  Next steps:"
echo "    1. Open a new terminal (so zsh + starship + all tools load)"
echo "    2. homebase setup        (workspace dirs + Doom Emacs + AI agents)"
echo "    3. Verify: which emacs rg fd fzf bat starship chezmoi just"
echo ""
echo "  To update everything later:"
echo "    homebase update"
echo ""
echo "  To re-run any phase, delete its stamp file:"
echo "    ls $STAMP_DIR/"
echo ""

# justfile - Homebase orchestration commands

default:
    @just --list

# Apply dotfiles via chezmoi
apply:
    chezmoi apply

# Update dotfiles from remote
update:
    chezmoi update

# Full sync (pull + apply + tools)
sync:
    chezmoi update
    @if [ "$(uname)" = "Darwin" ]; then \
        brew bundle --file={{ justfile_directory() }}/Brewfile; \
    else \
        echo "On Linux, run: distrobox upgrade home && just bootstrap"; \
    fi

# Bootstrap: install tools via nix profile (run inside distrobox)
bootstrap:
    #!/usr/bin/env bash
    set -e
    if [ -f ~/.homebase-bootstrapped ]; then
        echo "Already bootstrapped. Re-running to update..."
    fi
    echo "Installing homebase tools via nix profile..."
    nix profile install nixpkgs#{git,ripgrep,fd,fzf,bat,eza,jq,yq,delta,just,direnv,emacs}

    # Export Emacs to host desktop
    distrobox-export --app emacs 2>/dev/null || echo "Note: distrobox-export not available (not in distrobox?)"

    touch ~/.homebase-bootstrapped
    echo "Bootstrap complete. Tools installed to ~/.nix-profile/bin"

# Validate Brewfile matches homebase.toml
check-sync:
    @echo "Checking Brewfile vs homebase.toml..."
    @echo "TODO: implement validation script"

# Build slim distrobox image locally
build-slim:
    podman build -t homebase:slim -f Containerfile.slim .

# Test slim image (create throwaway distrobox)
test-slim:
    distrobox rm -f homebase-test || true
    distrobox create --image homebase:slim --name homebase-test
    distrobox enter homebase-test -- just bootstrap
    @echo "Test with: distrobox enter homebase-test"

# Enter distrobox (Linux only)
enter:
    distrobox enter home

# Re-add changed dotfiles to chezmoi
re-add:
    chezmoi re-add

# Push dotfile changes
push:
    cd ~/.local/share/chezmoi && git add -A && git commit -m "Update dotfiles" && git push

# Doom Emacs sync (after config changes)
doom-sync:
    ~/.emacs.d/bin/doom sync

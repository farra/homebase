# justfile - Homebase orchestration commands

registry := "ghcr.io/farra"
image_name := "homebase"
runtime := `command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo "no-runtime"`

default:
    @just --list

# ── Dotfile Management ───────────────────────────────────────────────────────

# Apply dotfiles via chezmoi
apply:
    chezmoi apply

# Update dotfiles from remote
update:
    chezmoi update

# Full sync (pull + apply + host tools)
sync:
    chezmoi update
    @if [ "$(uname)" = "Darwin" ]; then \
        brew bundle --file={{ justfile_directory() }}/Brewfile; \
    fi

# Re-add changed dotfiles to chezmoi
re-add:
    chezmoi re-add

# Push dotfile changes
push:
    cd ~/.local/share/chezmoi && git add -A && git commit -m "Update dotfiles" && git push

# Doom Emacs sync (after config changes)
doom-sync:
    ~/.emacs.d/bin/doom sync

# ── Image Building ───────────────────────────────────────────────────────────

# Build the homebase OCI image
build-image:
    {{runtime}} build \
        -t {{registry}}/{{image_name}}:latest \
        -f images/Containerfile .

# Tag the image with a version
tag-image version:
    {{runtime}} tag {{registry}}/{{image_name}}:latest {{registry}}/{{image_name}}:{{version}}

# Push latest image to registry
push-image:
    {{runtime}} push {{registry}}/{{image_name}}:latest

# Build, tag, and push a release
release version: build-image (tag-image version)
    {{runtime}} push {{registry}}/{{image_name}}:latest
    {{runtime}} push {{registry}}/{{image_name}}:{{version}}

# ── Distrobox ────────────────────────────────────────────────────────────────

# Create the homebase distrobox
distrobox-create:
    distrobox create --image {{registry}}/{{image_name}}:latest --name home

# Enter the homebase distrobox
distrobox-enter:
    distrobox enter home

# Remove the homebase distrobox
distrobox-rm:
    distrobox rm home --force

# Build image and create distrobox for local testing
test-local: build-image
    -distrobox rm homebase-test --force
    distrobox create --image {{registry}}/{{image_name}}:latest --name homebase-test
    @echo "Created distrobox 'homebase-test'. Enter with: distrobox enter homebase-test"

# ── Development ──────────────────────────────────────────────────────────────

# Enter nix develop shell (macOS)
dev:
    nix develop

# Run nix flake check
check:
    nix flake check


# justfile - Homebase project development
#
# For working ON homebase (building images, developing dotfiles).
# Run from the repo checkout: ~/dev/homebase/ or ~/dev/me/homebase/
#
# For living IN homebase, use ~/.homebase/justfile instead:
#   cd ~/.homebase && just --list
#   (or use the `homebase` shell alias)

registry := "ghcr.io/farra"
image_name := "homebase"
runtime := `command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo ""`

default:
    @just --list

# ── Image Building ───────────────────────────────────────────────────────

# Build the homebase OCI image
build-image: _require-runtime
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

# Build image and test in a throwaway distrobox
test-local: build-image
    -distrobox rm homebase-test --force
    distrobox create --image {{registry}}/{{image_name}}:latest --name homebase-test
    @echo "Created distrobox 'homebase-test'. Enter with: distrobox enter homebase-test"

# ── Dotfile Development ──────────────────────────────────────────────────

# Re-add changed dotfiles to chezmoi source
re-add:
    chezmoi re-add

# Commit and push dotfile changes
push:
    cd ~/.local/share/chezmoi && git add -A && git commit -m "Update dotfiles" && git push

# ── Flake Development ────────────────────────────────────────────────────

# Run nix flake check
check:
    nix flake check

# Enter nix develop shell (macOS native)
dev:
    nix develop

# ── Helpers ────────────────────────────────────────────────────────────

# Verify container runtime is available
_require-runtime:
    #!/usr/bin/env bash
    if [[ -z "{{runtime}}" ]]; then
        echo "ERROR: Neither podman nor docker found. Install one first."
        exit 1
    fi

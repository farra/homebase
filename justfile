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

# Build a profile image (base→:latest, others→:PROFILE-latest)
# Usage:
#   just build-variant base
#   just build-variant gamedev
build-variant profile: _require-runtime
    #!/usr/bin/env bash
    set -euo pipefail
    eval "$(bash scripts/resolve-profile.sh "{{profile}}" homebase.toml)"
    if [[ "{{profile}}" == "base" ]]; then
        tag="latest"
    else
        tag="{{profile}}-latest"
    fi
    {{runtime}} build \
        -t {{registry}}/{{image_name}}:"$tag" \
        --build-arg BASE_IMAGE="$RESOLVED_BASE_IMAGE" \
        --build-arg FLAKE_ENV="$RESOLVED_FLAKE_ENV" \
        --build-arg DNF_PACKAGES="$RESOLVED_DNF_PACKAGES" \
        --build-arg GODOT_VERSION="$RESOLVED_GODOT_VERSION" \
        -f images/Containerfile .

# Build the default (base) homebase OCI image
build-image: (build-variant "base")

# Tag the image with a version
tag-image version:
    {{runtime}} tag {{registry}}/{{image_name}}:latest {{registry}}/{{image_name}}:{{version}}

# Push latest image to registry
push-image:
    {{runtime}} push {{registry}}/{{image_name}}:latest

# Push a profile/flavor image
push-variant profile:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{profile}}" == "base" ]]; then
        tag="latest"
    else
        tag="{{profile}}-latest"
    fi
    {{runtime}} push {{registry}}/{{image_name}}:"$tag"

# Build, tag, and push a release
release version: (build-variant "base") (tag-image version)
    {{runtime}} push {{registry}}/{{image_name}}:latest
    {{runtime}} push {{registry}}/{{image_name}}:{{version}}

# Trigger CI image build via GitHub Actions
build-ci:
    gh workflow run "Build Images"
    @echo "Workflow triggered. Watch with: gh run watch"

# Build variant image and test in a throwaway distrobox
test-variant-local profile: (build-variant profile)
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{profile}}" == "base" ]]; then
        tag="latest"
    else
        tag="{{profile}}-latest"
    fi
    box_name="homebase-{{profile}}-test"
    distrobox rm "$box_name" --force 2>/dev/null || true
    VOLUME_FLAGS=""
    if [[ -d "/home/linuxbrew" ]]; then
        VOLUME_FLAGS="--volume /home/linuxbrew:/home/linuxbrew"
    fi
    distrobox create --image {{registry}}/{{image_name}}:"$tag" --name "$box_name" \
        --init-hooks "usermod -s /usr/bin/zsh \$USER" \
        $VOLUME_FLAGS
    echo "Created distrobox '$box_name'. Enter with: distrobox enter $box_name"

# Build image and test in a throwaway distrobox (base profile)
test-local: (test-variant-local "base")

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

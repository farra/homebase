#!/usr/bin/env bash
set -euo pipefail

# Render Brewfile content from homebase.toml.
# Usage:
#   scripts/render-brewfile.sh [toml_path]
# Output:
#   Brewfile text to stdout

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="${SCRIPT_DIR}/parse-toml-array.sh"
TOML_PATH="${1:-${SCRIPT_DIR}/../homebase.toml}"

if [[ ! -x "$PARSER" ]]; then
    echo "ERROR: TOML parser not found or not executable: $PARSER" >&2
    exit 1
fi

if [[ ! -f "$TOML_PATH" ]]; then
    echo "ERROR: TOML file not found: $TOML_PATH" >&2
    exit 1
fi

cat <<'EOF'
# Brewfile - Host substrate (Layer 0)
# Generated from homebase.toml (host tools + macOS casks)
#
# Dev tools (ripgrep, fd, fzf, bat, etc.) live in the container image now.
# This file only installs what the host needs to bootstrap and manage dotfiles.

# Core host tools
EOF

while IFS= read -r formula; do
    printf 'brew "%s"\n' "$formula"
done < <("$PARSER" host tools "$TOML_PATH")

cat <<'EOF'

# macOS only - GUI apps
EOF

while IFS= read -r cask; do
    printf 'cask "%s" if OS.mac?\n' "$cask"
done < <("$PARSER" macos casks "$TOML_PATH")

# Extra font casks (from [fonts.extra] macos-casks, if present)
if "$PARSER" fonts.extra macos-casks "$TOML_PATH" &>/dev/null; then
    cat <<'EOF'

# macOS only - extra fonts
EOF
    while IFS= read -r cask; do
        printf 'cask "%s" if OS.mac?\n' "$cask"
    done < <("$PARSER" fonts.extra macos-casks "$TOML_PATH")
fi

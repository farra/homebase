#!/usr/bin/env bash
set -euo pipefail

# Resolve container profile metadata from homebase.toml.
# Usage:
#   scripts/resolve-profile.sh <profile> [toml_path]
#
# Output (eval-able):
#   RESOLVED_FLAKE_ENV='...'
#   RESOLVED_BASE_IMAGE='...'
#
# Pure bash — no python3 or external TOML parser required.
# Works on a fresh Bazzite host before any tooling is installed.

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <profile> [toml_path]" >&2
    exit 2
fi

profile="$1"
toml_path="${2:-homebase.toml}"

if [[ ! -f "$toml_path" ]]; then
    echo "ERROR: TOML file not found: $toml_path" >&2
    exit 3
fi

# Parse [profiles.<profile>] section from TOML using regex.
# We only need simple key = "value" pairs from a known section header.
flake_env=""
base_image=""
in_section=false

while IFS= read -r line; do
    # Strip inline comments (but not inside quoted values)
    stripped="${line%%#*}"

    # Detect section headers: [profiles.NAME]
    if [[ "$stripped" =~ ^\[profiles\.([a-zA-Z0-9_-]+)\]$ ]]; then
        if [[ "${BASH_REMATCH[1]}" == "$profile" ]]; then
            in_section=true
        else
            # Entering a different section — stop if we were in ours
            $in_section && break
        fi
        continue
    fi

    # Any other section header ends our section
    if [[ "$stripped" =~ ^\[.+\]$ ]]; then
        $in_section && break
        continue
    fi

    if $in_section; then
        # Match key = "value" (with optional whitespace)
        if [[ "$stripped" =~ ^[[:space:]]*flake_env[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
            flake_env="${BASH_REMATCH[1]}"
        elif [[ "$stripped" =~ ^[[:space:]]*base_image[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
            base_image="${BASH_REMATCH[1]}"
        fi
    fi
done < "$toml_path"

if ! $in_section; then
    echo "ERROR: Missing [profiles.${profile}] in ${toml_path}" >&2
    exit 11
fi

if [[ -z "$flake_env" ]]; then
    echo "ERROR: profiles.${profile}.flake_env must be a non-empty string in ${toml_path}" >&2
    exit 12
fi

if [[ -z "$base_image" ]]; then
    echo "ERROR: profiles.${profile}.base_image must be a non-empty string in ${toml_path}" >&2
    exit 13
fi

printf "RESOLVED_FLAKE_ENV='%s'\n" "$flake_env"
printf "RESOLVED_BASE_IMAGE='%s'\n" "$base_image"

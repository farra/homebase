#!/usr/bin/env bash
set -euo pipefail

# Parse a TOML array and print values one per line.
# Usage:
#   scripts/parse-toml-array.sh <section> <key> [toml_path]
#
# Examples:
#   scripts/parse-toml-array.sh flatpaks apps homebase.toml
#   scripts/parse-toml-array.sh host tools homebase.toml
#   scripts/parse-toml-array.sh profiles.base tools homebase.toml  # dotted section
#
# Output: newline-delimited values (quotes stripped)
#
# Exit codes:
#   0  — success
#   2  — usage error
#   3  — TOML file not found
#   11 — section not found
#   12 — key not found in section
#
# Pure bash — no python3 or external TOML parser required.
# Works on a fresh Bazzite host before any tooling is installed.

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <section> <key> [toml_path]" >&2
    exit 2
fi

section="$1"
key="$2"
toml_path="${3:-homebase.toml}"

if [[ ! -f "$toml_path" ]]; then
    echo "ERROR: TOML file not found: $toml_path" >&2
    exit 3
fi

# Build the section header pattern.
# Dotted names like "profiles.base" → [profiles.base]
section_header="[${section}]"

in_section=false
found_section=false
in_array=false
values=""

while IFS= read -r line; do
    # Strip inline comments (not inside quoted values — good enough for our TOML subset)
    stripped="${line%%#*}"

    # Detect section headers: [name] or [dotted.name]
    if [[ "$stripped" =~ ^\[([a-zA-Z0-9._-]+)\]$ ]]; then
        header="[${BASH_REMATCH[1]}]"
        if [[ "$header" == "$section_header" ]]; then
            in_section=true
            found_section=true
        else
            # Entering a different section — stop if we were in ours
            if $in_section; then
                break
            fi
        fi
        continue
    fi

    if ! $in_section; then
        continue
    fi

    # If we're collecting a multi-line array, accumulate until ]
    if $in_array; then
        # Check for closing bracket
        if [[ "$stripped" =~ \] ]]; then
            # Extract any values before the bracket
            before_bracket="${stripped%%]*}"
            if [[ -n "$before_bracket" ]]; then
                values+=" $before_bracket"
            fi
            in_array=false
        else
            values+=" $stripped"
        fi
        continue
    fi

    # Match key = [...] (single-line) or key = [ (multi-line start)
    if [[ "$stripped" =~ ^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.*) ]]; then
        rest="${BASH_REMATCH[1]}"
        # Check if the array is complete on one line
        if [[ "$rest" =~ ^\[.*\]$ ]]; then
            # Single-line: strip brackets
            inner="${rest#\[}"
            inner="${inner%\]}"
            values="$inner"
        elif [[ "$rest" =~ ^\[ ]]; then
            # Multi-line: starts with [ but no closing ]
            inner="${rest#\[}"
            values="$inner"
            in_array=true
        fi
    fi
done < "$toml_path"

if ! $found_section; then
    echo "ERROR: Missing [${section}] in ${toml_path}" >&2
    exit 11
fi

if [[ -z "$values" ]]; then
    echo "ERROR: Key '${key}' not found or empty in [${section}]" >&2
    exit 12
fi

# Parse comma-separated values, strip quotes and whitespace, print one per line
# Handle values like: "foo", "bar", "baz"
echo "$values" | tr ',' '\n' | while IFS= read -r item; do
    # Trim whitespace
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    # Strip quotes
    item="${item#\"}"
    item="${item%\"}"
    # Skip empty items
    if [[ -n "$item" ]]; then
        echo "$item"
    fi
done

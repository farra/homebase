#!/bin/bash
# Create workspace directory structure
#
# ~/dev/.worktrees/  — bare clones (hidden, not worked in directly)
# ~/dev/me/          — github.com/farra (worktrees checked out here)
# ~/dev/jmt/         — github.com/jamandtea
# ~/dev/ref/         — third-party / reference
#
# Workflow: bare clone in .worktrees, git worktree add into group dirs.
# Each worktree = one branch = one agent. Branch is the artifact, directory
# is disposable.

mkdir -p ~/dev/.worktrees ~/dev/me ~/dev/jmt ~/dev/ref

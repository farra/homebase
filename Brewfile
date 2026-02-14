# Brewfile - Host substrate (Layer 0)
# Keep in sync with homebase.toml [host]
#
# Dev tools (ripgrep, fd, fzf, bat, etc.) live in the container image now.
# This file only installs what the host needs to bootstrap and manage dotfiles.

# Core host tools
brew "git"
brew "chezmoi"
brew "zsh"
brew "just"
brew "direnv"

# 1Password CLI
cask "1password-cli" if OS.mac?
brew "1password-cli" unless OS.mac?

# macOS only - GUI apps
cask "tailscale" if OS.mac?
cask "emacs" if OS.mac?
cask "font-fira-code-nerd-font" if OS.mac?
cask "font-fira-mono-nerd-font" if OS.mac?

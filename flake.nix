{
  description = "Homebase development environment - consistent tools across macOS, Bazzite, and WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Shared base tools for all homebase container profiles.
        # Language runtimes (python, node, rust, go) are per-project via
        # cautomaton-develops nix develop shells, not here.
        homebaseBasePackages = with pkgs; [
          # Core
          git
          zsh
          chezmoi
          just
          direnv

          # Search and navigation
          ripgrep
          fd
          fzf
          zoxide
          tree

          # Modern CLI tools
          bat
          eza
          jq
          yq-go
          delta
          glow
          tealdeer

          # Git
          gh
          lazygit

          # Shell
          starship
          atuin
          shellcheck
          tmux
          nushell
          zsh-autosuggestions
          zsh-syntax-highlighting

          # System essentials
          curl
          wget
          watch
          less
          file
          lsof
          bottom

          # Editor — Emacs with vterm native module for Doom Emacs
          (emacs.pkgs.withPackages (epkgs: with epkgs; [
            vterm
          ]))
        ];

        # Game development profile extras.
        # Keep this focused on heavy, domain-specific tooling that should not
        # bloat the default daily-driver profile.
        homebaseGamedevExtras = with pkgs; [
          godot_4        # GDScript projects → `godot`
          godot_4-mono   # C# projects → `godot-mono`
          dotnet-sdk_8
        ];

        homebaseGamedevPackages = homebaseBasePackages ++ homebaseGamedevExtras;
      in
      {
        packages = {
          # Base profile: default daily-driver distrobox tools
          homebase-base-env = pkgs.buildEnv {
            name = "homebase-base-env";
            paths = homebaseBasePackages;
          };

          # Gamedev profile: base + game development stack
          homebase-gamedev-env = pkgs.buildEnv {
            name = "homebase-gamedev-env";
            paths = homebaseGamedevPackages;
          };

          default = self.packages.${system}.homebase-base-env;
        };

        # devShell for macOS native use (nix develop)
        devShells.default = pkgs.mkShell {
          packages = homebaseBasePackages;
          shellHook = ''
            echo "homebase dev environment"
          '';
        };
      }
    );
}

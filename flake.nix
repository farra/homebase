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

        # All tools that should be available in the homebase environment
        homebasePackages = with pkgs; [
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

          # Modern CLI tools
          bat
          eza
          jq
          yq-go
          delta
          gh
          oh-my-posh

          # Editor — Emacs with vterm native module for Doom Emacs
          (emacs.pkgs.withPackages (epkgs: with epkgs; [
            vterm
          ]))
        ];
      in
      {
        packages = {
          # buildEnv for nix profile install (used in Containerfile)
          homebase-env = pkgs.buildEnv {
            name = "homebase-env";
            paths = homebasePackages;
          };

          default = self.packages.${system}.homebase-env;
        };

        # devShell for macOS native use (nix develop)
        devShells.default = pkgs.mkShell {
          packages = homebasePackages;
          shellHook = ''
            echo "homebase dev environment"
          '';
        };
      }
    );
}

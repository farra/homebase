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
        deps = builtins.fromTOML (builtins.readFile ./homebase.toml);

        resolvePackage = name:
          if builtins.hasAttr name pkgs then
            pkgs.${name}
          else
            throw "Unknown nixpkgs package in [container].packages: ${name}";

        # Emacs backend per platform:
        # Linux: emacs-pgtk for native Wayland support (HiDPI scaling)
        # macOS: standard emacs (Cocoa/NS backend)
        emacsPackage = if pkgs.stdenv.isLinux then pkgs.emacs-pgtk else pkgs.emacs;

        specialIncludes = {
          emacs-vterm = emacsPackage.pkgs.withPackages (epkgs: with epkgs; [
            vterm
          ]);
        };

        resolveInclude = name:
          if builtins.hasAttr name specialIncludes then
            specialIncludes.${name}
          else
            throw "Unknown include in [container].include: ${name}";

        # Shared base tools for all homebase container profiles.
        # Language runtimes (python, node, rust, go) are per-project via
        # cautomaton-develops nix develop shells, not here.
        homebaseBasePackages =
          map resolvePackage (deps.container.packages or [])
          ++ map resolveInclude (deps.container.include or []);

        # Game development profile extras (Nix-only, CLI tools).
        # GUI apps (godot) and their runtime deps (dotnet-sdk) are installed
        # via DNF in the Containerfile so they can access host GPU drivers.
        homebaseGamedevExtras = with pkgs; [
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

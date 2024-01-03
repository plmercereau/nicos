{
  description = "Nicos - Nix Integrated Configuration and Operational Systems";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # Don't use nixos-unstable-small when enabling the linux-builder
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "nixpkgs-darwin";
    agenix.inputs.home-manager.follows = "home-manager";

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Used for building the documentation
    pnpm2nix.url = "github:nzbr/pnpm2nix-nzbr";
  };

  outputs = inputs @ {
    agenix,
    deploy-rs,
    flake-utils,
    home-manager,
    impermanence,
    nix-darwin,
    nixos-anywhere,
    nixpkgs,
    pnpm2nix,
    self,
    ...
  }: let
    inherit (nixpkgs) lib;
  in
    {
      lib = {configure = import ./configure.nix inputs;};
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3;
    in {
      inherit (import ./modules inputs) nixosModules darwinModules;

      packages = {
        cli = python.pkgs.buildPythonApplication rec {
          name = "nicos";
          propagatedBuildInputs = (
            [
              agenix.packages.${system}.default
              nixos-anywhere.packages.${system}.default
              pkgs.rsync
              pkgs.wireguard-tools
            ]
            # not very elegant
            ++ (lib.optional (pkgs.hostPlatform.isLinux) (import ./packages/mount-image.nix {inherit pkgs;}))
            ++ (with python.pkgs; [
              bcrypt
              python-box
              click
              cryptography
              questionary
              jinja2
              psutil
            ])
          );
          src = ./cli;
        };

        doc = pkgs.writeShellApplication {
          name = "doc";
          runtimeInputs = [pkgs.nodejs];
          text = ''
            cd docs
            npx mintlify dev
          '';
        };

        docgen = import ./docgen.nix inputs system;
      };

      apps = rec {
        default = cli;

        cli = flake-utils.lib.mkApp {drv = self.packages.${system}.cli;};
      };

      devShells = {
        default = pkgs.mkShell {
          # Load the dependencies of all the packages
          packages =
            (lib.mapAttrsToList (name: pkg: pkg.propagatedBuildInputs) self.packages.${system})
            ++ [
              # for the documentation
              pkgs.nodejs
            ];
          shellHook = ''
            # echo "Nix environment loaded"
          '';
        };
      };
    });
}

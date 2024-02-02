{
  description = "Nicos - Nix Integrated Configuration and Operational Systems";

  inputs = {
    systems.url = "github:nix-systems/default";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    # Hint: don't use nixos-unstable-small when enabling the linux-builder on darwin
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs = {
      nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs = {
      nixpkgs.follows = "nixpkgs";
      disko.follows = "disko";
      nixos-stable.follows = "nixpkgs-stable";
    };

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs = {
      nixpkgs.follows = "nixpkgs";
      darwin.follows = "nixpkgs-darwin";
      home-manager.follows = "home-manager";
      systems.follows = "systems";
    };

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs = {
      nixpkgs.follows = "nixpkgs";
      utils.follows = "flake-utils";
    };

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    flake-utils,
    nixpkgs,
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
    in rec {
      inherit (import ./modules inputs) nixosModules darwinModules;

      packages = {
        cli = import ./packages/cli pkgs inputs;
        doc = import ./packages/doc.nix pkgs;
        docgen = import ./packages/docgen.nix pkgs inputs;
        k3s-ca-certs = import ./packages/k3s-ca-certs.nix pkgs;
      };

      apps = rec {
        default = cli;

        cli = flake-utils.lib.mkApp {drv = packages.cli;};
      };

      devShells = {
        default = pkgs.mkShell {
          # Load the dependencies of all the packages
          packages =
            (lib.mapAttrsToList (name: pkg: pkg.propagatedBuildInputs) packages)
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

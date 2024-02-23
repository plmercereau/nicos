{
  description = "Nicos - Nix Integrated Configuration and Operational Systems";

  inputs = {
    systems.url = "github:nix-systems/default";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs = {
      nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs = {
      disko.follows = "disko";
    };

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
      systems.follows = "systems";
    };

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    flake-utils,
    nixpkgs,
    ...
  }:
    with nixpkgs.lib;
      {
        lib = {configure = import ./configure.nix inputs;};
      }
      // flake-utils.lib.eachDefaultSystem
      (system: let
        flake-lib = import ./flake-lib.nix inputs;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [flake-lib.overlays.default];
        };
      in rec {
        packages = {
          cli = pkgs.nicos;
          doc = pkgs.nicos-doc;
          docgen = pkgs.nicos-docgen;
        };

        apps = rec {
          default = cli;

          cli = flake-utils.lib.mkApp {drv = packages.nicos;};
        };

        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nicos
              nicos-doc
              nicos-docgen
              k3s-ca-certs
            ];
            shellHook = ''
              # echo "Nix environment loaded"
            '';
          };
        };
      });
}

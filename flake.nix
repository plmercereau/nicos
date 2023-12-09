{
  description = "Flake for managing my machines";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    flake-lib.url = "./flakes";
    flake-lib.inputs = {
      nixpkgs.follows = "nixpkgs";
      nix-darwin.follows = "nix-darwin";
      home-manager.follows = "home-manager";
    };
  };

  outputs = {
    nixpkgs,
    flake-lib,
    flake-utils,
    ...
  }:
    flake-lib.lib.configure {
      projectRoot = ./.;
      extraModules = [./settings.nix];
      clusterAdmins = ["pilou"];
    } (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # TODO for dev purpose only
      devShells = flake-lib.devShells.${system};
    }));
}

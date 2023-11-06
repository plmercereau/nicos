{
  description = "Flake for managing my machines";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # ? how is it used?
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "nixpkgs-darwin";

    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = flakeInputs @ {
    self,
    flake-utils,
    nixpkgs,
    agenix,
    home-manager,
    nix-darwin,
    nixpkgs-darwin,
    deploy-rs,
  }:
    flake-utils.lib.meld flakeInputs [./flakes/main.nix ./flakes/machines.nix];
}

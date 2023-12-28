{
  description = "Flake for managing my machines";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    cluster.url = "./cluster-flake";
    cluster.inputs = {
      nixpkgs.follows = "nixpkgs";
      nix-darwin.follows = "nix-darwin";
      home-manager.follows = "home-manager";
    };
  };

  outputs = {
    cluster,
    flake-utils,
    nixpkgs,
    ...
  }:
    cluster.lib.configure (import ./config.nix) (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # Use the devShells of the cluster flake
      devShells = {
        inherit (cluster.devShells.${system}) default;
      };

      apps = {
        # Shortcut to call the cli using `nix run .`
        inherit (cluster.apps.${system}) default;

        # Browse the flake using nix repl
        repl = flake-utils.lib.mkApp {
          drv = pkgs.writeShellApplication {
            name = "repl";
            runtimeInputs = [pkgs.jq];
            text = ''
              flake_url=$(nix flake metadata --json --no-write-lock-file --quiet | jq -r '.url')
              nix repl --expr "builtins.getFlake \"$flake_url\""
            '';
          };
        };
      };
    }));
}

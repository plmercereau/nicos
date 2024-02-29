inputs @ {
  deploy-rs,
  nixpkgs,
  srvos,
  ...
}:
with nixpkgs.lib; let
  flakeLib = import ./flake-lib.nix inputs;
  inherit (flakeLib) features overlays nixosModules hardware specialArgs printMachine hostsList;
in
  {
    projectRoot,
    adminKeys,
    extraModules ? [],
    machinesPath,
    builders ? {
      enable = false;
      path = null;
    },
    users ? {
      enable = false;
      path = null;
    },
    wifi ? {
      enable = false;
      path = null;
    },
  }:
    if (builtins.length adminKeys == 0)
    then (throw "There should be at least one admin key in order to safely generate secrets")
    else let
      nixosConfigurations = genAttrs (hostsList projectRoot machinesPath) (hostname:
        printMachine hostname nixosSystem {
          modules =
            nixosModules.default
            ++ [
              (projectRoot + "/${machinesPath}/${hostname}.nix")
              # Set the hostname from the file name
              {networking.hostName = hostname;}
            ]
            ++ extraModules;
          specialArgs = specialArgs // {inherit cluster;};
        });

      # TODO helper to get the config. Remove this if possible
      hosts = mapAttrs (name: sys: sys.config) nixosConfigurations;

      # Cluster object, that contains the cluster configuration
      cluster = {
        inherit projectRoot machinesPath builders users wifi hosts adminKeys;
        secrets =
          features.secrets {inherit projectRoot machinesPath builders users wifi hosts adminKeys;}
          # * Optionally loads the secrets.nix file in the project root file if it exists
          // optionalAttrs (builtins.pathExists (projectRoot + "/secrets.nix")) (import (projectRoot + "/secrets.nix"));
        hardware = hardware.recap;
      };

      # Make all the NixOS configurations deployable by deploy-rs
      deploy = {
        user = "root";
        nodes = builtins.mapAttrs (hostname: machine: let
          inherit (machine.config.nixpkgs.hostPlatform) system;
          printHostname = builtins.trace "Evaluating deployment: ${hostname} (${system})";
        in
          printHostname {
            inherit hostname;
            profiles.system.path = deploy-rs.lib.${system}.activate.nixos machine;
          })
        nixosConfigurations;
      };
    in
      recursiveUpdate {
        inherit
          nixosConfigurations
          deploy
          cluster
          nixosModules
          overlays
          ;
      }

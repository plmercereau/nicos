{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  cfg = config.settings.services.nix-builder;
  inherit (cfg.ssh) user;
  inherit (config.networking) hostName;
  builders = filterAttrs (_: conf: conf.settings.services.nix-builder.enable && conf.networking.hostName != hostName) cluster.hosts;
  nbBuilers = builtins.length (builtins.attrNames builders);
in {
  # TODO garbage collector etc: see the srvos nix-builder role
  options = {
    settings.services.nix-builder = {
      enable = mkEnableOption "the machine as a Nix builder for the other machines";
      ssh.user = mkOption {
        type = types.str;
        default = "builder";
        description = "The user name of the Nix builder.";
      };
      ssh.privateKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The private key file of the Nix builder.";
      };
      ssh.publicKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The public key of the Nix builder.";
      };

      supportedFeatures = mkOption {
        type = types.listOf types.str;
        default = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        description = ''
          A list of features that the builder supports
        '';
      };
      speedFactor = mkOption {
        type = types.int;
        default = 1;
        description = ''
          The speed factor of the builder. The speed factor is used to
          prioritize builders when multiple builders are available.
          The higher the speed factor, the more likely it is that the builder
          will be used.
        '';
      };
      maxJobs = mkOption {
        type = types.int;
        default = let
          inherit (config.nix.settings) cores;
        in
          if cores > 0
          then cores
          else 1;
        description = ''
          The maximum number of jobs that can be run in parallel on the builder.
          The default is _nix.settings.cores_ if it is greater than 0, otherwise 1
        '';
      };
    };
  };
  config = {
    assertions = [
      {
        assertion =
          !(nbBuilers > 0 && cfg.ssh.privateKeyFile == null);
        message = "At least one Nix builder is enabled but settings.services.nix-builder.ssh.privateKeyFile is null.";
      }
      {
        assertion = !(cfg.enable && cfg.ssh.publicKey == null);
        message = "The Nix builder is enabled but settings.services.nix-builder.ssh.publicKey is null.";
      }
    ];

    environment.etc."ssh/ssh_config.d/150-remote-builders.conf" =
      mkIf (nbBuilers > 0)
      {
        text = builtins.concatStringsSep "\n" (
          mapAttrsToList (name: host: ''
            Match user ${user} originalhost ${host.networking.hostName}
              IdentityFile ${cfg.ssh.privateKeyFile}
          '')
          builders
        );
      };

    # The builder user can use nix
    nix.settings.trusted-users = mkIf cfg.enable (mkAfter [user]);

    # Force enable the builder user
    settings.users.users.${user} = mkIf cfg.enable {
      enable = mkForce true;
      publicKeys = [cfg.ssh.publicKey];
    };

    # Every host has access to the machines configured as a Nix builder
    nix.buildMachines =
      mkForce
      (mapAttrsToList (name: host: let
          conf = host.settings.services.nix-builder;
        in {
          inherit (host.networking) hostName;
          inherit (conf) supportedFeatures speedFactor maxJobs;
          sshUser = conf.ssh.user;
          sshKey = conf.ssh.privateKeyFile;
          protocol = "ssh-ng";

          systems =
            [host.nixpkgs.hostPlatform.system]
            ++ (optionals
              (host.nixpkgs.hostPlatform.isLinux)
              host.boot.binfmt.emulatedSystems);
        })
        builders);
  };
}

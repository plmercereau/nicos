{
  config,
  lib,
  pkgs,
  cluster,
  ...
}: let
  cfg = config.settings.services.nix-builder;
  enabled = cfg.enable;
  user = cfg.ssh.user;
  inherit (cluster) hosts;
  id = config.settings.id;
  builders = lib.filterAttrs (_: conf: conf.settings.services.nix-builder.enable && conf.settings.id != id) hosts;
  nbBuilers = builtins.length (builtins.attrNames builders);
in {
  # ? TODO shouldn't we adapt or disable the garbage collector on the builder?
  options = with lib; {
    settings.services = with lib; {
      nix-builder = {
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
  };
  config = {
    assertions = [
      {
        assertion =
          !(nbBuilers > 0 && cfg.ssh.privateKeyFile == null);
        message = "At least one Nix builder is enabled but settings.services.nix-builder.ssh.privateKeyFile is null.";
      }
      {
        assertion = !(enabled && cfg.ssh.publicKey == null);
        message = "The Nix builder is enabled but settings.services.nix-builder.ssh.publicKey is null.";
      }
    ];

    environment.etc."ssh/ssh_config.d/150-remote-builders.conf" =
      lib.mkIf (nbBuilers > 0)
      {
        text = builtins.concatStringsSep "\n" (
          lib.mapAttrsToList (name: host: ''
            Match user ${user} originalhost ${host.networking.hostName}
              IdentityFile ${cfg.ssh.privateKeyFile}
          '')
          builders
        );
      };

    # The builder user can use nix
    nix.settings.trusted-users = lib.mkIf enabled (lib.mkAfter [user]);

    # Force enable the builder user
    settings.users.users.${user} = lib.mkIf enabled {
      enable = lib.mkForce true;
      publicKeys = [cfg.ssh.publicKey];
    };

    # Every host has access to the machines configured as a Nix builder
    nix.buildMachines =
      lib.mkForce
      (lib.mapAttrsToList (name: host: let
          conf = host.settings.services.nix-builder;
        in {
          inherit (host.networking) hostName;
          inherit (conf) supportedFeatures speedFactor maxJobs;
          sshUser = conf.ssh.user;
          sshKey = conf.ssh.privateKeyFile;
          protocol = "ssh-ng";

          systems =
            [host.nixpkgs.hostPlatform.system]
            ++ (lib.optionals
              (host.nixpkgs.hostPlatform.isLinux)
              host.boot.binfmt.emulatedSystems);
        })
        builders);
  };
}

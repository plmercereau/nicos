{
  config,
  lib,
  pkgs,
  ...
}: let
  enabled = config.settings.builder.enable;
  isDarwin = pkgs.hostPlatform.isDarwin;
in {
  options.settings = with lib; {
    # TODO settings.builder.privateKeyFile and settings.builder.publicKeyFile
    # TODO or rather a builder user in ./users/
    builder = {
      enable = mkEnableOption "Is the machine a NixOS builder";
    };
  };
  config = {
    nix =
      {
        # https://nixos.wiki/wiki/Storage_optimization
        settings.auto-optimise-store = true;
        settings.trusted-users = lib.mkIf enabled ["builder"];
        # https://nixos.wiki/wiki/Distributed_build
        distributedBuilds = true;
        # optional, useful when the builder has a faster internet connection than yours
        extraOptions = ''
          builders-use-substitutes = true
        '';

        buildMachines = [
          # TODO
          #   {
          #     hostName = "builder";
          #     system = host.platform;
          #     protocol = "ssh-ng";
          #     # if the builder supports building for multiple architectures,
          #     # replace the previous line by, e.g.,
          #     # systems = ["x86_64-linux" "aarch64-linux"];
          #     maxJobs = 1;
          #     speedFactor = 2;
          #     sshUser = "builder";
          #     sshKey = "/path/to/your/private/ssh/key";
          #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
          #     mandatoryFeatures = [];
          #   }
        ];
      }
      // lib.optionalAttrs isDarwin {
        # Create a Linux remote builder that works out of the box
        linux-builder = {
          enable = true;
          maxJobs = 10; # use all cores (M1 has 8, M2 has 10)
        };
        configureBuildUsers = true; # Allow nix-darwin to build users
        # * add the admin ssh keys into the linux-builder to be able to connect
        linux-builder.config.users.users.builder.openssh.authorizedKeys.keys = config.lib.ext_lib.adminKeys;
      };

    users.users.builder = lib.mkIf enabled {
      isSystemUser = true;
      # TODO
      # openssh.authorizedKeys.keys
      # openssh.authorizedKeys.keyFiles
    };
  };
}

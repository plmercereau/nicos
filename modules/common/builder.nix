{
  config,
  lib,
  pkgs,
  ...
}: let
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
  enabled = host.builder;
in {
  config = {
    # TODO
    # settings.builder.enable = host.builder;
    nix.settings.trustedUsers = mkIf enabled ["builder"];
    users.users.builder = mkIf enabled {
      isSystemUser = true;
      #   ?
      # openssh.authorizedKeys.keys
      # openssh.authorizedKeys.keyFiles
    };
    # https://nixos.wiki/wiki/Distributed_build
    nix.distributedBuilds = true;
    # optional, useful when the builder has a faster internet connection than yours
    nix.extraOptions = ''
      builders-use-substitutes = true
    '';

    nix.buildMachines = [
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
      # sshUser = "builder";
      #    sshKey = "/path/to/your/ssh/key"; # TODO
      #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #     mandatoryFeatures = [];
      #   }
    ];
  };
}

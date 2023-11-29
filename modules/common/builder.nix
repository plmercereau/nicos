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
  settings = {
    # TODO settings.builder.privateKeyFile and settings.builder.publicKeyFile
  };
  config = {
    # https://nixos.wiki/wiki/Storage_optimization
    nix.settings.auto-optimise-store = true;
    # settings.builder.enable = host.builder;
    nix.settings.trusted-users = mkIf enabled ["builder"];
    users.users.builder = mkIf enabled {
      isSystemUser = true;
      # TODO
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
      #     sshUser = "builder";
      #     sshKey = "/path/to/your/private/ssh/key";
      #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #     mandatoryFeatures = [];
      #   }
    ];
  };
}

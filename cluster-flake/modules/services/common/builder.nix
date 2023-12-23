{
  config,
  lib,
  pkgs,
  ...
}: let
  enabled = config.settings.services.builder.enable;
in {
  options.settings.services = with lib; {
    # TODO settings.builder.privateKeyFile and settings.builder.publicKeyFile
    # TODO or rather a builder user in ./users/
    builder = {
      enable = mkEnableOption "Is the machine a NixOS builder";
    };
  };
  config = lib.mkIf enabled {
    nix = {
      settings.trusted-users = ["builder"];
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
    };

    users.users.builder = {
      isSystemUser = true;
      # TODO
      # openssh.authorizedKeys.keys
      # openssh.authorizedKeys.keyFiles
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    settings.services.linux-builder = {
      enable = mkEnableOption "the Linux remote builder";
      speedFactor = mkOption {
        type = types.int;
        default = 10;
        description = "Speed factor for the Linux remote builder";
      };
      maxJobs = mkOption {
        type = types.int;
        default = config.nix.settings.max-jobs;
        description = ''
          Maximum number of jobs for the Linux remote builder.
          Defaults to `nix.settings.max-jobs`.
        '';
      };
    };
  };
  config.nix = mkIf config.settings.services.linux-builder.enable {
    # Create a Linux remote builder that works out of the box
    linux-builder = {
      # TODO don't use the builder when building it???
      # * See: https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/profiles/macos-builder.nix#L179
      inherit (config.settings.services.linux-builder) enable;
      maxJobs = mkDefault config.settings.services.linux-builder.maxJobs;
      config = {
        # TODO add an option to increase disk size and/or garbage connection
        boot.binfmt.emulatedSystems =
          if config.nixpkgs.hostPlatform.isAarch64
          then ["x86_64-linux"]
          else ["aarch64-linux"];
        # * add the admin ssh keys into the linux-builder to be able to connect
        users.users.builder.openssh.authorizedKeys.keys = config.lib.ext_lib.adminKeys;
      };
    };
    # rewrite of the default buildMachines, except that it defines two `systems` instead of one `system`
    buildMachines = mkForce [
      {
        hostName = "linux-builder";
        sshUser = "builder";
        sshKey = "/etc/nix/builder_ed25519";
        inherit (config.settings.services.linux-builder) maxJobs speedFactor;
        systems = ["x86_64-linux" "aarch64-linux"]; # <- this is the only difference and it replaces the `system` attribute
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
        inherit (config.nix.linux-builder) supportedFeatures;
      }
    ];
  };
}

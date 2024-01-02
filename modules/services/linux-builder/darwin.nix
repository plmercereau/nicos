{
  config,
  lib,
  pkgs,
  nixpkgs-darwin,
  ...
}:
with lib; let
  cfg = config.settings.services.linux-builder;
in {
  options = {
    settings.services.linux-builder = {
      enable = mkOption {
        description = ''          '
          Whether to run a virtual linux builder on the host machine.

          <Warning>If no Nix builder is available with the host's architecture, you must first build with the `services.linux-builder.initialBuitd' option enabled.</Warning>
        '';
        type = types.bool;
        default = false;
      };
      initialBuild = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to activate the initial linux-builder from the nixpkgs cache.

          On the first run, the Linux builder needs to be created. Unless there is a corresponding nix builder set up,
          the Darwin host won't be able to build the Linux builder with its custom configuraiton.

          This option allows to disable the custom configuration of the linux-builder,
          so that the Linux builder can be installed from the official cache.

          Once the Linux builder is on, it is available as a build itself, and the option can then be disabled
          so the host machine can rebuild it again with the custom configuration.
        '';
      };
      crossBuilding.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether for the Linux builder to support cross-building.

          When enabled, the Linux builder will support both ARM and x86 using QEMU. It is slow.
        '';
      };
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
  config.nix = mkIf cfg.enable {
    # Create a Linux remote builder that works out of the box
    linux-builder = {
      # * nix-darwin option: https://github.com/LnL7/nix-darwin/blob/master/modules/nix/linux-builder.nix
      # * darwin-builder: https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/profiles/macos-builder.nix
      enable = true;
      config = mkIf (!cfg.initialBuild) {
        # TODO add an option to increase disk size etc
        # TODO use the srvos builder role
        boot.binfmt.emulatedSystems =
          mkIf (cfg.crossBuilding.enable)
          (
            if config.nixpkgs.hostPlatform.isAarch64
            then ["x86_64-linux"]
            else ["aarch64-linux"]
          );
        # * add the admin ssh keys into the linux-builder so the project admins can connect to it without using the /etc/nix/builder_ed25519 identity
        users.users.builder.openssh.authorizedKeys.keys = config.lib.ext_lib.adminKeys;
      };
    };
    # rewrite of the default buildMachines, except that it defines two `systems` instead of one `system`
    buildMachines = mkForce [
      {
        hostName = "linux-builder";
        sshUser = "builder";
        sshKey = "/etc/nix/builder_ed25519";
        inherit (cfg) maxJobs speedFactor;
        systems =
          # This is the only difference with the original builder and it replaces the `system` attribute
          if (!cfg.initialBuild && !cfg.crossBuilding.enable)
          then [(builtins.replaceStrings ["-darwin"] ["-linux"] config.nixpkgs.hostPlatform.system)]
          else ["x86_64-linux" "aarch64-linux"];
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
        inherit (config.settings.services.nix-builder) supportedFeatures;
      }
    ];
  };
}

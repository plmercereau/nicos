{
  config,
  lib,
  pkgs,
  ...
}: {
  services.nix-daemon.enable = true; # Make sure the nix daemon always runs

  # Apply settings on activation.
  # * See https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
  # TODO restart yabai/skhd (probably not working because of killall Dock)
  system.activationScripts.postUserActivation.text = ''
    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    killall Dock
    osascript -e 'display notification "Nix settings applied"'
  '';

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      cores = 0; # use all cores
      max-jobs = 10; # use all cores (M1 has 8, M2 has 10)
      trusted-users = ["@admin"];
      extra-experimental-features = ["nix-command" "flakes"];
      keep-outputs = true;
      keep-derivations = true;
    };

    # Create a Linux remote builder that works out of the box
    linux-builder = {
      # TODO don't use the builder when building it???
      # * See: https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/profiles/macos-builder.nix#L179
      # TODO should be optional
      enable = true;
      maxJobs = 8; # use all cores (M1 has 8, M2 has 10)
      config = {
        boot.binfmt.emulatedSystems =
          if config.nixpkgs.hostPlatform.isAarch64
          then ["x86_64-linux"]
          else ["aarch64-linux"];
        # * add the admin ssh keys into the linux-builder to be able to connect
        users.users.builder.openssh.authorizedKeys.keys = config.lib.ext_lib.adminKeys;
      };
    };
    # rewrite of the default buildMachines, except that it defines two `systems` instead of one `system`
    # TODO lib.mkForce probably won't get along well with another buildMachines definition e.g. when adding builders
    buildMachines = lib.mkForce [
      {
        hostName = "linux-builder";
        sshUser = "builder";
        sshKey = "/etc/nix/builder_ed25519";
        systems = ["x86_64-linux" "aarch64-linux"]; # <- this is the only difference and it replaces the `system` attribute
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
        inherit (config.nix.linux-builder) maxJobs supportedFeatures;
      }
    ];
  };
}

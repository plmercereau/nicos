{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  services.nix-daemon.enable = true; # Make sure the nix daemon always runs

  # Apply settings on activation.
  # * See https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
  system.activationScripts.postUserActivation.text = ''
    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    killall Dock
    osascript -e 'display notification "Nix settings applied"'
  '';

  nix = {
    package = pkgs.nixVersions.stable;
    configureBuildUsers = true; # Creates "build users"
    settings = {
      # TODO not ideal difference bw admin and wheel. And also, not ideal to reuse as nix trusted users. Create a separate group?
      trusted-users = ["@admin"];
      extra-experimental-features = ["nix-command" "flakes"];
      keep-outputs = true;
      keep-derivations = true;
      # ! Remove when this issue will be solved: https://github.com/NixOS/nix/issues/7273
      auto-optimise-store = mkForce false;
    };
  };
}
